import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A prefs store whose FIRST write to a chosen key blocks on a gate.
///
/// This simulates a slow platform write: two rapid `setString` calls for the
/// same key can therefore complete OUT OF ORDER (the older call finishing
/// last). The regression tests below prove the database layer serializes its
/// full-snapshot writes so the newest state always lands last — even when
/// the platform would otherwise reorder completion.
class _GatedPrefsStore extends SharedPreferencesStorePlatform {
  _GatedPrefsStore(this._gatedKey) : super();

  final String _gatedKey;
  final Map<String, Object> _data = {};
  final Completer<void> _gate = Completer<void>();
  final Completer<void> _gateReached = Completer<void>();
  bool _gated = false;

  // SharedPreferences prefixes keys with 'flutter.' before hitting the store.
  static const _prefix = 'flutter.';
  bool _matches(String key) => key == _gatedKey || key == '$_prefix$_gatedKey';

  /// Completes once the first (gated) write has parked on the gate.
  Future<void> get gateReached => _gateReached.future;

  Future<void> releaseGate() async {
    if (!_gate.isCompleted) _gate.complete();
    // Give the released write a chance to finish.
    await Future<void>.delayed(Duration.zero);
  }

  String? rawString(String key) =>
      (_data[key] ?? _data['$_prefix$key']) as String?;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_matches(key) && !_gated) {
      _gated = true;
      if (!_gateReached.isCompleted) _gateReached.complete();
      await _gate.future;
    }
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map.of(_data);
}

