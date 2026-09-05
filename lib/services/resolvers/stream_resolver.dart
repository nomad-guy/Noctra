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

  /// Overall wall-clock budget for one uncached resolution pass. Without it,
  /// a song rejected by every tier could wait the full sum of per-tier
  /// timeouts (up to ~40s on slow/unstable networks). The budget caps the
  /// whole chain; tiers that cannot finish inside the remaining time are
  /// skipped so playback fails gracefully instead of hanging.
  static const Duration _defaultResolutionBudget = Duration(seconds: 18);

  /// Below this remaining time a tier is skipped entirely — its internal
  /// timeouts alone would exceed the budget.
  static const Duration _minRemainingTierTime = Duration(milliseconds: 150);

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

  static Future<String?> resolve(Song song,
      {int startTier = 0, Duration? budget}) async {
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

    final future = _resolveUncached(song,
        startTier: startTier, budget: budget ?? _defaultResolutionBudget);
    if (startTier == 0) {
      _inFlight[key] = future;
    }
    // Cancellation/late-result safety: only URLs awaited successfully inside
    // the attempt's own budget are cached (a timed-out tier's underlying
    // request may finish later, but its result is discarded at the timeout
    // boundary and can never reach the cache or a newer caller). The
    // _inFlight entry is always removed here, so a timed-out/cancelled
    // attempt never blocks a subsequent retry for the same song.
    try {
      return await future;
    } finally {
      if (startTier == 0) {
        _inFlight.remove(key);
      }
    }
  }

  static Future<String?> _resolveUncached(Song song,
      {int startTier = 0, Duration? budget}) async {
    final key = _cacheKey(song);
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = budget ?? _defaultResolutionBudget;

    // Single monotonic clock for the whole uncached attempt. `remaining()`
    // MUST be re-evaluated immediately before every blocking operation:
    // a slow canResolve() consumes budget, and passing a stale pre-computed
    // value to resolveStreamUrl() would let a tier exceed the overall
    // deadline (budget canResolve + budget resolve = 2× budget).
    final watch = Stopwatch()..start();
    Duration remaining() {
      final r = total - watch.elapsed;
      return r.isNegative ? Duration.zero : r;
    }

    for (int i = startTier; i < _resolvers.length; i++) {
      if (remaining() < _minRemainingTierTime) {
        // Overall resolution budget exhausted — stop instead of waiting out
        // every remaining tier timeout.
        break;
      }
      final resolver = _resolvers[i];
      try {
        final canBudget = remaining();
        final canResolve = await resolver
            .canResolve(song, timeBudget: canBudget)
            .timeout(canBudget, onTimeout: () => false);
        if (!canResolve) continue;

        // Recompute AFTER canResolve: it consumed part of the budget.
        final resolveBudget = remaining();
        if (resolveBudget < _minRemainingTierTime) {
          // Not enough left for this tier's resolve stage — skip it and let
          // a later (possibly faster) tier try inside its remaining slice.
          continue;
        }
        final url = await resolver
            .resolveStreamUrl(song, timeBudget: resolveBudget)
            .timeout(resolveBudget, onTimeout: () => null);
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
      } catch (e) {
        if (e is TimeoutException) {
          // Budget-managed timeout: drop this tier and continue (the next
          // loop iteration re-checks the remaining time).
          continue;
        }
        if (_isOfflineException(e)) {
          // DNS/offline failures affect every remaining tier — fail fast.
          break;
        }
        // Transient failures (HTTP 5xx/429 surfaces, resets, TLS errors):
        // drop only this tier; never retry it in a loop here.
      }
    }
    if (TrustedAudioHosts.isTrusted(song.streamUrl)) {
      return song.streamUrl;
    }
    return null;
  }
}
