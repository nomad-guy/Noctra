import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// youtube_explode_dart removed: NativeKotlinResolver + InnerTubeMusicResolver
// handle YouTube resolution via the Kotlin engine — no Dart-side library needed.
import '../../data/models/song_model.dart';
import '../audio/stream_quality_service.dart';
import 'track_matching_guard.dart';

abstract class StreamResolver {
  String get sourceId;
  Future<bool> canResolve(Song song);
  Future<String?> resolveStreamUrl(Song song);
}

class LocalFileResolver implements StreamResolver {
  @override
  String get sourceId => 'local_offline';
  @override
  Future<bool> canResolve(Song song) async {
    if (kIsWeb) return false;
    final path = song.localFilePath;
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        return f.existsSync() && f.lengthSync() > 1024;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<String?> resolveStreamUrl(Song song) async => song.localFilePath;
}

class DirectOpenStreamResolver implements StreamResolver {
  @override
  String get sourceId => 'direct_open';
  @override
  Future<bool> canResolve(Song song) async {
    final url = song.streamUrl;
    if (url == null || url.isEmpty) return false;
    if (!_TrustedAudioHosts.isTrusted(url)) return false;
    // Reject known-bad hosts even if they are in the trusted set
    // (defence in depth — e.g. an attacker who somehow registers
    // `attacker.com.youtube.com` won't pass because the trusted
    // list already excludes `youtube.com` direct hosts).
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    const blockedSuffixes = ['scdn.co', 'spotify.com', 'apple.com'];
    for (final suffix in blockedSuffixes) {
      if (host == suffix || host.endsWith('.$suffix')) return false;
    }
    return true;
  }

  @override
  Future<String?> resolveStreamUrl(Song song) async => song.streamUrl;
}

class JioSaavnDirectResolver implements StreamResolver {
  static const _channel = MethodChannel('com.nomadguy.noctra/native_resolver');
  @override
  String get sourceId => 'jiosaavn_320kbps';
  @override
  Future<bool> canResolve(Song song) async {
    final u = song.streamUrl;
    if (u != null &&
        u.isNotEmpty &&
        (u.contains('saavncdn.com') || u.contains('jiosaavn.com'))) {
      return true;
    }
    return song.id.startsWith('saavn_');
  }

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    if (song.streamUrl != null &&
        song.streamUrl!.isNotEmpty &&
        song.streamUrl!.contains('saavncdn.com')) {
      return song.streamUrl;
    }
    if (song.id.startsWith('saavn_')) {
      try {
        final pid = song.id.substring(6);
        final uri = Uri.parse(
            'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$pid&_format=json&_marker=0&ctx=android');
        final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          // Guard against OOM on malicious or oversized responses
          if (res.contentLength != null && res.contentLength! > 200000) {
            return null;
          }
          if (res.body.length > 200000) {
            return null;
          }
          final data = jsonDecode(res.body);
          final songData = (data is Map
              ? (data[pid] ?? data.values.firstOrNull)
              : null) as Map<String, dynamic>?;
          final encUrl = songData?['encrypted_media_url'] as String? ??
              songData?['more_info']?['encrypted_media_url'] as String?;
          if (encUrl != null && encUrl.isNotEmpty) {
            final decUrl = await _channel
                .invokeMethod<String>('decryptUrl', {'encryptedUrl': encUrl});
            if (decUrl != null && decUrl.isNotEmpty) return decUrl;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}

class NativeKotlinResolver implements StreamResolver {
  static const _channel = MethodChannel('com.nomadguy.noctra/native_resolver');
  @override
  String get sourceId => 'native_kotlin_320k';
  @override
  Future<bool> canResolve(Song song) async =>
      !kIsWeb && !song.id.startsWith('jam_');
  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      final cleanTitle = song.title
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      final String? streamUrl =
          await _channel.invokeMethod<String>('resolve320k', {
        'title': cleanTitle.isNotEmpty ? cleanTitle : song.title,
        'artist': cleanArtist.isNotEmpty ? cleanArtist : song.artist,
      }).timeout(const Duration(seconds: 6));
      if (streamUrl != null &&
          streamUrl.isNotEmpty &&
          !streamUrl.contains('preview')) {
        return streamUrl;
      }
    } catch (_) {}
    return null;
  }
}

class InnerTubeMusicResolver implements StreamResolver {
  @override
  String get sourceId => 'innertube_stream';
  @override
  Future<bool> canResolve(Song song) async => !song.id.startsWith('jam_');

