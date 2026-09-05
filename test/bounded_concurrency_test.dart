import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/core/utils/bounded_concurrency.dart';

/// Phase 22 regression tests for the artist-lookup request storm.
///
/// Background: every visible Explore Artists card fired a multi-tier
/// Deezer/JioSaavn/iTunes/Wikipedia lookup simultaneously — a 12-artist row
/// could launch 40+ concurrent requests and jank the home screen on slow
/// networks. `BoundedConcurrency` caps in-flight lookups (3) and queues the
/// rest, preserving results for every caller.
void main() {
  test('never runs more than maxConcurrent tasks at once', () async {
    final limiter = BoundedConcurrency(3);
    var inFlight = 0;
    var peak = 0;

    Future<int> task(int id) async {
      inFlight++;
      peak = peak < inFlight ? inFlight : peak;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inFlight--;
      return id;
    }

    final results =
        await Future.wait(List.generate(8, (i) => limiter.run(() => task(i))));
    expect(results, [0, 1, 2, 3, 4, 5, 6, 7]);
    expect(peak, 3, reason: 'peak concurrency must equal the configured cap');
  });

  test('queued tasks run FIFO after slots free up', () async {
    final limiter = BoundedConcurrency(1);
    final order = <int>[];
    final results = await Future.wait(List.generate(4, (i) {
      return limiter.run(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add(i);
        return i;
      });
    }));
    expect(results, [0, 1, 2, 3]);
    expect(order, [0, 1, 2, 3]);
  });

  test('errors propagate to the caller and do not stall the queue', () async {
    final limiter = BoundedConcurrency(1);
    final boom = limiter.run<void>(() async => throw StateError('boom'));
    await expectLater(boom, throwsStateError);

    // The queue must keep draining after an error.
    final value = await limiter.run(() async => 42);
    expect(value, 42);
  });

  test('a single shared limiter serializes heavy bursts', () async {
    final limiter = BoundedConcurrency(2);
    var inFlight = 0;
    var maxSeen = 0;
    final started = <String>[];
    for (var i = 0; i < 10; i++) {
      final id = 'burst-$i';
      unawaited(limiter.run(() async {
        inFlight++;
        maxSeen = inFlight > maxSeen ? inFlight : maxSeen;
        started.add(id);
        await Future<void>.delayed(const Duration(milliseconds: 3));
        inFlight--;
      }));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(started, hasLength(10));
    expect(maxSeen, 2);
  });
}
