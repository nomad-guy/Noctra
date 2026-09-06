import 'dart:collection';

/// Bounded in-memory LRU (Least Recently Used) cache with optional time-to-live (TTL).
class LruCache<K, V> {
  final int maximumSize;
  final Duration? defaultTtl;
  final LinkedHashMap<K, _CacheEntry<V>> _entries = LinkedHashMap();

  LruCache({required this.maximumSize, this.defaultTtl})
      : assert(maximumSize > 0, 'maximumSize must be greater than zero');

  int get size => _entries.length;

  bool containsKey(K key) {
    _pruneExpired();
    return _entries.containsKey(key);
  }

  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _entries.remove(key);
      return null;
    }

    // Refresh access position in LRU order
    _entries.remove(key);
    _entries[key] = entry;
    return entry.value;
  }

  void put(K key, V value, {Duration? ttl}) {
    _entries.remove(key);

    if (_entries.length >= maximumSize) {
      _entries.remove(_entries.keys.first);
    }

    final effectiveTtl = ttl ?? defaultTtl;
    final expiresAt =
        effectiveTtl != null ? DateTime.now().add(effectiveTtl) : null;
    _entries[key] = _CacheEntry(value, expiresAt);
  }

  V? remove(K key) {
    final entry = _entries.remove(key);
    return entry?.value;
  }

  void clear() {
    _entries.clear();
  }

  void _pruneExpired() {
    if (defaultTtl == null) return;
    final now = DateTime.now();
    _entries.removeWhere((_, entry) => entry.expiresAt != null && now.isAfter(entry.expiresAt!));
  }
}

class _CacheEntry<V> {
  final V value;
  final DateTime? expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
