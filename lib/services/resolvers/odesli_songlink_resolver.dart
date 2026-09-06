import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'stream_resolver_base.dart';

class OdesliMatchResult {
  final String? tidalTrackId;
  final String? tidalUrl;
  final String? qobuzTrackId;
  final String? qobuzUrl;
  final String? title;
  final String? artist;

  const OdesliMatchResult({
    this.tidalTrackId,
    this.tidalUrl,
    this.qobuzTrackId,
    this.qobuzUrl,
    this.title,
    this.artist,
  });

  bool get hasLosslessMatch =>
      tidalTrackId != null || qobuzTrackId != null;
}

class OdesliSongLinkResolver {
  static const String _apiBase = 'https://api.song.link/v1-alpha.1/links';
  static final Map<String, OdesliMatchResult> _cache = {};
  static final Map<String, Future<OdesliMatchResult?>> _inFlight = {};
  static const int _maxCacheEntries = 300;

  static String? extractTidalId(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final trackIdx = segments.indexOf('track');
    if (trackIdx != -1 && trackIdx + 1 < segments.length) {
      return segments[trackIdx + 1];
    }
    final match = RegExp(r'track/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  static String? extractQobuzId(String? url) {
    if (url == null || url.isEmpty) return null;
    final match = RegExp(r'track/([a-zA-Z0-9]+)').firstMatch(url);
    return match?.group(1);
  }

  static Future<OdesliMatchResult?> resolve({
    required String trackUrl,
    Duration? timeBudget,
  }) async {
    if (trackUrl.isEmpty) return null;
    final cacheKey = trackUrl.trim().toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey];
    }

    final completer = Completer<OdesliMatchResult?>();
    _inFlight[cacheKey] = completer.future;

    try {
      final cap = boundedTimeout(timeBudget, const Duration(milliseconds: 3500));
      final uri = Uri.parse('$_apiBase?url=${Uri.encodeComponent(trackUrl)}&songIfSingle=true');
      final client = http.Client();
      final response = await client
          .get(uri, headers: {'User-Agent': 'Noctra/1.0.3 (Lossless Engine)'})
          .timeout(cap);
      client.close();

      if (response.statusCode != 200) {
        completer.complete(null);
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final linksByPlatform =
          data['linksByPlatform'] as Map<String, dynamic>? ?? {};

      final tidal = linksByPlatform['tidal'] as Map<String, dynamic>?;
      final qobuz = linksByPlatform['qobuz'] as Map<String, dynamic>?;

      final tidalUrl = tidal?['url'] as String?;
      final qobuzUrl = qobuz?['url'] as String?;

      final tidalId = extractTidalId(tidalUrl);
      final qobuzId = extractQobuzId(qobuzUrl);

      final entityId = data['entityUniqueId'] as String? ?? '';
      final entities = data['entitiesByUniqueId'] as Map<String, dynamic>? ?? {};
      final entity = entities[entityId] as Map<String, dynamic>?;

      final title = entity?['title'] as String?;
      final artist = entity?['artistName'] as String?;

      final result = OdesliMatchResult(
        tidalTrackId: tidalId,
        tidalUrl: tidalUrl,
        qobuzTrackId: qobuzId,
        qobuzUrl: qobuzUrl,
        title: title,
        artist: artist,
      );

      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[cacheKey] = result;
      completer.complete(result);
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Odesli] Resolution failed for $trackUrl: $e');
      }
      completer.complete(null);
      return null;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  @visibleForTesting
  static void clearCacheForTesting() {
    _cache.clear();
    _inFlight.clear();
  }
}
