import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/resolvers/stream_resolver.dart';

/// Phase 20.1 regression tests: the composite resolution budget must be a
/// true end-to-end deadline over the whole uncached attempt.
///
/// Background: the Phase 20 budget computed `remaining` ONCE per tier and
/// reused it for both `canResolve()` and `resolveStreamUrl()`. A slow
/// `canResolve()` therefore let the tier spend up to 2× the budget
/// (canResolve budget + resolve budget). It also never cancelled the
/// underlying request, so a timed-out tier's network work kept running and
/// `_inFlight`/cache behavior on abandonment needed proof.
///
/// Fixes under test:
///  * a single monotonic stopwatch deadline with `remaining()` recomputed
///    immediately before every blocking stage;
///  * tiers receive the remaining slice as `timeBudget` so their own requests
///    are truncated/closed at the shared deadline;
///  * late results from abandoned tiers are discarded (never cached) and
///    `_inFlight` is always cleared so a retry works;
///  * offline-class errors break the chain, transient errors (resets/429/5xx)
///    drop only the failing tier without a retry loop.
Song _song({String id = 'res_t', String? streamUrl}) => Song(
      id: id,
      title: 'Resolver Test Track',
      artist: 'Test Artist',
      duration: const Duration(seconds: 200),
      streamUrl: streamUrl,
    );

/// Resolver whose canResolve and resolve stages each sleep [delay]; used to
/// prove the shared budget is enforced end-to-end, not per stage.
class _SlowBothStagesResolver implements StreamResolver {
  final Duration delay;
  _SlowBothStagesResolver(this.delay);
  @override
  String get sourceId => 'slow_both';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async {
    await Future<void>.delayed(delay);
    return true;
  }

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    await Future<void>.delayed(delay);
    return null;
  }
}

/// canResolve sleeps [delay] then reports false (burns budget cheaply).
class _SlowCanResolveFalseResolver implements StreamResolver {
  final Duration delay;
  _SlowCanResolveFalseResolver(this.delay);
  @override
  String get sourceId => 'slow_can_false';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async {
    await Future<void>.delayed(delay);
    return false;
  }

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async =>
      null;
}

/// Fails after [delay] and counts calls.
class _SlowFailingResolver implements StreamResolver {
  final Duration delay;
  int resolveCalls = 0;
  _SlowFailingResolver(this.delay);
  @override
  String get sourceId => 'slow_fail';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    resolveCalls++;
    await Future<void>.delayed(delay);
    return null;
  }
}

class _FastSuccessResolver implements StreamResolver {
  final String url;
  _FastSuccessResolver(
      {this.url = 'https://storage.googleapis.com/test/track.mp3'});
  @override
  String get sourceId => 'fast_ok';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async =>
      url;
}

/// Resolve sleeps [delay] then returns a URL — the late result the budget
/// must discard.
class _LateSuccessResolver implements StreamResolver {
  final Duration delay;
  _LateSuccessResolver(this.delay);
  @override
  String get sourceId => 'late_ok';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    await Future<void>.delayed(delay);
    return 'https://aac.saavncdn.com/late.mp4';
  }
}

/// Throws [error] from resolve; canResolve is cheap.
class _ThrowingResolver implements StreamResolver {
  final Object error;
  int resolveCalls = 0;
  _ThrowingResolver(this.error);
  @override
  String get sourceId => 'throws';
  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;
  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    resolveCalls++;
    throw error;
  }
}

