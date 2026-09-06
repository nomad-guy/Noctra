import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/services/metadata/song_artwork_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SongArtworkResolver', () {
    test('returns existing artworkUrl immediately', () async {
      final song = Song(
        id: 'test_1',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        artworkUrl: 'https://example.com/art.jpg',
        duration: const Duration(seconds: 180),
      );
      final art = await SongArtworkResolver.resolveArtwork(song);
      expect(art, 'https://example.com/art.jpg');
    });

    test('resolves YouTube 11-char ID thumbnail immediately without network',
        () async {
      final song = Song(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        album: 'Whenever You Need Somebody',
        duration: const Duration(seconds: 213),
      );
      final art = await SongArtworkResolver.resolveArtwork(song);
      expect(art, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('manual setCachedArtwork populates cache for subsequent lookups',
        () async {
      final song = Song(
        id: 'import_custom_1',
        title: 'Custom Track',
        artist: 'Custom Artist',
        album: 'Custom Album',
        duration: const Duration(seconds: 200),
      );
      SongArtworkResolver.setCachedArtwork(
          song, 'https://example.com/cached_art.jpg');
      final art = await SongArtworkResolver.resolveArtwork(song);
      expect(art, 'https://example.com/cached_art.jpg');
    });
  });

  group('MusicRepository updateSongMetadata', () {
    late MusicRepository repo;

    setUp(() {
      repo = MusicRepository();
      repo.debugResetForTest();
    });

    test('updates song artwork and duration in custom folders and favorites',
        () {
      final initial = Song(
        id: 'import_mushk_001',
        title: 'Mushk (Original Soundtrack)',
        artist: 'Ali Zafar',
        album: 'Imported',
        artworkUrl: null,
        duration: Duration.zero,
      );

      repo.createFolder('My Playlist');
      repo.addSongToFolder('My Playlist', initial);
      repo.toggleFavorite(initial);

      expect(repo.customFolders['My Playlist']!.first.artworkUrl, isNull);
      expect(repo.favorites.first.artworkUrl, isNull);

      final enriched = initial.copyWith(
        artworkUrl: 'https://example.com/mushk_art.jpg',
        duration: const Duration(seconds: 262),
      );

      repo.updateSongMetadata(enriched);

      expect(repo.customFolders['My Playlist']!.first.artworkUrl,
          'https://example.com/mushk_art.jpg');
      expect(repo.customFolders['My Playlist']!.first.duration,
          const Duration(seconds: 262));
      expect(repo.favorites.first.artworkUrl,
          'https://example.com/mushk_art.jpg');
      expect(repo.favorites.first.duration, const Duration(seconds: 262));
    });
  });
}