Song _song(String id, {String? path}) => Song(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      localFilePath: path,
      duration: const Duration(seconds: 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedPrefsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _GatedPrefsStore('_none_');
    SharedPreferencesStorePlatform.instance = store;
    NoctraLocalDatabase().debugResetForTest();
    MusicRepository().debugResetForTest();
  });

  // Let queued prefs writes (and the platform store) drain.
  Future<void> drainWrites() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('serialized full-snapshot prefs writes', () {
    test(
        'favorites: newest snapshot wins even when the older write '
        'completes last', () async {
      final db = NoctraLocalDatabase();
      // Re-point the gate at the favorites key AFTER getInstance cached prefs,
      // then simulate two rapid toggle writes where the FIRST write is slow.
      store = _GatedPrefsStore('noctra_favs');
      SharedPreferencesStorePlatform.instance = store;

      final f1 = db.saveFavorites([_song('A')]); // slow write (gated)
      await store.gateReached; // f1 is now parked on the gate
      final f2 = db.saveFavorites([_song('B')]); // fast write
      await Future<void>.delayed(Duration.zero);

      // Release the older write AFTER the newer one already completed.
      await store.releaseGate();
      await Future.wait([f1, f2]);

      final raw = store.rawString('noctra_favs');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect((decoded.single as Map)['id'], 'B',
          reason: 'disk must hold the newest snapshot, not the stale one');
    });

    test('downloads: newest snapshot wins under reordered completion',
        () async {
      final db = NoctraLocalDatabase();
      store = _GatedPrefsStore('noctra_downloads');
      SharedPreferencesStorePlatform.instance = store;

      final f1 = db.saveDownloads([_song('X')]);
      await store.gateReached;
      final f2 = db.saveDownloads([_song('Y')]);
      await Future<void>.delayed(Duration.zero);
      await store.releaseGate();
      await Future.wait([f1, f2]);

      final decoded = jsonDecode(store.rawString('noctra_downloads')!) as List;
      expect((decoded.single as Map)['id'], 'Y');
    });

    test(
        'playback position: the last-issued position wins — a stale song '
        'write cannot overwrite a newer song', () async {
      final db = NoctraLocalDatabase();
      store = _GatedPrefsStore('noctra_last_playback');
      SharedPreferencesStorePlatform.instance = store;

      final songA = _song('A');
      final songB = _song('B');

      // Song A stops at 100 s; its (slow) write is in flight.
      final fA = db.savePlaybackPosition(songA, 100000);
      await store.gateReached; // A's write is parked on the gate
      // User skips to song B; B's write is issued after A's.
      final fB = db.savePlaybackPosition(songB, 5000);
      await Future<void>.delayed(Duration.zero);
      // A's slow write completes only after B's fast write.
      await store.releaseGate();
      await Future.wait([fA, fB]);

      final raw = store.rawString('noctra_last_playback')!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect((decoded['song'] as Map)['id'], 'B',
          reason: 'restart must resume song B, never the stale song A');
      expect(decoded['positionMs'], 5000);
    });

    test('manifest play counters are not lost when play records overlap',
        () async {
      final db = NoctraLocalDatabase();
      store = _GatedPrefsStore('noctra_kg_manifests');
      SharedPreferencesStorePlatform.instance = store;

      final song = _song('K1');

      final f1 = db.recordManifest(song, action: 'play');
      await store.gateReached;
      final f2 = db.recordManifest(song, action: 'play');
      final f3 = db.recordManifest(song, action: 'skip');
      await Future<void>.delayed(Duration.zero);
      await store.releaseGate();
      await Future.wait([f1, f2, f3]);

      final raw = store.rawString('noctra_kg_manifests')!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final manifest = decoded['K1'] as Map<String, dynamic>;
      expect(manifest['playCount'], 2,
          reason: 'two overlapping play records must both be counted');
      expect(manifest['skipCount'], 1);
    });

    test('taste vector: newest write wins after rapid updates', () async {
      final db = NoctraLocalDatabase();
      store = _GatedPrefsStore('noctra_taste_vector');
      SharedPreferencesStorePlatform.instance = store;

      final v1 = List<double>.filled(32, 0.3);
      final v2 = List<double>.filled(32, 0.9);
      final f1 = db.saveTasteVector(v1);
      await store.gateReached;
      final f2 = db.saveTasteVector(v2);
      await Future<void>.delayed(Duration.zero);
      await store.releaseGate();
      await Future.wait([f1, f2]);

      final decoded =
          jsonDecode(store.rawString('noctra_taste_vector')!) as List;
      expect(decoded.every((e) => e == 0.9), isTrue);
    });
  });

  group('user-state ownership / stamping', () {
    test('favoriting a resolver song stamps current local download state',
        () async {
      final repo = MusicRepository();
      final db = NoctraLocalDatabase();

      // Song is downloaded offline first (local truth).
      repo.addDownloadedSong(
          _song('S1', path: '/storage/emulated/0/Noctra/S1.mp3'));
      await drainWrites();

      // A fresh resolver copy claims isDownloaded=false (stale remote truth).
      final resolverCopy = _song('S1');
      repo.toggleFavorite(resolverCopy);
      await drainWrites();

      expect(repo.favorites, hasLength(1));
      final fav = repo.favorites.first;
      expect(fav.isFavorite, isTrue);
      expect(fav.isDownloaded, isTrue,
          reason: 'local download state must survive a stale resolver copy');
      expect(fav.localFilePath, '/storage/emulated/0/Noctra/S1.mp3');

      // And the persisted favorite row carries the same stamp.
      final saved = await db.loadFavorites();
      expect(saved.first.isDownloaded, isTrue);
      expect(saved.first.localFilePath, '/storage/emulated/0/Noctra/S1.mp3');
    });

    test('duplicate favorite toggle add/remove settles on the final state',
        () async {
      final repo = MusicRepository();
      final db = NoctraLocalDatabase();
      final song = _song('S2');

      repo.toggleFavorite(song); // add
      repo.toggleFavorite(song); // remove — final state should be empty
      await drainWrites();

      expect(repo.isFavorite(song.id), isFalse);
      final saved = await db.loadFavorites();
      expect(saved, isEmpty,
          reason: 'rapid add+remove must not resurrect the favorite');
    });
  });
}
