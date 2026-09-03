import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/song_model.dart';
import 'innertube_resolver.dart';
import 'stream_resolver_base.dart';
import 'trusted_audio_hosts.dart';
import 'youtube_web_search_resolver.dart';

export 'innertube_resolver.dart';
export 'stream_resolver_base.dart';
export 'trusted_audio_hosts.dart';
export 'youtube_web_search_resolver.dart';

class _CacheEntry {
  final String url;
  final int timestamp;
  final int expiresAt;
  _CacheEntry(this.url, this.timestamp, this.expiresAt);
}

class CompositeStreamResolver {
  static final Map<String, _CacheEntry> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};
  static const int _ttlMs = 30 * 60 * 1000;

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

  static Future<String?> _resolveUncached(Song song,
      {int startTier = 0}) async {
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
              TrustedAudioHosts.isTrusted(url)) {
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
          break;
        }
      }
    }
    if (TrustedAudioHosts.isTrusted(song.streamUrl)) {
      return song.streamUrl;
    }
    return null;
  }
}
