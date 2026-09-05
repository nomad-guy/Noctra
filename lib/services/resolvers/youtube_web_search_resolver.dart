import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/models/song_model.dart';
import 'innertube/innertube_player_api.dart';
import 'stream_resolver_base.dart';
import 'track_matching_guard.dart';

/// Search client pinned to a current WEB build (www.youtube.com).
const String _webClientName = 'WEB';
const String _webClientVersion = '2.20260213.00.00';
const String _webClientId = '1';
const String _webUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) '
    'Gecko/20100101 Firefox/140.0';

/// Fallback tier: searches www.youtube.com for a strict track match, then
/// resolves the stream through the same direct-URL cascade used by the
/// InnerTube tier (against the www host).
class YoutubeWebSearchResolver implements StreamResolver {
  @override
  String get sourceId => 'youtube_web_search';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async =>
      !kIsWeb && !song.id.startsWith('jam_');

  /// Searches www.youtube.com; returns a strictly matched video id.
  /// [cap] bounds the request by the caller's remaining resolution budget.
  Future<String?> _searchVideoId(Song song, {Duration? cap}) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      final sUri = Uri.parse('https://www.youtube.com/youtubei/v1/search');
      final sBody = jsonEncode({
        'query': '$cleanTitle $cleanArtist',
        'context': {
          'client': {
            'clientName': _webClientName,
            'clientVersion': _webClientVersion,
            'hl': 'en',
            'gl': 'US',
          }
        },
      });
      // Per-attempt client: closing it on budget expiry aborts the request
      // instead of leaving the socket open until the full 5 s cap.
      final client = http.Client();
      try {
        final sRes = await client.post(sUri, body: sBody, headers: {
          'Content-Type': 'application/json',
          'User-Agent': _webUserAgent,
          'X-Goog-Api-Format-Version': '1',
          'X-YouTube-Client-Name': _webClientId,
          'X-YouTube-Client-Version': _webClientVersion,
        }).timeout(boundedTimeout(cap, const Duration(seconds: 5)));
        if (sRes.statusCode != 200) return null;
        final sData = jsonDecode(sRes.body);
        final contents = sData['contents']?['twoColumnSearchResultsRenderer']
            ?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
        if (contents == null) return null;
        for (final sec in contents) {
          final items =
              (sec as Map)['itemSectionRenderer']?['contents'] as List?;
          if (items == null) continue;
          for (final item in items) {
            final vr = (item as Map?)?['videoRenderer'] as Map?;
            final vid = vr?['videoId']?.toString();
            if (vid == null || vid.length != 11) continue;
            final candTitle = vr?['title']?['runs']?[0]?['text']?.toString() ??
                vr?['title']?['simpleText']?.toString() ??
                '';
            final candArtist =
                vr?['ownerText']?['runs']?[0]?['text']?.toString() ?? '';
            final candDuration = TrackMatchingGuard.parseDurationString(
                vr?['lengthText']?['simpleText']?.toString());
            if (TrackMatchingGuard.isSafeMatch(
              targetTitle: song.title,
              targetArtist: song.artist,
              targetDuration: song.duration,
              candidateTitle: candTitle.isNotEmpty ? candTitle : song.title,
              candidateArtist: candArtist.isNotEmpty ? candArtist : song.artist,
              candidateDuration: candDuration,
            )) {
              return vid;
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
    final found = await _searchVideoId(song,
        cap: boundedTimeout(timeBudget, const Duration(seconds: 5)));
    if (found == null || found.length != 11) return null;
    return resolveInnerTubeStreamUrl(
      found,
      host: 'www.youtube.com',
      perRequestTimeout: boundedTimeout(timeBudget, const Duration(seconds: 5)),
    );
  }
}
