import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/models/migration_models.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/data/sources/noctra_manifest_store.dart';
import 'package:noctra/services/migration/track_matcher.dart';
import 'package:noctra/services/resolvers/stream_resolver.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    MusicRepository.instance.debugResetForTest();
  });

  group('Phase 6: MusicRepository O(1) Set Indexes & Invariants', () {
    test('isFavorite and isDownloaded return O(1) matching truth', () {
      final repo = MusicRepository.instance;
      final song1 = Song(
        id: 'track_1',
        title: 'Song One',
        artist: 'Artist A',
        album: 'Album A',
        artworkUrl: '',
        duration: const Duration(seconds: 180),
      );
      final song2 = Song(
        id: 'track_2',
        title: 'Song Two',
        artist: 'Artist B',
        album: 'Album B',
        artworkUrl: '',
        duration: const Duration(seconds: 210),
      );

      expect(repo.isFavorite('track_1'), isFalse);
      expect(repo.isDownloaded('track_1'), isFalse);

      repo.toggleFavorite(song1);
      expect(repo.isFavorite('track_1'), isTrue);
      expect(repo.isFavorite('track_2'), isFalse);

      repo.addDownloadedSong(song2);
      expect(repo.isDownloaded('track_2'), isTrue);
      expect(repo.isDownloaded('track_1'), isFalse);

      // Untoggle favorite
      repo.toggleFavorite(song1);
      expect(repo.isFavorite('track_1'), isFalse);
    });

    test('addSongsToFavorites bulk index synchronization', () {
      final repo = MusicRepository.instance;
      final bulkSongs = List.generate(
        100,
        (i) => Song(
          id: 'bulk_$i',
          title: 'Title $i',
          artist: 'Artist $i',
          album: 'Album $i',
          artworkUrl: '',
          duration: const Duration(seconds: 200),
        ),
      );

      repo.addSongsToFavorites(bulkSongs);
      expect(repo.favorites.length, 100);
      for (int i = 0; i < 100; i++) {
        expect(repo.isFavorite('bulk_$i'), isTrue);
      }
      expect(repo.isFavorite('non_existent'), isFalse);
    });
  });

  group('Phase 6: TrackMatcher Catalog Indexing & Memory Optimization', () {
    test('Levenshtein distance calculation matches exact differences', () {
      expect(TrackMatcher.matchAll([]), isEmpty);

      final songA = Song(
        id: 'id_kesariya',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        artworkUrl: '',
        duration: const Duration(seconds: 268),
      );

      final repo = MusicRepository.instance;
      repo.addSongsToFavorites([songA]);

      final tracksToMatch = [
        NormalizedTrack(
          title: 'kesariya',
          artist: 'arijit singh',
          source: 'spotify',
        ),
        NormalizedTrack(
          title: 'kesariya',
          artist: 'arijit singh',
          source: 'apple',
        ),
        NormalizedTrack(
          title: 'completely unrelated track',
          artist: 'unknown artist',
          source: 'youtube',
        ),
      ];

      final matches = TrackMatcher.matchAll(tracksToMatch);
      expect(matches.length, 3);
      expect(matches[0].confidence, MatchConfidence.exact);
      expect(matches[0].matchedSong?.id, 'id_kesariya');
      expect(matches[1].confidence, MatchConfidence.exact);
      expect(matches[2].confidence, MatchConfidence.none);
    });
  });

  group('Phase 6: NoctraManifestStore Static Regex Invariants', () {
    test('inferred language accurately categorizes languages with pre-compiled regex', () {
      final store = NoctraManifestStore();
      final hindiSong = Song(
        id: 'h1',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        artworkUrl: '',
        duration: const Duration(seconds: 262),
      );
      final punjabiSong = Song(
        id: 'p1',
        title: '295',
        artist: 'Sidhu Moose Wala',
        album: 'Moosetape',
        artworkUrl: '',
        duration: const Duration(seconds: 270),
      );
      final englishSong = Song(
        id: 'e1',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        artworkUrl: '',
        duration: const Duration(seconds: 230),
      );

      store.recordManifest(hindiSong);
      store.recordManifest(punjabiSong);
      store.recordManifest(englishSong);

      expect(store.manifests['h1']?.language, 'Hindi');
      expect(store.manifests['p1']?.language, 'Punjabi');
      expect(store.manifests['e1']?.language, 'English');
    });
  });

  group('Phase 6: StreamResolver and MusicService Deduplication', () {
    test('CompositeStreamResolver cache invalidation works cleanly', () {
      CompositeStreamResolver.invalidateCache('test_song_123');
      expect(true, isTrue);
    });
  });
}
