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
    if (url.contains('scdn.co') || url.contains('spotify.com') || url.contains('preview') || url.contains('apple.com')) return false;
    return !url.contains('youtube.com') && !url.contains('youtu.be');
  }
  @override
  Future<String?> resolveStreamUrl(Song song) async => song.streamUrl;
}

class JioSaavnDirectResolver implements StreamResolver {
  static const _channel = MethodChannel('com.noctra.app/native_resolver');
  @override
  String get sourceId => 'jiosaavn_320kbps';
  @override
  Future<bool> canResolve(Song song) async {
    final u = song.streamUrl;
    if (u != null && u.isNotEmpty && (u.contains('saavncdn.com') || u.contains('jiosaavn.com'))) return true;
    return song.id.startsWith('saavn_');
  }
  @override
  Future<String?> resolveStreamUrl(Song song) async {
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty && song.streamUrl!.contains('saavncdn.com')) {
      return song.streamUrl;
    }
    if (song.id.startsWith('saavn_')) {
      try {
        final pid = song.id.substring(6);
        final uri = Uri.parse('https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$pid&_format=json&_marker=0&ctx=android');
        final res = await http.get(uri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          // Guard against OOM on malicious or oversized responses
          if (res.contentLength != null && res.contentLength! > 200000) return null;
          if (res.body.length > 200000) return null;
          final data = jsonDecode(res.body);
          final songData = (data is Map ? (data[pid] ?? data.values.firstOrNull) : null) as Map<String, dynamic>?;
          final encUrl = songData?['encrypted_media_url'] as String? ?? songData?['more_info']?['encrypted_media_url'] as String?;
          if (encUrl != null && encUrl.isNotEmpty) {
            final decUrl = await _channel.invokeMethod<String>('decryptUrl', {'encryptedUrl': encUrl});
            if (decUrl != null && decUrl.isNotEmpty) return decUrl;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}

class NativeKotlinResolver implements StreamResolver {
  static const _channel = MethodChannel('com.noctra.app/native_resolver');
  @override
  String get sourceId => 'native_kotlin_320k';
  @override
  Future<bool> canResolve(Song song) async => !kIsWeb && !song.id.startsWith('jam_');
  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      final String? streamUrl = await _channel.invokeMethod<String>('resolve320k', {
        'title': cleanTitle.isNotEmpty ? cleanTitle : song.title,
        'artist': cleanArtist.isNotEmpty ? cleanArtist : song.artist,
      }).timeout(const Duration(seconds: 6));
      if (streamUrl != null && streamUrl.isNotEmpty && !streamUrl.contains('preview')) {
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
    {'clientName': 'ANDROID_TESTSUITE', 'clientVersion': '1.9', 'androidSdkVersion': 30},
    {'clientName': 'ANDROID_MUSIC', 'clientVersion': '6.42.52', 'androidSdkVersion': 34},
    {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'},
    {'clientName': 'TVHTML5', 'clientVersion': '7.20240801.12.00', 'theme': 'TVHTML5'}
  ];

  /// Deep extraction of videoId from any YTMusic result format.
  static String? _extractVideoId(dynamic item) {
    if (item == null || item is! Map) return null;
    // 1. musicResponsiveListItemRenderer (songs, top result)
    final responsive = item['musicResponsiveListItemRenderer'] as Map?;
    if (responsive != null) {
      final vid = responsive['playlistItemData']?['videoId']?.toString() ??
          responsive['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
      if (vid != null && vid.length == 11) return vid;
    }
    // 2. musicTwoRowItemRenderer (artist cards, album cards, playlists)
    final twoRow = item['musicTwoRowItemRenderer'] as Map?;
    if (twoRow != null) {
      final vid = twoRow['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
          twoRow['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString();
      // For watchEndpoint, videoId should be 11 chars; browseEndpoint is longer
      if (vid != null && vid.length == 11) return vid;
    }
    // 3. musicShelfRenderer contents (search shelves)
    final shelf = item['musicShelfRenderer'] as Map?;
    if (shelf != null) {
      final shelfItems = shelf['contents'] as List?;
      if (shelfItems != null && shelfItems.isNotEmpty) {
        final nestedVid = _extractVideoId(shelfItems[0]);
        if (nestedVid != null) return nestedVid;
      }
    }
    // 4. musicResponsiveListItemRenderer flexColumn fallback (some formats)
    if (responsive != null) {
      final flexCols = responsive['flexColumns'] as List?;
      if (flexCols != null) {
        for (final col in flexCols) {
          final runs = (col as Map?)?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
          if (runs != null) {
            for (final run in runs) {
              final navEndpoint = (run as Map?)?['navigationEndpoint']?['watchEndpoint'];
              final vid = navEndpoint?['videoId']?.toString();
              if (vid != null && vid.length == 11) return vid;
            }
          }
        }
      }
    }
    return null;
  }

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      String videoId = song.id;
      if (videoId.length != 11 || videoId.contains('_')) {
        final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
        final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
        final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final sBody = jsonEncode({
          'query': '$cleanTitle $cleanArtist',
          'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}
        });
        final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 6));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body);
          final contents = sData['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
          if (contents != null) {
            for (final sec in contents) {
              final secMap = sec as Map;
              final itemSections = secMap['itemSectionRenderer']?['contents'] as List?;
              final shelfItems = secMap['musicShelfRenderer']?['contents'] as List?;
              final allItems = [...?itemSections, ...?shelfItems];
              for (final item in allItems) {
                final vid = _extractVideoId(item);
                if (vid != null) {
                  videoId = vid;
                  break;
                }
              }
              if (videoId.length == 11) break;
            }
          }
        }
      }

      if (videoId.length == 11) {
        if (!kIsWeb) {
          try {
            final nativeUrl = await const MethodChannel('com.noctra.app/native_resolver').invokeMethod<String>('extractInnerTube', {'videoId': videoId}).timeout(const Duration(seconds: 3));
            if (nativeUrl != null && nativeUrl.isNotEmpty) return nativeUrl;
          } catch (_) {}
        }

        for (final client in innerTubeClients) {
          try {
            final pUri = Uri.parse('https://music.youtube.com/youtubei/v1/player');
            final pBody = jsonEncode({'videoId': videoId, 'context': {'client': client}});
            final pRes = await http.post(pUri, body: pBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 3));
            if (pRes.statusCode == 200) {
              final pData = jsonDecode(pRes.body);
              final formats = pData['streamingData']?['adaptiveFormats'] as List?;
              if (formats != null && formats.isNotEmpty) {
                final audioStreams = formats.where((f) => (f['mimeType'] as String?)?.contains('audio') == true).toList();
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
                  audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
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
  Future<bool> canResolve(Song song) async => !kIsWeb && !song.id.startsWith('jam_');

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
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
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }).timeout(const Duration(seconds: 5));
      if (sRes.statusCode != 200) return null;
      final sData = jsonDecode(sRes.body);
      // Parse videoRenderer items from the standard YouTube search
      String? videoId;
      final contents = sData['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (contents != null) {
        for (final sec in contents) {
          final items = (sec as Map)['itemSectionRenderer']?['contents'] as List?;
          if (items != null) {
            for (final item in items) {
              final vr = (item as Map?)?['videoRenderer'] as Map?;
              final vid = vr?['videoId']?.toString();
              if (vid != null && vid.length == 11) {
                videoId = vid;
                break;
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
          final pBody = jsonEncode({'videoId': videoId, 'context': {'client': client}});
          final pRes = await http.post(pUri, body: pBody, headers: {
            'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'
          }).timeout(const Duration(seconds: 4));
          if (pRes.statusCode == 200) {
            final pData = jsonDecode(pRes.body);
            final formats = pData['streamingData']?['adaptiveFormats'] as List?;
            if (formats != null && formats.isNotEmpty) {
              final audioStreams = formats.where((f) => (f['mimeType'] as String?)?.contains('audio') == true).toList();
              if (audioStreams.isNotEmpty) {
                audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
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
  _CacheEntry(this.url, this.timestamp);
}

class CompositeStreamResolver {
  static final Map<String, _CacheEntry> _cache = {};
  static const int _ttlMs = 12 * 3600 * 1000; // 12-hour TTL

  static final List<StreamResolver> _resolvers = [
    LocalFileResolver(),
    DirectOpenStreamResolver(),
    JioSaavnDirectResolver(),
    NativeKotlinResolver(),
    InnerTubeMusicResolver(),
    YoutubeWebSearchResolver(),
  ];

  static void invalidateCache(String songId) {
    _cache.remove(songId);
  }

  static Future<String?> resolve(Song song, {int startTier = 0}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (startTier == 0 && _cache.containsKey(song.id)) {
      final entry = _cache[song.id]!;
      if (now - entry.timestamp < _ttlMs) {
        // Move to most recent for true LRU
        _cache.remove(song.id);
        _cache[song.id] = entry;
        return entry.url;
      } else {
        _cache.remove(song.id);
      }
    }

    for (int i = startTier; i < _resolvers.length; i++) {
      final resolver = _resolvers[i];
      try {
        if (await resolver.canResolve(song)) {
          final url = await resolver.resolveStreamUrl(song);
          if (url != null && url.isNotEmpty && !url.contains('preview') && !url.contains('scdn.co')) {
            _cache.remove(song.id);
            if (_cache.length >= 200) {
              _cache.remove(_cache.keys.first);
            }
            _cache[song.id] = _CacheEntry(url, now);
            return url;
          }
        }
      } catch (_) {}
    }
    return song.streamUrl;
  }
}
