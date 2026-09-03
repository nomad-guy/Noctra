import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _createSong(String id, {String title = 'Test Track', String artist = 'Test Artist', String? path, Duration? duration}) =>
    Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Test Album',
      localFilePath: path,
      duration: duration ?? const Duration(seconds: 180),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    MusicRepository.instance.debugResetForTest();
  });

  group('Phase 15 — Schema Integrity & Malformation Isolation', () {
    test('invalid ID type in song map throws FormatException on parse', () {
      final map = {
        'id': 987654,
        'title': 'Numeric ID Song',
        'artist': 'Artist',
        'durationMs': 120000,
      };
      expect(() => Song.fromMap(map), throwsFormatException);
    });

    test('negative duration is clamped safely to 0', () {
      final map = {
        'id': 'neg_dur_song',
        'title': 'Clamped Duration',
        'artist': 'Artist',
        'durationMs': -5000,
      };
      final song = Song.fromMap(map);
      expect(song.duration.inMilliseconds, 0);
    });

    test('single corrupt record in favorites list does not destroy entire list', () async {
      final valid1 = _createSong('song_1', title: 'Track One');
      final valid2 = _createSong('song_2', title: 'Track Two');
      final corrupt = {'id': true, 'title': null}; // invalid non-string id & null title

      final initialList = [valid1.toMap(), corrupt, valid2.toMap()];
      SharedPreferences.setMockInitialValues({
        'noctra_favs': jsonEncode(initialList),
      });

      final db = NoctraLocalDatabase();
      final favs = await db.loadFavorites();

      expect(favs.length, 2);
      expect(favs.map((s) => s.id), containsAll(['song_1', 'song_2']));
    });

    test('corrupted non-JSON string is safely backed up to _corrupt_bak before removal', () async {
      const corruptPayload = '{not a valid json string:::';
      SharedPreferences.setMockInitialValues({
        'noctra_favs': corruptPayload,
      });

      final db = NoctraLocalDatabase();
      final favs = await db.loadFavorites();
      expect(favs, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('noctra_favs_corrupt_bak'), corruptPayload);
      expect(prefs.getString('noctra_favs'), isNull);
    });
  });

  group('Phase 15 — Theme Normalization & AMOLED Migration', () {
    test('legacy amoled and noirAmoled migrate to noirBlack', () async {
      SharedPreferences.setMockInitialValues({
        'noctra_theme_mode': 'amoled',
      });
      final db = NoctraLocalDatabase();
      await db.init();
      expect(db.getCachedThemeMode(), 'noirBlack');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('noctra_theme_mode'), 'noirBlack');
    });

    test('invalid or unknown themes normalize to noirBlack', () {
      expect(NoctraLocalDatabase.normalizeThemeMode('dark'), 'noirBlack');
      expect(NoctraLocalDatabase.normalizeThemeMode('system'), 'noirBlack');
      expect(NoctraLocalDatabase.normalizeThemeMode('unknown_random'), 'noirBlack');
      expect(NoctraLocalDatabase.normalizeThemeMode(null), 'noirBlack');
    });

    test('valid themes noirWhite and liquidGlass are preserved', () {
      expect(NoctraLocalDatabase.normalizeThemeMode('noirWhite'), 'noirWhite');
      expect(NoctraLocalDatabase.normalizeThemeMode('liquidGlass'), 'liquidGlass');
      expect(NoctraLocalDatabase.normalizeThemeMode('liquid_glass'), 'liquidGlass');
      expect(NoctraLocalDatabase.normalizeThemeMode('light'), 'noirWhite');
    });
  });

  group('Phase 15 — Queue Persistence & Restoration with Duplicates (A B A C)', () {
    test('duplicate songs in queue survive restart with order and index preserved', () async {
      final songA = _createSong('id_A', title: 'Song A');
      final songB = _createSong('id_B', title: 'Song B');
      final songC = _createSong('id_C', title: 'Song C');

      // Queue: A B A C (songA appears twice at index 0 and 2)
      final queue = [songA, songB, songA, songC];
      final playingIndex = 2; // Active song is second occurrence of songA

      final db = NoctraLocalDatabase();
      await db.savePlaybackSession(
        currentSong: queue[playingIndex],
        positionMs: 45000,
        queue: queue,
        currentIndex: playingIndex,
        isShuffle: true,
        loopMode: 'one',
      );

      final session = await db.loadPlaybackSession();
      expect(session, isNotNull);
      final restoredQueue = session!['queue'] as List<Song>;
      expect(restoredQueue.length, 4);
      expect(restoredQueue[0].id, 'id_A');
      expect(restoredQueue[1].id, 'id_B');
      expect(restoredQueue[2].id, 'id_A');
      expect(restoredQueue[3].id, 'id_C');

      expect(session['currentIndex'], 2);
      expect((session['song'] as Song?)?.id, 'id_A');
      expect(session['positionMs'], 45000);
      expect(session['isShuffle'], true);
      expect(session['loopMode'], 'one');
    });
  });

  group('Phase 15 — Startup Read-Write Race Protection in MusicRepository', () {
    test('user mutations performed before/during load are preserved and not overwritten', () async {
      final diskFav = _createSong('disk_fav', title: 'Disk Favorite');
      SharedPreferences.setMockInitialValues({
        'noctra_favs': jsonEncode([diskFav.toMap()]),
      });

      final repo = MusicRepository.instance;
      // Start init which kicks off database load in background
      final initFuture = repo.init();
      // User favorites a new song before repository init completes
      final startupFav = _createSong('startup_fav', title: 'Startup Favorite');
      repo.toggleFavorite(startupFav);

      // Now wait for init to complete
      await initFuture;

      // Both the disk favorite and the startup user favorite must be present
      expect(repo.isFavorite('startup_fav'), isTrue);
      expect(repo.isFavorite('disk_fav'), isTrue);
      expect(repo.favorites.length, 2);
    });

    test('user un-favoriting a song during startup is not re-added by disk load', () async {
      final diskFav = _createSong('disk_fav', title: 'Disk Favorite');
      SharedPreferences.setMockInitialValues({
        'noctra_favs': jsonEncode([diskFav.toMap()]),
      });

      final repo = MusicRepository.instance;
      final initFuture = repo.init();
      // User explicitly un-favorites the song during startup
      repo.toggleFavorite(diskFav); // was false, becomes true
      repo.toggleFavorite(diskFav); // toggled off (removed)

      await initFuture;

      // The un-favorited song must NOT be re-added by disk load
      expect(repo.isFavorite('disk_fav'), isFalse);
    });
  });

  group('Phase 15 — Custom Folders Pruning', () {
    test('custom folders are pruned of missing local files during startup reconciliation', () async {
      final songWithMissingFile = _createSong(
        'missing_track',
        title: 'Missing Offline Track',
        path: '/non_existent_folder/missing_track.mp3',
      ).copyWith(isDownloaded: true);

      SharedPreferences.setMockInitialValues({
        'noctra_downloads': jsonEncode([songWithMissingFile.toMap()]),
        'noctra_custom_folders': jsonEncode({
          'Roadtrip': [songWithMissingFile.toMap()],
        }),
      });

      final repo = MusicRepository.instance;
      await repo.init();

      // The missing download must have been pruned from downloads
      expect(repo.isDownloaded('missing_track'), isFalse);
      expect(repo.downloads.isEmpty, isTrue);

      // Custom folder must also have had the stale downloaded flag cleared
      final roadtripSongs = repo.customFolders['Roadtrip']!;
      expect(roadtripSongs.length, 1);
      expect(roadtripSongs.first.isDownloaded, isFalse);
      expect(roadtripSongs.first.localFilePath, isNull);
    });
  });
}
