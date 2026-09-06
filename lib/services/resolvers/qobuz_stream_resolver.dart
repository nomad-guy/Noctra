import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/audio_quality.dart';
import '../../data/models/song_model.dart';
import 'odesli_songlink_resolver.dart';
import 'stream_resolver_base.dart';
import 'track_matching_guard.dart';

class QobuzStreamResolver implements StreamResolver {
  @override
  String get sourceId => 'qobuz_flac';

  static String? customEndpoint;
  static const List<String> defaultEndpoints = [
    'https://api.qobuz.proxy.internal',
  ];

  static final Map<String, AudioStreamInfo> _streamInfoCache = {};

  static AudioStreamInfo? getStreamInfo(String songId) =>
      _streamInfoCache[songId];

  static List<String> get activeEndpoints {
    final list = <String>[];
    if (customEndpoint != null && customEndpoint!.trim().isNotEmpty) {
      list.add(customEndpoint!.trim().replaceAll(RegExp(r'/+$'), ''));
    }
    list.addAll(defaultEndpoints);
    return list;
  }

  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async {
    if (song.id.startsWith('qobuz_')) return true;
    if (song.streamUrl != null && song.streamUrl!.contains('qobuz.com')) {
      return true;
    }
    return song.title.trim().isNotEmpty && song.artist.trim().isNotEmpty;
  }

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    final remainingBudget = boundedTimeout(timeBudget, const Duration(seconds: 4));
    final stopwatch = Stopwatch()..start();

    String? qobuzId;
    if (song.id.startsWith('qobuz_')) {
      qobuzId = song.id.substring(6);
    } else if (song.streamUrl != null && song.streamUrl!.contains('track/')) {
      final match = RegExp(r'track/([a-zA-Z0-9]+)').firstMatch(song.streamUrl!);
      qobuzId = match?.group(1);
    }

    if (qobuzId == null && song.streamUrl != null) {
      final odesliBudget = remainingBudget - stopwatch.elapsed;
      if (odesliBudget > const Duration(milliseconds: 500)) {
        final match = await OdesliSongLinkResolver.resolve(
          trackUrl: song.streamUrl!,
          timeBudget: odesliBudget,
        );
        qobuzId = match?.qobuzTrackId;
      }
    }

    for (final base in activeEndpoints) {
      final iterationBudget = remainingBudget - stopwatch.elapsed;
      if (iterationBudget <= const Duration(milliseconds: 400)) break;

      try {
        qobuzId ??= await _searchQobuzTrack(base, song, iterationBudget);
        if (qobuzId == null) continue;

        final stream = await _fetchStreamUrl(base, qobuzId, iterationBudget);
        if (stream != null) {
          _streamInfoCache[song.id] = stream;
          return stream.url;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[QobuzResolver] Endpoint $base error: $e');
        }
      }
    }

    return null;
  }

  Future<String?> _searchQobuzTrack(
    String base,
    Song song,
    Duration budget,
  ) async {
    final client = http.Client();
    try {
      final query = Uri.encodeComponent('${song.title} ${song.artist}'.trim());
      final uri = Uri.parse('$base/search?query=$query&limit=3');
      final res = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(boundedTimeout(budget, const Duration(milliseconds: 1800)));

      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      final tracks = (json is Map
          ? (json['tracks'] is Map ? json['tracks']['items'] : json['data'])
          : json) as List?;
      if (tracks == null || tracks.isEmpty) return null;

      for (final item in tracks) {
        if (item is! Map) continue;
        final candidateTitle = item['title']?.toString() ?? '';
        final candidateArtist = item['performer']?['name']?.toString() ??
            item['artist']?['name']?.toString() ??
            '';
        final candidateDuration = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
        final candidateDurationMs = candidateDuration * 1000;

        if (TrackMatchingGuard.isMismatch(
          requestedTitle: song.title,
          requestedArtist: song.artist,
          candidateTitle: candidateTitle,
          candidateArtist: candidateArtist,
          candidateDurationMs: candidateDurationMs > 0 ? candidateDurationMs : null,
          requestedDurationMs: song.duration.inMilliseconds > 0 ? song.duration.inMilliseconds : null,
        )) {
          continue;
        }

        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
    return null;
  }

  Future<AudioStreamInfo?> _fetchStreamUrl(
    String base,
    String qobuzId,
    Duration budget,
  ) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$base/track/$qobuzId?format_id=27');
      final res = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(boundedTimeout(budget, const Duration(milliseconds: 2000)));

      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final url = json['url']?.toString() ?? json['data']?['url']?.toString();
      if (url == null || url.isEmpty) return null;

      final bitDepth = int.tryParse(
              json['bitDepth']?.toString() ?? json['data']?['bitDepth']?.toString() ?? '') ??
          24;
      final sampleRate = int.tryParse(
              json['sampleRate']?.toString() ?? json['data']?['sampleRate']?.toString() ?? '') ??
          96000;

      if (bitDepth >= 24) {
        return AudioStreamInfo.hiResFlac(
          url: url,
          bitDepth: bitDepth,
          sampleRate: sampleRate,
          sourceId: sourceId,
        );
      }
      return AudioStreamInfo.losslessFlac(
        url: url,
        bitDepth: bitDepth,
        sampleRate: sampleRate,
        sourceId: sourceId,
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static void clearCacheForTesting() {
    _streamInfoCache.clear();
  }
}