  static final List<Map<String, dynamic>> innerTubeClients = [
    {
      'clientName': 'ANDROID_TESTSUITE',
      'clientVersion': '1.9',
      'androidSdkVersion': 30
    },
    {
      'clientName': 'ANDROID_MUSIC',
      'clientVersion': '6.42.52',
      'androidSdkVersion': 34
    },
    {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240820.01.00',
      'hl': 'en',
      'gl': 'US'
    },
    {
      'clientName': 'TVHTML5',
      'clientVersion': '7.20240801.12.00',
      'theme': 'TVHTML5'
    }
  ];

  /// Extracts candidate metadata (title, artist, duration, videoId) for
  /// strict matching against the requested song.
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
      final col0Runs = (flexCols[0]
              as Map?)?['musicResponsiveListItemFlexColumnRenderer']?['text']
          ?['runs'] as List?;
      if (col0Runs != null && col0Runs.isNotEmpty) {
        candTitle = col0Runs
            .map((r) => (r as Map?)?['text']?.toString() ?? '')
            .join();
      }
      if (flexCols.length > 1) {
        final col1Runs = (flexCols[1]
                as Map?)?['musicResponsiveListItemFlexColumnRenderer']?['text']
            ?['runs'] as List?;
        if (col1Runs != null && col1Runs.isNotEmpty) {
          final texts = col1Runs
              .map((r) => (r as Map?)?['text']?.toString() ?? '')
              .where((t) => t != ' • ')
              .toList();
          if (texts.isNotEmpty) {
            candArtist = texts[0];
          }
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

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      String videoId = song.id;
      if (videoId.length != 11 || videoId.contains('_')) {
        // Query preserving remix/live modifiers
        final cleanTitle = song.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
        final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
        final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final sBody = jsonEncode({
          'query': '$cleanTitle $cleanArtist',
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20240820.01.00',
              'hl': 'en',
              'gl': 'US'
            }
          }
        });
        final sRes = await http.post(sUri, body: sBody, headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 6));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body);
          final contents = sData['contents']?['tabbedSearchResultsRenderer']
                  ?['tabs']?[0]?['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List?;
          if (contents != null) {
            for (final sec in contents) {
              final secMap = sec as Map;
              final itemSections =
                  secMap['itemSectionRenderer']?['contents'] as List?;
              final shelfItems =
                  secMap['musicShelfRenderer']?['contents'] as List?;
              final allItems = [...?itemSections, ...?shelfItems];
              for (final item in allItems) {
                final cand = _extractCandidateInfo(item);
                if (cand != null) {
                  final candTitle = cand['title'] as String;
                  final candArtist = cand['artist'] as String;
                  final candDur = cand['duration'] as Duration?;
                  if (TrackMatchingGuard.isSafeMatch(
                    targetTitle: song.title,
                    targetArtist: song.artist,
                    targetDuration: song.duration,
                    candidateTitle:
                        candTitle.isNotEmpty ? candTitle : song.title,
                    candidateArtist:
                        candArtist.isNotEmpty ? candArtist : song.artist,
                    candidateDuration: candDur,
                  )) {
                    videoId = cand['videoId'] as String;
                    break;
                  }
                }
              }
              if (videoId.length == 11 && !videoId.contains('_')) break;
            }
          }
        }
      }

