import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../features/discovery/domain/stream_resolver_contract.dart';
import '../../data/models/song_model.dart';
import 'trusted_audio_hosts.dart';

/// Caps an internal network timeout by [budget] (the remaining time of the
/// caller's overall resolution budget) when the budget is tighter. Lets a
/// resolver's own requests fail at the shared deadline instead of running
/// on past it after the composite has given up on the tier.
Duration boundedTimeout(Duration? budget, Duration internal) {
  if (budget == null) return internal;
  return internal <= budget ? internal : budget;
}

abstract class StreamResolver implements StreamResolverContract {
  @override
  String get sourceId;

  /// [timeBudget] is the remaining time of the caller's overall resolution
  /// budget. Cheap/local checks may ignore it; network checks must not run
  /// longer than it.
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget});

  /// Same [timeBudget] contract as [canResolve]. Implementations must bound
  /// every blocking network stage by it and close/cancel their HTTP client
  /// when the budget expires, so a timed-out tier does not leave orphaned
  /// requests running.
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget});
}

class LocalFileResolver implements StreamResolver {
  @override
  String get sourceId => 'local_offline';
  @override
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async {
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
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async =>
      song.localFilePath;
}

class DirectOpenStreamResolver implements StreamResolver {
  @override
  String get sourceId => 'direct_open';
  @override
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async {
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
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async =>
      song.streamUrl;
}

class JioSaavnDirectResolver implements StreamResolver {
  static const _channel = MethodChannel('com.nomadguy.noctra/native_resolver');
  @override
  String get sourceId => 'jiosaavn_320kbps';
  @override
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async {
    final u = song.streamUrl;
    if (u != null &&
        u.isNotEmpty &&
        (u.contains('saavncdn.com') || u.contains('jiosaavn.com'))) {
      return true;
    }
    return song.id.startsWith('saavn_');
  }

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    if (song.streamUrl != null &&
        song.streamUrl!.isNotEmpty &&
        song.streamUrl!.contains('saavncdn.com')) {
      return song.streamUrl;
    }
    if (song.id.startsWith('saavn_')) {
      final pid = song.id.substring(6);
      final uri = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$pid&_format=json&_marker=0&ctx=android');
      // Per-attempt client so the request can actually be aborted when the
      // shared resolution budget expires (top-level http.get would keep the
      // socket open until its own 4 s cap with no way to cancel).
      final client = http.Client();
      try {
        final cap = boundedTimeout(timeBudget, const Duration(seconds: 4));
        final res = await client
            .get(uri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(cap);
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
      } on TimeoutException {
        // Budget expired: client.close() below aborts the in-flight GET.
        return null;
      } catch (_) {
        return null;
      } finally {
        client.close();
      }
    }
    return null;
  }
}

class NativeKotlinResolver implements StreamResolver {
  static const _channel = MethodChannel('com.nomadguy.noctra/native_resolver');
  @override
  String get sourceId => 'native_kotlin_320k';
  @override
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async =>
      !kIsWeb && !song.id.startsWith('jam_');

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    try {
      final cleanTitle = song.title
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      // The native call itself cannot be cancelled from Dart once invoked;
      // bound the wait by the shared budget (the Kotlin engine also has its
      // own connect/read timeouts) and simply discard a late result.
      final cap = boundedTimeout(timeBudget, const Duration(seconds: 6));
      final String? streamUrl =
          await _channel.invokeMethod<String>('resolve320k', {
        'title': cleanTitle.isNotEmpty ? cleanTitle : song.title,
        'artist': cleanArtist.isNotEmpty ? cleanArtist : song.artist,
      }).timeout(cap);
      if (streamUrl != null &&
          streamUrl.isNotEmpty &&
          !streamUrl.contains('preview')) {
        return streamUrl;
      }
    } catch (_) {}
    return null;
  }
}
