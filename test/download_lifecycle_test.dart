import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/migration_models.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/migration/track_matcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Song _song(String id, {String? title, String? artist, String? path}) => Song(
      id: id,
      title: title ?? 'Track $id',
      artist: artist ?? 'Artist',
      localFilePath: path,
      duration: const Duration(seconds: 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    MusicRepository().debugResetForTest();
  });

  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('download lifecycle (deletion + pruning)', () {
    test('removeDownloadedSong removes the entry and persists the list',
        () async {
      final repo = MusicRepository();
      final db = NoctraLocalDatabase();

      repo.addDownloadedSong(_song('D1', path: '/fake/D1.mp3'));
      await drain();
      expect(repo.downloads, hasLength(1));

      await repo.removeDownloadedSong('D1', deleteFile: false);
      await drain();

      expect(repo.downloads, isEmpty);
      expect(await db.loadDownloads(), isEmpty,
          reason: 'removal must be persisted, not just in-memory');
    });

    test(
        'removeDownloadedSong un-stamps favorite rows pointing at the '
        'removed download', () async {
      final repo = MusicRepository();
      repo.addDownloadedSong(_song('D2', path: '/fake/D2.mp3'));
      await drain();
      repo.addSongsToFavorites([_song('D2')]); // favorite stamped as downloaded
      await drain();
      final fav = repo.favorites.first;
      expect(fav.isDownloaded, isTrue);
      expect(fav.localFilePath, '/fake/D2.mp3');

      await repo.removeDownloadedSong('D2', deleteFile: false);
      await drain();

      final after = repo.favorites.first;
      expect(after.isDownloaded, isFalse,
          reason: 'a removed download must not keep advertising a file');
      expect(after.localFilePath, isNull);
    });

    test('removeDownloadedSong deletes the local file when asked', () async {
      final dir = await Directory.systemTemp.createTemp('noctra_dl_test');
      final file = File('${dir.path}/D3.mp3');
      file.writeAsStringSync('audio');
      addTearDown(() => dir.deleteSync(recursive: true));

      final repo = MusicRepository();
      repo.addDownloadedSong(_song('D3', path: file.path));
      await drain();

      await repo.removeDownloadedSong('D3', deleteFile: true);
      await drain();

      expect(file.existsSync(), isFalse,
          reason: 'deleting the download must delete its file');
    });

    test('pruneMissingDownloadedFiles drops entries whose file is gone',
        () async {
      final dir = await Directory.systemTemp.createTemp('noctra_prune_test');
      final liveFile = File('${dir.path}/live.mp3');
      liveFile.writeAsStringSync('audio');
      addTearDown(() => dir.deleteSync(recursive: true));

      final repo = MusicRepository();
      repo.addDownloadedSong(_song('LIVE', path: liveFile.path));
      repo.addDownloadedSong(_song('GONE', path: '${dir.path}/gone.mp3'));
      await drain();

      final pruned = await repo.pruneMissingDownloadedFiles();
      await drain();

      expect(pruned, 1);
      expect(repo.downloads.map((s) => s.id), ['LIVE'],
          reason: 'only the entry with a missing file is pruned');
      final saved = await NoctraLocalDatabase().loadDownloads();
      expect(saved.map((s) => s.id), ['LIVE']);
    });

    test('pruneMissingDownloadedFiles also un-stamps favorite rows', () async {
      final dir = await Directory.systemTemp.createTemp('noctra_prune2');
      addTearDown(() => dir.deleteSync(recursive: true));

      final repo = MusicRepository();
      repo.addDownloadedSong(_song('G2', path: '${dir.path}/gone.mp3'));
      await drain();
      repo.addSongsToFavorites([_song('G2')]);
      await drain();
      expect(repo.favorites.first.isDownloaded, isTrue);

      await repo.pruneMissingDownloadedFiles();
      await drain();

      expect(repo.favorites.first.isDownloaded, isFalse);
      expect(repo.favorites.first.localFilePath, isNull);
    });
  });

  group('batched import commit', () {
    test('commitImport favorites many tracks in one logical commit', () async {
      final repo = MusicRepository();
      final songs = [for (var i = 0; i < 20; i++) _song('M$i')];
      final matched = songs
          .map((s) => MatchedTrack(
                imported: NormalizedTrack(
                  title: s.title,
                  artist: s.artist,
                  source: 'test',
                ),
                matchedSong: s,
                confidence: MatchConfidence.exact,
                score: 1.0,
                matchMethod: 'test',
              ))
          .toList();

      await MigrationManager.commitImport(matched, addToFavorites: true);
      await drain();

      expect(repo.favorites.length, 20);
      expect(repo.favorites.every((s) => s.isFavorite), isTrue);
    });

    test('commitImport is idempotent across re-runs', () async {
      final repo = MusicRepository();
      final songs = [for (var i = 0; i < 5; i++) _song('R$i')];
      MatchedTrack mt(Song s) => MatchedTrack(
            imported: NormalizedTrack(
              title: s.title,
              artist: s.artist,
              source: 'test',
            ),
            matchedSong: s,
            confidence: MatchConfidence.exact,
            score: 1.0,
            matchMethod: 'test',
          );

      await MigrationManager.commitImport(songs.map(mt).toList(),
          addToFavorites: true);
      await MigrationManager.commitImport(songs.map(mt).toList(),
          addToFavorites: true);
      await drain();

      expect(repo.favorites.length, 5,
          reason: 're-importing the same library must not duplicate rows');
    });
  });

  group('ID-collision decode preservation', () {
    test('two DIFFERENT recordings sharing an ID both survive decoding',
        () async {
      final db = NoctraLocalDatabase();
      // Seed a favorites payload with two distinct recordings that happen to
      // share the same song id (cross-provider collision).
      final dupId = 'collision_1';
      final payload = jsonEncode([
        _song(dupId, title: 'First Recording', artist: 'Artist A').toMap(),
        _song(dupId, title: 'Second Recording', artist: 'Artist B').toMap(),
      ]);
      SharedPreferences.setMockInitialValues(
          {'noctra_favs': payload, 'flutter.noctra_favs': payload});
      NoctraLocalDatabase().debugResetForTest();

      final favs = await db.loadFavorites();
      expect(favs.length, 2,
          reason: 'a distinct recording must never be dropped for sharing '
              'an id with another recording');
      expect(favs.map((s) => s.title).toSet(),
          {'First Recording', 'Second Recording'});
    });

    test('exact duplicate (same id, title, artist) still collapses', () async {
      final db = NoctraLocalDatabase();
      final payload = jsonEncode([
        _song('dup_x', title: 'Same Song', artist: 'Same Artist').toMap(),
        _song('dup_x', title: 'Same Song', artist: 'Same Artist').toMap(),
      ]);
      SharedPreferences.setMockInitialValues(
          {'noctra_favs': payload, 'flutter.noctra_favs': payload});
      NoctraLocalDatabase().debugResetForTest();

      final favs = await db.loadFavorites();
      expect(favs.length, 1,
          reason: 'true re-import duplicates should still deduplicate');
    });
  });

  group('write-failure visibility', () {
    test('a failing save is contained and does not wedge the write queue',
        () async {
      final db = NoctraLocalDatabase();
      // First write to the favorites key throws (simulated platform failure);
      // the DB layer must absorb it (logged) and the queue must stay alive so
      // the NEXT write still lands.
      var failNext = true;
      final failing = _ThrowingPrefsStore(
        shouldThrow: (key) {
          if (failNext && key.endsWith('noctra_favs')) {
            failNext = false;
            return true;
          }
          return false;
        },
      );
      SharedPreferencesStorePlatform.instance = failing;

      final f1 = db.saveFavorites([_song('W1')]);
      await f1; // must complete normally (error logged internally)
      final f2 = db.saveFavorites([_song('W2')]);
      await f2;
      await drain();

      final raw = failing.rawString('noctra_favs');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect((decoded.single as Map)['id'], 'W2',
          reason: 'the write after a failure must still reach disk');
    });
  });
}

class _ThrowingPrefsStore extends SharedPreferencesStorePlatform {
  _ThrowingPrefsStore({required this.shouldThrow}) : super();

  final bool Function(String key) shouldThrow;
  final Map<String, Object> _data = {};

  String? rawString(String key) =>
      (_data[key] ?? _data['flutter.$key']) as String?;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (shouldThrow(key)) {
      throw Exception('simulated platform write failure');
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