      if (videoId.length == 11) {
        if (!kIsWeb) {
          try {
            final nativeUrl =
                await const MethodChannel('com.nomadguy.noctra/native_resolver')
                    .invokeMethod<String>('extractInnerTube', {
              'videoId': videoId
            }).timeout(const Duration(seconds: 3));
            if (nativeUrl != null && nativeUrl.isNotEmpty) return nativeUrl;
          } catch (_) {}
        }

        for (final client in innerTubeClients) {
          try {
            final pUri =
                Uri.parse('https://music.youtube.com/youtubei/v1/player');
            final pBody = jsonEncode({
              'videoId': videoId,
              'context': {'client': client}
            });
            final pRes = await http.post(pUri, body: pBody, headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(seconds: 3));
            if (pRes.statusCode == 200) {
              final pData = jsonDecode(pRes.body);
              final formats =
                  pData['streamingData']?['adaptiveFormats'] as List?;
              if (formats != null && formats.isNotEmpty) {
                final audioStreams = formats
                    .where((f) =>
                        (f['mimeType'] as String?)?.contains('audio') == true)
                    .toList();
                if (audioStreams.isNotEmpty) {
                  final qualityService = StreamQualityService();
                  // Use StreamQualityService to pick the best bitrate
                  final List<Map<String, dynamic>> formatMaps = audioStreams
                      .map((f) => {
                            'mimeType': f['mimeType'] ?? '',
                            'bitrate': f['bitrate'] ?? 0,
                            'url': f['url'] ?? '',
                          })
                      .toList();
                  final bestUrl = qualityService.selectBestQuality(formatMaps);
                  if (bestUrl.isNotEmpty) return bestUrl;
                  // Fallback: highest bitrate
                  audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0)
                      .compareTo((a['bitrate'] as num?) ?? 0));
                  final url = audioStreams[0]['url'] as String?;
                  if (url != null && url.isNotEmpty) return url;
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Last-resort resolver: searches YouTube (non-music InnerTube) for a video
/// and extracts audio. Falls back to the regular InnerTube player endpoints.
class YoutubeWebSearchResolver implements StreamResolver {
  @override
  String get sourceId => 'youtube_web_search';
  @override
  Future<bool> canResolve(Song song) async =>
      !kIsWeb && !song.id.startsWith('jam_');

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      // Use regular YouTube search (non-music) as fallback
      final sUri = Uri.parse('https://www.youtube.com/youtubei/v1/search');
      final sBody = jsonEncode({
        'query': '$cleanTitle $cleanArtist audio',
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240801.00.00',
            'hl': 'en',
            'gl': 'US',
          }
        }
      });
      final sRes = await http.post(sUri, body: sBody, headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }).timeout(const Duration(seconds: 5));
      if (sRes.statusCode != 200) return null;
      final sData = jsonDecode(sRes.body);
      // Parse videoRenderer items from the standard YouTube search
      String? videoId;
      final contents = sData['contents']?['twoColumnSearchResultsRenderer']
          ?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (contents != null) {
        for (final sec in contents) {
          final items =
              (sec as Map)['itemSectionRenderer']?['contents'] as List?;
          if (items != null) {
            for (final item in items) {
              final vr = (item as Map?)?['videoRenderer'] as Map?;
              final vid = vr?['videoId']?.toString();
              if (vid != null && vid.length == 11) {
                final candTitle = vr?['title']?['runs']?[0]?['text']?.toString() ??
                    vr?['title']?['simpleText']?.toString() ?? '';
                final candArtist = vr?['ownerText']?['runs']?[0]?['text']?.toString() ?? '';
                final durationText = vr?['lengthText']?['simpleText']?.toString();
                final candDuration = TrackMatchingGuard.parseDurationString(durationText);

                if (TrackMatchingGuard.isSafeMatch(
                  targetTitle: song.title,
                  targetArtist: song.artist,
                  targetDuration: song.duration,
                  candidateTitle: candTitle.isNotEmpty ? candTitle : song.title,
                  candidateArtist: candArtist.isNotEmpty ? candArtist : song.artist,
                  candidateDuration: candDuration,
                )) {
                  videoId = vid;
                  break;
                }
              }
            }
          }
          if (videoId != null) break;
        }
      }
      if (videoId == null || videoId.length != 11) return null;
      // Now extract stream from this videoId using regular YouTube player
      for (final client in InnerTubeMusicResolver.innerTubeClients) {
        try {
          final pUri = Uri.parse('https://www.youtube.com/youtubei/v1/player');
          final pBody = jsonEncode({
            'videoId': videoId,
            'context': {'client': client}
          });
          final pRes = await http.post(pUri, body: pBody, headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0'
          }).timeout(const Duration(seconds: 4));
          if (pRes.statusCode == 200) {
            final pData = jsonDecode(pRes.body);
            final formats = pData['streamingData']?['adaptiveFormats'] as List?;
            if (formats != null && formats.isNotEmpty) {
              final audioStreams = formats
                  .where((f) =>
                      (f['mimeType'] as String?)?.contains('audio') == true)
                  .toList();
              if (audioStreams.isNotEmpty) {
                audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0)
                    .compareTo((a['bitrate'] as num?) ?? 0));
                final url = audioStreams[0]['url'] as String?;
                if (url != null && url.isNotEmpty) return url;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
}

class _CacheEntry {
  final String url;
  final int timestamp;

  /// When the upstream URL is expected to stop working. After this time
  /// the cache entry is treated as expired and the resolver is re-invoked.
  final int expiresAt;
  _CacheEntry(this.url, this.timestamp, this.expiresAt);
}

/// Centralised allowlist of hostnames that are trusted to serve audio
/// bytes directly. The list is intentionally small: only CDN domains
/// that the app's resolvers have first-party contracts with.
class _TrustedAudioHosts {
  static const Set<String> hosts = {
    'aac.saavncdn.com',
    'saavncdn.com',
    'jiosaavn.com',
    'c.saavncdn.com',
    'www.jiosaavn.com',
    'storage.googleapis.com',
    'googlevideo.com',
    'ytimg.com',
    'i.ytimg.com',
    'lh3.googleusercontent.com',
    'akamaized.net',
    'cloudfront.net',
    'cdn.jsdelivr.net',
    'jamendo.com',
    'jamendocdn.com',
  };

  static bool isTrusted(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final u = Uri.parse(url);
      if (u.scheme != 'https') return false;
      final h = u.host.toLowerCase();
      if (h.isEmpty) return false;
      if (hosts.contains(h)) return true;
      // Allow known CDN suffixes only.
      for (final allowed in hosts) {
        if (h.endsWith('.$allowed')) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class CompositeStreamResolver {
  static final Map<String, _CacheEntry> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};
  // Signed CDN URLs (YouTube / JioSaavn) are short-lived; cap cache
  // lifetime to 30 minutes to avoid returning a URL that has already
  // expired upstream.
  static const int _ttlMs = 30 * 60 * 1000; // 30 minutes

  static final List<StreamResolver> _resolvers = [
    LocalFileResolver(),
    DirectOpenStreamResolver(),
    JioSaavnDirectResolver(),
    NativeKotlinResolver(),
    InnerTubeMusicResolver(),
    YoutubeWebSearchResolver(),
  ];

  @visibleForTesting
  static void setResolversForTesting(List<StreamResolver>? custom) {
    _resolvers.clear();
    if (custom != null) {
      _resolvers.addAll(custom);
    } else {
      _resolvers.addAll([
        LocalFileResolver(),
        DirectOpenStreamResolver(),
        JioSaavnDirectResolver(),
        NativeKotlinResolver(),
        InnerTubeMusicResolver(),
        YoutubeWebSearchResolver(),
      ]);
    }
  }

  @visibleForTesting
  static void clearCacheForTesting() {
    _cache.clear();
    _inFlight.clear();
  }

  static String _cacheKey(Song song) {
    if (song.id.isNotEmpty) return song.id;
    return '${song.title.toLowerCase().trim()}__${song.artist.toLowerCase().trim()}';
  }

  static bool _isOfflineException(Object e) {
    if (e is SocketException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('no address associated with hostname') ||
        msg.contains('connection refused') ||
        msg.contains('no route to host');
  }

  static void invalidateCache(String songId) {
    _cache.remove(songId);
    _cache.removeWhere((key, _) => key.startsWith(songId));
  }

  static Future<String?> resolve(Song song, {int startTier = 0}) async {
    final key = _cacheKey(song);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (startTier == 0 && _cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (now < entry.expiresAt) {
        // Move to most recent for true LRU
        _cache.remove(key);
        _cache[key] = entry;
        return entry.url;
      } else {
        _cache.remove(key);
      }
    }

    if (startTier == 0 && _inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final future = _resolveUncached(song, startTier: startTier);
    if (startTier == 0) {
      _inFlight[key] = future;
    }
    try {
      return await future;
    } finally {
      if (startTier == 0) {
        _inFlight.remove(key);
      }
    }
  }

  static Future<String?> _resolveUncached(Song song, {int startTier = 0}) async {
    final key = _cacheKey(song);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = startTier; i < _resolvers.length; i++) {
      final resolver = _resolvers[i];
      try {
        if (await resolver.canResolve(song)) {
          final url = await resolver.resolveStreamUrl(song);
          if (url != null &&
              url.isNotEmpty &&
              !url.contains('preview') &&
              !url.contains('scdn.co') &&
              _TrustedAudioHosts.isTrusted(url)) {
            // Evict least-recently-inserted (oldest) entry. LRU
            // ordering on read is preserved by re-inserting on hits
            // above; this is FIFO on size pressure, not strict LRU.
            _cache.remove(key);
            if (_cache.length >= 200) {
              _cache.remove(_cache.keys.first);
            }
            _cache[key] = _CacheEntry(url, now, now + _ttlMs);
            return url;
          }
        }
      } catch (e) {
        if (_isOfflineException(e)) {
          // Device is offline / network unreachable: fail-fast to prevent 50+ sec hanging
          break;
        }
      }
    }
    // Final fallback is the Song's own streamUrl, but only when it
    // passes the same host allowlist the resolver chain uses. An
    // untrusted Song.streamUrl must NOT bypass validation.
    if (_TrustedAudioHosts.isTrusted(song.streamUrl)) {
      return song.streamUrl;
    }
    return null;
  }
}
