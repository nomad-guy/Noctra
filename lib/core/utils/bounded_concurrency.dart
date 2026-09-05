import 'dart:async';

/// Runs async tasks with at most [maxConcurrent] executions in flight.
///
/// Excess tasks queue FIFO and start as slots free up. The returned Future
/// completes only when the underlying task completes (or errors), so it is
/// safe to share locked results through in-flight dedup maps — a queued
/// caller receives the same outcome as a running one, and neither observes
/// an artificial early completion.
///
/// Motivation: the Explore Artists carousel mounts several cards at once and
/// each artist lookup fans out across multiple upstreams; without a bound the
/// row launched tens of simultaneous requests on slow networks.
class BoundedConcurrency {
  BoundedConcurrency(this.maxConcurrent);

  final int maxConcurrent;
  int _active = 0;
  final List<Future<void> Function()> _queue = [];

  Future<T> run<T>(Future<T> Function() task) {
    if (_active < maxConcurrent) {
      _active++;
      return task().whenComplete(() {
        _active--;
        _drain();
      });
    }
    final completer = Completer<T>();
    _queue.add(() async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _active++;
      next().whenComplete(() {
        _active--;
        _drain();
      });
    }
  }
}
