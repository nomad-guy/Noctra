import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../data/models/song_model.dart';
import 'trusted_audio_hosts.dart';

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
    if (!TrustedAudioHosts.isTrusted(url)) return false;
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
