import 'dart:async';

/// Coordinates single-flight execution so concurrent callers with the same
/// key share the exact same in-flight [Future] rather than duplicating work.
class SingleFlight<K, V> {
  final Map<K, Future<V>> _inFlight = {};

  Future<V> run(K key, Future<V> Function() fn) {
    final active = _inFlight[key];
    if (active != null) return active;

    final future = fn();
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
  }

  void clear() => _inFlight.clear();
}

/// Enforces latest-wins semantics for asynchronous streams or requests.
/// Late results from older generations are automatically discarded.
class LatestWinsCoordinator<T> {
  int _currentGeneration = 0;

  int nextGeneration() => ++_currentGeneration;

  bool isCurrent(int generation) => generation == _currentGeneration;

  Future<T?> execute(
    Future<T> Function(int generation) task, {
    void Function(T result)? onLatest,
  }) async {
    final gen = nextGeneration();
    final result = await task(gen);
    if (isCurrent(gen)) {
      onLatest?.call(result);
      return result;
    }
    return null;
  }
}

/// A lightweight token used to track cancellation or superseded state.
class GenerationToken {
  int _epoch = 0;

  int get epoch => _epoch;

  int increment() => ++_epoch;

  bool isValid(int token) => token == _epoch;
}

/// Simple debounce utility that executes an action only after [duration] has
/// elapsed without new calls.
class AsyncDebouncer {
  final Duration duration;
  Timer? _timer;

  AsyncDebouncer({required this.duration});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
