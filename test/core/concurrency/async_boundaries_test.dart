import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/concurrency/async_boundaries.dart';
import 'package:noctra/core/caching/lru_cache.dart';

void main() {
  group('SingleFlight Concurrency Primitive', () {
    test('concurrent callers with identical keys share single in-flight future', () async {
      final flight = SingleFlight<String, int>();
      int counter = 0;

      Future<int> heavyTask() async {
        await Future.delayed(const Duration(milliseconds: 20));
        return ++counter;
      }

      final results = await Future.wait([
        flight.run('query_1', heavyTask),
        flight.run('query_1', heavyTask),
        flight.run('query_1', heavyTask),
      ]);

      expect(results, equals([1, 1, 1]));
      expect(counter, equals(1));
    });
  });

  group('LatestWinsCoordinator', () {
    test('discards late results from superseded generations', () async {
      final coordinator = LatestWinsCoordinator<String>();
      String? latestResult;

      // Request 1: Takes long to complete (50ms)
      coordinator.execute((gen) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'Result 1';
      }, onLatest: (r) => latestResult = r);

      // Request 2: Supercedes request 1 immediately (10ms)
      await Future.delayed(const Duration(milliseconds: 5));
      await coordinator.execute((gen) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'Result 2';
      }, onLatest: (r) => latestResult = r);

      // Wait for all to finish
      await Future.delayed(const Duration(milliseconds: 60));
      expect(latestResult, equals('Result 2'));
    });
  });

  group('LruCache Bounded Storage & TTL', () {
    test('evicts least-recently used entry when capacity is exceeded', () {
      final cache = LruCache<String, int>(maximumSize: 2);
      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.get('a'), equals(1)); // access 'a', makes 'b' LRU

      cache.put('c', 3); // should evict 'b'
      expect(cache.get('a'), equals(1));
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), equals(3));
    });

    test('expires items after TTL duration', () async {
      final cache = LruCache<String, int>(
        maximumSize: 5,
        defaultTtl: const Duration(milliseconds: 15),
      );
      cache.put('key1', 42);
      expect(cache.get('key1'), equals(42));

      await Future.delayed(const Duration(milliseconds: 25));
      expect(cache.get('key1'), isNull);
    });
  });
}
