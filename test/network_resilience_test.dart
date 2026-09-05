import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/resolvers/stream_resolver.dart';

/// Phase 20 regression tests: slow-network resilience of the resolver chain.
///
/// Background: CompositeStreamResolver iterated every tier with no overall
/// deadline, so on a slow/unstable network a song rejected by all tiers could
/// wait the full sum of per-tier timeouts (≈40s) while the player sat in a
/// loading state. The chain now enforces a bounded overall resolution budget
/// and skips tiers that cannot finish inside the remaining time. Offline
/// detection still short-circuits the whole chain.
///
/// (The Phase 20.1 end-to-end deadline / cancellation / failure-class tests
/// live in resolver_deadline_test.dart.)
Song _song({String id = 'res_t', String? streamUrl}) => Song(
      id: id,
      title: 'Resolver Test Track',
      artist: 'Test Artist',
      duration: const Duration(seconds: 200),
      streamUrl: streamUrl,
    );

/// A resolver that sleeps [delay] before answering, then fails (null URL).
class _SlowFailingResolver implements StreamResolver {
  final Duration delay;
  _SlowFailingResolver(this.delay);
  @override
  String get sourceId => 'slow_fail';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    await Future<void>.delayed(delay);
    return null;
  }
}

class _FastSuccessResolver implements StreamResolver {
  @override
  String get sourceId => 'fast_ok';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async =>
      'https://storage.googleapis.com/test/track.mp3';
}

class _OfflineResolver implements StreamResolver {
  @override
  String get sourceId => 'offline';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    throw const SocketException('Network is unreachable');
  }
}

void main() {
  tearDown(() {
    CompositeStreamResolver.setResolversForTesting(null);
    CompositeStreamResolver.clearCacheForTesting();
  });

  group('bounded resolution budget', () {
    test(
        'all-tiers-fail returns within the budget instead of the sum of '
        'tier timeouts', () async {
      // 5 slow tiers × 400 ms = 2000 ms unbounded.
      final resolvers = List<StreamResolver>.generate(
          5, (_) => _SlowFailingResolver(const Duration(milliseconds: 400)));
      CompositeStreamResolver.setResolversForTesting(resolvers);

      final watch = Stopwatch()..start();
      final url = await CompositeStreamResolver.resolve(
        _song(),
        budget: const Duration(milliseconds: 1000),
      );
      watch.stop();

      expect(url, isNull);
      // Budget consumed ≈ 1200 ms (3 tiers + one more partial); the old code
      // took ≥2000 ms. Assert comfortably inside that bound.
      expect(watch.elapsedMilliseconds, lessThan(1900),
          reason: 'resolution must stop near the budget, not the timeout sum');
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(700));
    });

    test('a slow early tier does not starve a fast later success', () async {
      CompositeStreamResolver.setResolversForTesting([
        _SlowFailingResolver(const Duration(milliseconds: 900)),
        _FastSuccessResolver(),
      ]);
      final url = await CompositeStreamResolver.resolve(
        _song(),
        budget: const Duration(seconds: 3),
      );
      expect(url, 'https://storage.googleapis.com/test/track.mp3');
    });

    test('default budget still resolves through several normal tiers',
        () async {
      // 3 slow-but-finite failures followed by a success inside the default
      // 18 s budget must succeed (guards against over-aggressive trimming).
      CompositeStreamResolver.setResolversForTesting([
        _SlowFailingResolver(const Duration(milliseconds: 250)),
        _SlowFailingResolver(const Duration(milliseconds: 250)),
        _SlowFailingResolver(const Duration(milliseconds: 250)),
        _FastSuccessResolver(),
      ]);
      final url = await CompositeStreamResolver.resolve(_song());
      expect(url, isNotNull);
    });
  });

  group('offline behavior', () {
    test(
        'offline exception breaks the chain and falls back to a trusted '
        'existing streamUrl', () async {
      CompositeStreamResolver.setResolversForTesting([_OfflineResolver()]);
      final song =
          _song(streamUrl: 'https://storage.googleapis.com/cached.mp3');
      final watch = Stopwatch()..start();
      final url = await CompositeStreamResolver.resolve(song);
      watch.stop();
      expect(url, song.streamUrl);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });

    test('offline without a trusted fallback returns null quickly', () async {
      CompositeStreamResolver.setResolversForTesting([_OfflineResolver()]);
      final watch = Stopwatch()..start();
      final url = await CompositeStreamResolver.resolve(_song());
      watch.stop();
      expect(url, isNull);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('cache safety', () {
    test('failed resolutions do not poison the cache', () async {
      CompositeStreamResolver.setResolversForTesting([
        _SlowFailingResolver(const Duration(milliseconds: 100)),
      ]);
      expect(
          await CompositeStreamResolver.resolve(_song(),
              budget: const Duration(milliseconds: 600)),
          isNull);
      // A second attempt must try the network again, not replay a failure.
      CompositeStreamResolver.setResolversForTesting([_FastSuccessResolver()]);
      final url = await CompositeStreamResolver.resolve(_song());
      expect(url, isNotNull);
    });
  });
}
