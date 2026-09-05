import 'dart:async';

/// Abstract key-value storage contract for preferences and lightweight state.
abstract class KeyValueStorageContract {
  FutureOr<T?> get<T>(String key);
  FutureOr<void> set<T>(String key, T value);
  FutureOr<void> remove(String key);
  FutureOr<bool> containsKey(String key);
  FutureOr<void> clear();
}

/// Abstract database transaction/query contract for structured entities.
abstract class DatabaseContract {
  Future<void> initialize();
  Future<void> close();
  Future<T> transaction<T>(Future<T> Function() action);
}
