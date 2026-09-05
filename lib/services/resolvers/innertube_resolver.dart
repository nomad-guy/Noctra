import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../data/models/song_model.dart';
import 'innertube/innertube_player_api.dart';
import 'stream_resolver_base.dart';
import 'track_matching_guard.dart';

/// Music search client pinned to a current WEB_REMIX build.
const String _searchClientName = 'WEB_REMIX';
const String _searchClientVersion = '1.20260213.01.00';
const String _searchClientId = '67';
const String _searchUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) '
    'Gecko/20100101 Firefox/140.0';

/// Resolves playable audio for a Song whose source is YouTube Music.
///
/// Flow:
/// 1. Normalize to an 11-char YouTube video id (music.youtube.com search +
///    strict track matching when the id is not already a video id).
/// 2. Native Kotlin `extractInnerTube` fast path (fixed client set).
/// 3. Dart direct-URL cascade (`resolveInnerTubeStreamUrl`) with visitor
///    retry and CDN probing.
class InnerTubeMusicResolver implements StreamResolver {
  @override
  String get sourceId => 'innertube_stream';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async =>
      !song.id.startsWith('jam_');

  static Map<String, dynamic>? _extractCandidateInfo(dynamic item) {
    if (item == null || item is! Map) return null;
    final responsive = item['musicResponsiveListItemRenderer'] as Map?;
    if (responsive == null) return null;
    final vid = responsive['playlistItemData']?['videoId']?.toString() ??
        responsive['navigationEndpoint']?['watchEndpoint']?['videoId']
            ?.toString();
    if (vid == null || vid.length != 11) return null;

    String candTitle = '';
    String candArtist = '';
    Duration? candDuration;

    final flexCols = responsive['flexColumns'] as List?;
    if (flexCols != null && flexCols.isNotEmpty) {
      final col0Runs =
          (flexCols[0] as Map?)?['musicResponsiveListItemFlexColumnRenderer']
              ?['text']?['runs'] as List?;
      if (col0Runs != null && col0Runs.isNotEmpty) {
        candTitle =
            col0Runs.map((r) => (r as Map?)?['text']?.toString() ?? '').join();
      }
      if (flexCols.length > 1) {
        final col1Runs =
            (flexCols[1] as Map?)?['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List?;
        if (col1Runs != null && col1Runs.isNotEmpty) {
          final texts = col1Runs
              .map((r) => (r as Map?)?['text']?.toString() ?? '')
              .where((t) => t != ' • ')
              .toList();
          if (texts.isNotEmpty) candArtist = texts[0];
          for (final t in texts) {
            if (t.contains(':')) {
              candDuration = TrackMatchingGuard.parseDurationString(t);
            }
          }
        }
      }
    }
    return {
      'videoId': vid,
      'title': candTitle,
      'artist': candArtist,
      'duration': candDuration,
    };
  }

  /// Searches YouTube Music and returns a strictly track-matched video id.
  /// [cap] bounds the request by the caller's remaining resolution budget.
  Future<String?> _searchVideoId(Song song, {Duration? cap}) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
      final sBody = jsonEncode({
        'query': '$cleanTitle $cleanArtist',
        'context': {
          'client': {
            'clientName': _searchClientName,
            'clientVersion': _searchClientVersion,
            'hl': 'en',
            'gl': 'US',
          }
        },
      });
      // Per-attempt client: closing it on budget expiry aborts the request
      // instead of leaving the socket open until the full 6 s cap.
      final client = http.Client();
      try {
        final sRes = await client.post(sUri, body: sBody, headers: {
          'Content-Type': 'application/json',
          'User-Agent': _searchUserAgent,
          'X-Goog-Api-Format-Version': '1',
          'X-YouTube-Client-Name': _searchClientId,
          'X-YouTube-Client-Version': _searchClientVersion,
        }).timeout(boundedTimeout(cap, const Duration(seconds: 6)));
        if (sRes.statusCode != 200) return null;
        final sData = jsonDecode(sRes.body);
        final contents = sData['contents']?['tabbedSearchResultsRenderer']
                ?['tabs']?[0]?['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (contents == null) return null;
        for (final sec in contents) {
          final secMap = sec as Map;
          final itemSections =
              secMap['itemSectionRenderer']?['contents'] as List?;
          final shelfItems = secMap['musicShelfRenderer']?['contents'] as List?;
          final allItems = [...?itemSections, ...?shelfItems];
          for (final item in allItems) {
            final cand = _extractCandidateInfo(item);
            if (cand == null) continue;
            final candTitle = cand['title'] as String;
            final candArtist = cand['artist'] as String;
            final candDur = cand['duration'] as Duration?;
            if (TrackMatchingGuard.isSafeMatch(
              targetTitle: song.title,
              targetArtist: song.artist,
              targetDuration: song.duration,
              candidateTitle: candTitle.isNotEmpty ? candTitle : song.title,
              candidateArtist: candArtist.isNotEmpty ? candArtist : song.artist,
              candidateDuration: candDur,
            )) {
              return cand['videoId'] as String;
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    var videoId = song.id;
    if (videoId.length != 11 || videoId.contains('_')) {
      final found = await _searchVideoId(song,
          cap: boundedTimeout(timeBudget, const Duration(seconds: 6)));
      if (found == null) return null;
      videoId = found;
    }
    if (videoId.length != 11) return null;

    if (!kIsWeb) {
      // Native fast path (fixed client set in Kotlin). Cannot be cancelled
      // from Dart once invoked; bound the wait by the remaining budget and
      // discard any late reply (Kotlin engine has its own timeouts).
      try {
        final cap = boundedTimeout(timeBudget, const Duration(seconds: 3));
        final nativeUrl =
            await const MethodChannel('com.nomadguy.noctra/native_resolver')
                .invokeMethod<String>(
                    'extractInnerTube', {'videoId': videoId}).timeout(cap);
        if (nativeUrl != null && nativeUrl.isNotEmpty) return nativeUrl;
      } catch (_) {}
    }
    // Direct-URL cascade; cap each of its per-request timeouts by what is
    // left of the shared budget so it cannot run far past the deadline.
    return resolveInnerTubeStreamUrl(
      videoId,
      perRequestTimeout: boundedTimeout(timeBudget, const Duration(seconds: 5)),
    );
  }
}
