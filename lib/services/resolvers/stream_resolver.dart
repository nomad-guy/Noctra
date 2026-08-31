import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// youtube_explode_dart removed: NativeKotlinResolver + InnerTubeMusicResolver
// handle YouTube resolution via the Kotlin engine — no Dart-side library needed.
import '../../data/models/song_model.dart';

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
      }).timeout(const Duration(seconds: 4));
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

  static const List<Map<String, dynamic>> _innerTubeClients = [
    {'clientName': 'ANDROID_TESTSUITE', 'clientVersion': '1.9', 'androidSdkVersion': 30},
    {'clientName': 'ANDROID_MUSIC', 'clientVersion': '6.42.52', 'androidSdkVersion': 34},
    {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'},
    {'clientName': 'TVHTML5', 'clientVersion': '7.20240801.12.00', 'theme': 'TVHTML5'}
  ];

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      String videoId = song.id;
      if (videoId.length != 11 || videoId.contains('_')) {
        final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
        final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
        final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final sBody = jsonEncode({
          'query': '$cleanTitle $cleanArtist audio',
          'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}
        });
        final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body);
          final contents = sData['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
          if (contents != null) {
            for (final sec in contents) {
              final items = (sec as Map)['itemSectionRenderer']?['contents'] as List? ?? (sec)['musicShelfRenderer']?['contents'] as List?;
              if (items != null && items.isNotEmpty) {
                final r = (items[0] as Map)['musicResponsiveListItemRenderer'] as Map?;
                final vid = r?['playlistItemData']?['videoId']?.toString() ?? r?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
                if (vid != null && vid.length == 11) { videoId = vid; break; }
              }
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

        for (final client in _innerTubeClients) {
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

// YoutubeExplodeResolver is retained as a named stub so CompositeStreamResolver
// compiles without changes. It always returns null — resolution falls back to
// the cached streamUrl on the Song model.
class YoutubeExplodeResolver implements StreamResolver {
  @override
  String get sourceId => 'youtube_explode_stub';
  @override
  Future<bool> canResolve(Song song) async => false; // disabled: use NativeKotlinResolver
  @override
  Future<String?> resolveStreamUrl(Song song) async => null;
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
    YoutubeExplodeResolver(),
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
