import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../data/models/song_model.dart';

abstract class StreamResolver {
  String get sourceId;
  Future<bool> canResolve(Song song);
  Future<String?> resolveStreamUrl(Song song);
}

class LocalFileResolver implements StreamResolver {
  @override
  String get sourceId => 'local';
  @override
  Future<bool> canResolve(Song song) async => !kIsWeb && song.localFilePath != null && song.localFilePath!.isNotEmpty;
  @override
  Future<String?> resolveStreamUrl(Song song) async => song.localFilePath;
}

class JioSaavnDirectResolver implements StreamResolver {
  @override
  String get sourceId => 'jiosaavn_320kbps';
  @override
  Future<bool> canResolve(Song song) async {
    final u = song.streamUrl;
    return u != null && u.isNotEmpty && (u.contains('saavncdn.com') || u.contains('jiosaavn.com'));
  }
  @override
  Future<String?> resolveStreamUrl(Song song) async => song.streamUrl;
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

/// Echo Music Style InnerTube YouTube Music Direct REST Extractor
class InnerTubeMusicResolver implements StreamResolver {
  @override
  String get sourceId => 'innertube_echo';
  @override
  Future<bool> canResolve(Song song) async => !song.id.startsWith('jam_');

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
        final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body);
          final contents = sData['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
          if (contents != null && contents is List) {
            for (final section in contents) {
              final items = section['musicShelfRenderer']?['contents'] ?? section['musicCardShelfRenderer']?['contents'];
              if (items is List && items.isNotEmpty) {
                final top = items[0]['musicResponsiveListItemRenderer']?['playlistItemData']?['videoId'] ?? items[0]['musicResponsiveListItemRenderer']?['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'];
                if (top != null) { videoId = top.toString(); break; }
              }
            }
          }
        }
      }

      if (videoId.length == 11) {
        final pUri = Uri.parse('https://music.youtube.com/youtubei/v1/player');
        final pBody = jsonEncode({
          'videoId': videoId,
          'context': {'client': {'clientName': 'ANDROID_MUSIC', 'clientVersion': '6.42.52', 'androidSdkVersion': 34, 'hl': 'en', 'gl': 'US'}}
        });
        final pRes = await http.post(pUri, body: pBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'com.google.android.apps.youtube.music/6.42.52'}).timeout(const Duration(seconds: 4));
        if (pRes.statusCode == 200) {
          final pData = jsonDecode(pRes.body);
          final formats = pData['streamingData']?['adaptiveFormats'] as List?;
          if (formats != null && formats.isNotEmpty) {
            // Find highest bitrate audio stream (e.g. 251 Opus 160kbps or 140 m4a 128kbps)
            final audioStreams = formats.where((f) => (f['mimeType'] as String?)?.contains('audio') == true).toList();
            if (audioStreams.isNotEmpty) {
              audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
              final url = audioStreams[0]['url'] as String?;
              if (url != null && url.isNotEmpty) return url;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

class YoutubeExplodeResolver implements StreamResolver {
  static final YoutubeExplode _yt = YoutubeExplode();
  @override
  String get sourceId => 'youtube_explode';
  @override
  Future<bool> canResolve(Song song) async => !kIsWeb && !song.id.startsWith('jam_');

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      String videoId = song.id;
      if (videoId.length != 11 || videoId.contains('_')) {
        final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'\[.*?\]'), '').trim();
        final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
        final searchResults = await _yt.search.search('$cleanTitle $cleanArtist audio').timeout(const Duration(seconds: 4));
        if (searchResults.isNotEmpty) videoId = searchResults.first.id.value;
      }
      if (videoId.length == 11) {
        final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 4));
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) return audioOnly.withHighestBitrate().url.toString();
      }
    } catch (_) {}
    return null;
  }
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

class CompositeStreamResolver {
  static final List<StreamResolver> _resolvers = [
    LocalFileResolver(),
    JioSaavnDirectResolver(),
    DirectOpenStreamResolver(),
    NativeKotlinResolver(),
    InnerTubeMusicResolver(),
    YoutubeExplodeResolver(),
  ];

  static Future<String?> resolve(Song song) async {
    for (final resolver in _resolvers) {
      try {
        if (await resolver.canResolve(song)) {
          final url = await resolver.resolveStreamUrl(song);
          if (url != null && url.isNotEmpty && !url.contains('preview') && !url.contains('scdn.co')) {
            return url;
          }
        }
      } catch (_) {}
    }
    return song.streamUrl;
  }
}
