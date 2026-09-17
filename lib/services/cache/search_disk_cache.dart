import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';

/// Disk-backed search-result cache.
///
/// Purpose: on slow networks or offline, a query the user has searched
/// before should still return results instead of an empty list. The
/// in-memory cache in `MusicService` handles the hot path; this layer
/// persists the same entries across app restarts.
///
/// Storage: one JSON file per bucket (latest 5 minutes of queries are the
/// hot set; everything the user searched this session gets a stale copy
/// that is still good enough to display offline). Writes are debounced and
/// batched — one file rewrite per burst, never per keystroke.
///
/// Records are fault-isolated: one malformed entry is skipped, never fatal.
class SearchDiskCache {
  SearchDiskCache._internal();
  static final SearchDiskCache instance = SearchDiskCache._internal();

  static const int _maxEntries = 120;
  static const Duration _freshTtl = Duration(minutes: 30);
  // Stale entries stay readable for 30 days — offline UX beats freshness
  // when there is no network at all.
  static const Duration _staleTtl = Duration(days: 30);

  File? _file;
  Map<String, Map<String, dynamic>> _entries = {};
  bool _loaded = false;
  Timer? _flushTimer;
  bool _dirty = false;

  File get _cacheFile {
    if (_file != null) return _file!;
    // Lazy: path_provider is only safe after platform binding exists.
    final dir = Directory.systemTemp;
    _file = File('${dir.path}${Platform.pathSeparator}noctra_search_cache.json');
    return _file!;
  }

  /// Allows tests / bootstrap to pin the storage location before first use.
  static void configure(String directoryPath) {
    instance._file = File('$directoryPath${Platform.pathSeparator}'
        'noctra_search_cache.json');
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = _cacheFile;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _entries = decoded.map((k, v) =>
          MapEntry(k.toString(), v is Map<String, dynamic> ? v : <String, dynamic>{}));
    } catch (e) {
      // Corrupt cache: start clean, never propagate.
      NoctraLogger.w('SearchDiskCache: load failed, starting clean', e);
      _entries = {};
    }
  }

  Future<void> _scheduleFlush() async {
    _dirty = true;
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 3), () {
      if (_dirty) unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      await _ensureLoaded();
      // Evict hard-expired + oldest overflow before writing.
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - _staleTtl.inMilliseconds;
      _entries.removeWhere((_, v) {
        final ts = (v['ts'] as num?)?.toInt() ?? 0;
        return ts < cutoff;
      });
      while (_entries.length > _maxEntries) {
        String? oldest;
        int? oldestTs;
        for (final e in _entries.entries) {
          final ts = (e.value['ts'] as num?)?.toInt() ?? 0;
          if (oldestTs == null || ts < oldestTs) {
            oldest = e.key;
            oldestTs = ts;
          }
        }
        if (oldest == null) break;
        _entries.remove(oldest);
      }
      final tmp = File('${_cacheFile.path}.tmp');
      await tmp.writeAsString(jsonEncode(_entries), flush: true);
      await tmp.rename(_cacheFile.path);
    } catch (e) {
      NoctraLogger.w('SearchDiskCache: flush failed', e);
    }
  }

  /// Returns results for [cacheKey] recorded by a previous session, or null.
  /// [allowStale] accepts entries past the fresh TTL (offline path).
  Future<List<Song>?> get(String cacheKey, {bool allowStale = false}) async {
    if (kIsWeb) return null;
    try {
      await _ensureLoaded();
      final entry = _entries[cacheKey];
      if (entry == null) return null;
      final ts = (entry['ts'] as num?)?.toInt() ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = now - ts;
      if (age > _freshTtl.inMilliseconds && !allowStale) return null;
      if (age > _staleTtl.inMilliseconds) {
        _entries.remove(cacheKey);
        return null;
      }
      final list = entry['results'];
      if (list is! List) return null;
      final songs = <Song>[];
      for (final item in list) {
        try {
          if (item is Map<String, dynamic>) {
            songs.add(Song.fromJson(item));
          } else if (item is Map) {
            songs.add(Song.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip malformed record — fault isolation per entry.
        }
      }
      return songs.isEmpty ? null : songs;
    } catch (e) {
      NoctraLogger.w('SearchDiskCache: get failed', e);
      return null;
    }
  }

  /// Records results for [cacheKey]. Fire-and-forget; failures are logged
  /// and swallowed — the memory cache remains the source of truth.
  Future<void> put(String cacheKey, List<Song> results) async {
    if (kIsWeb || results.isEmpty) return;
    try {
      await _ensureLoaded();
      _entries[cacheKey] = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'results': results.map((s) => s.toJson()).toList(),
      };
      await _scheduleFlush();
    } catch (e) {
      NoctraLogger.w('SearchDiskCache: put failed', e);
    }
  }

  /// Test hook / logout hygiene: drop everything.
  Future<void> clear() async {
    _entries = {};
    _dirty = false;
    _flushTimer?.cancel();
    try {
      if (await _cacheFile.exists()) await _cacheFile.delete();
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTesting() {
    instance._file = null;
    instance._entries = {};
    instance._loaded = false;
    instance._flushTimer?.cancel();
    instance._dirty = false;
  }
}