void main() {
  tearDown(() {
    CompositeStreamResolver.setResolversForTesting(null);
    CompositeStreamResolver.clearCacheForTesting();
  });

  group('end-to-end deadline', () {
    test(
        'budget is shared across canResolve+resolve: 700ms+700ms stages '
        'finish near a 1000ms budget, not ~1400ms', () async {
      // Regression: remaining was computed once before canResolve() and then
      // reused for resolveStreamUrl(), so a slow canResolve() let the tier
      // consume budget + full resolve timeout (≈2× budget). The composite
      // must recompute the remaining time before the resolve stage.
      CompositeStreamResolver.setResolversForTesting(
          [_SlowBothStagesResolver(const Duration(milliseconds: 700))]);
      final watch = Stopwatch()..start();
      final url = await CompositeStreamResolver.resolve(_song(),
          budget: const Duration(milliseconds: 1000));
      watch.stop();

      expect(url, isNull);
      // New code: 700ms canResolve + resolve truncated at ~300ms remaining.
      expect(watch.elapsedMilliseconds, lessThan(1250),
          reason: 'resolve stage must be truncated by the remaining budget');
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(850),
          reason: 'the canResolve stage must still be allowed to run');
    });

    test('slow canResolve() does not starve a fast later resolver', () async {
      // Tier 1 burns 800ms of a 1200ms budget in canResolve (false); tier 2
      // is instant. The stale-timeout bug would leave tier 2 with a stale
      // (too generous) budget; the fix recomputes so tier 2 still has the
      // ~400ms it needs.
      CompositeStreamResolver.setResolversForTesting([
        _SlowCanResolveFalseResolver(const Duration(milliseconds: 800)),
        _FastSuccessResolver(),
      ]);
      final watch = Stopwatch()..start();
      final url = await CompositeStreamResolver.resolve(_song(),
          budget: const Duration(milliseconds: 1200));
      watch.stop();
      expect(url, 'https://storage.googleapis.com/test/track.mp3');
      expect(watch.elapsedMilliseconds, lessThan(1150));
    });

    test('single monotonic deadline bounds the whole uncached attempt',
        () async {
      // 6 tiers of 400ms each under a 1000ms budget: the chain must stop at
      // ~1s regardless of how many tiers could still run.
      final resolvers = List<StreamResolver>.generate(
          6, (_) => _SlowFailingResolver(const Duration(milliseconds: 400)));
      CompositeStreamResolver.setResolversForTesting(resolvers);
      final watch = Stopwatch()..start();
      final url = await CompositeStreamResolver.resolve(_song(),
          budget: const Duration(milliseconds: 1000));
      watch.stop();
      expect(url, isNull);
      expect(watch.elapsedMilliseconds, lessThan(1250));
    });
  });

  group('cancellation / late results', () {
    test(
        'a late success after the budget expires is discarded, in-flight '
        'clears, and a fresh attempt succeeds', () async {
      // 700ms resolve vs 400ms budget: the composite abandons the tier at the
      // budget. The underlying resolver would have returned a URL at 700ms —
      // that late result must not reach the cache or block later attempts.
      CompositeStreamResolver.setResolversForTesting(
          [_LateSuccessResolver(const Duration(milliseconds: 700))]);
      final url = await CompositeStreamResolver.resolve(_song(),
          budget: const Duration(milliseconds: 400));
      expect(url, isNull);

      // Immediate follow-up with a fast resolver: must not hit a stale cache
      // entry (the late 700ms URL) and must not be blocked by a stuck
      // _inFlight entry from the abandoned attempt.
      const fresh = 'https://storage.googleapis.com/test/fresh.mp3';
      CompositeStreamResolver.setResolversForTesting(
          [_FastSuccessResolver(url: fresh)]);
      final watch = Stopwatch()..start();
      final retry = await CompositeStreamResolver.resolve(_song());
      watch.stop();
      expect(retry, fresh);
      expect(watch.elapsedMilliseconds, lessThan(800));
    });

    test('_inFlight is cleared even when every tier times out', () async {
      CompositeStreamResolver.setResolversForTesting(
          [_SlowFailingResolver(const Duration(seconds: 5))]);
      final first = await CompositeStreamResolver.resolve(_song(),
          budget: const Duration(milliseconds: 200));
      expect(first, isNull);
      // A second resolution for the same key must start fresh (no shared
      // stale future); swapping in a fast resolver proves it runs now.
      CompositeStreamResolver.setResolversForTesting([_FastSuccessResolver()]);
      final second = await CompositeStreamResolver.resolve(_song());
      expect(second, isNotNull);
    });
  });

  group('failure classification', () {
    test('offline-class error breaks the chain immediately', () async {
      final throwing = _ThrowingResolver(
          const SocketException('Failed host lookup: no.internet'));
      final never = _SlowFailingResolver(const Duration(milliseconds: 50));
      CompositeStreamResolver.setResolversForTesting([throwing, never]);
      final url = await CompositeStreamResolver.resolve(_song());
      expect(url, isNull);
      expect(throwing.resolveCalls, 1);
      expect(never.resolveCalls, 0,
          reason: 'must not attempt further tiers when offline');
    });

    test('transient connection reset drops only the tier, then fallback runs',
        () async {
      final throwing =
          _ThrowingResolver(http.ClientException('Connection reset by peer'));
      CompositeStreamResolver.setResolversForTesting(
          [throwing, _FastSuccessResolver()]);
      final url = await CompositeStreamResolver.resolve(_song());
      expect(url, 'https://storage.googleapis.com/test/track.mp3');
      expect(throwing.resolveCalls, 1,
          reason: 'a transient failure must not be retried in a loop');
    });

    test('429/5xx refusals move to the next tier without a retry loop',
        () async {
      final throwing =
          _ThrowingResolver(http.ClientException('429 Too Many Requests'));
      final throwing2 =
          _ThrowingResolver(http.ClientException('503 Service Unavailable'));
      CompositeStreamResolver.setResolversForTesting(
          [throwing, throwing2, _FastSuccessResolver()]);
      final url = await CompositeStreamResolver.resolve(_song());
      expect(url, 'https://storage.googleapis.com/test/track.mp3');
      expect(throwing.resolveCalls, 1);
      expect(throwing2.resolveCalls, 1);
    });
  });
}
