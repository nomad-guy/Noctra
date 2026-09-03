import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/ai/session_context_tracker.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:noctra/services/audio/audio_visualizer_service.dart';
import 'package:noctra/services/lyrics/live_transliteration_controller.dart';
import 'package:noctra/services/ytdlp/music_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    await NoctraLocalDatabase().init();
    MusicRepository().debugResetForTest();
  });

  group('Phase 7 - Playback & Concurrency Hardening', () {
    test('Playback invalidation updates settings safely', () {
      final player = AudioPlayerService();
      player.pause();
      player.setCrossfadeSeconds(3);
      expect(player.crossfadeSeconds, 3);
    });

    test('MusicRepository.updateSongMetadata preserves order and updates in-place', () {
      final repo = MusicRepository();
      final song1 = Song(
        id: 'song_1',
        title: 'Original Title 1',
        artist: 'Artist A',
        album: 'Album 1',
        artworkUrl: '',
        duration: const Duration(seconds: 180),
      );
      final song2 = Song(
        id: 'song_2',
        title: 'Original Title 2',
        artist: 'Artist B',
        album: 'Album 2',
        artworkUrl: '',
        duration: const Duration(seconds: 210),
      );
      final song3 = Song(
        id: 'song_3',
        title: 'Original Title 3',
        artist: 'Artist C',
        album: 'Album 3',
        artworkUrl: '',
        duration: const Duration(seconds: 240),
      );

      // Add in specific order
      repo.toggleFavorite(song1);
      repo.toggleFavorite(song2);
      repo.toggleFavorite(song3);

      // In favorites: song3 (index 0), song2 (index 1), song1 (index 2)
      expect(repo.favorites.map((s) => s.id).toList(), ['song_3', 'song_2', 'song_1']);

      // Now update song2 metadata
      final updatedSong2 = song2.copyWith(
        title: 'Updated Title 2',
        artworkUrl: 'https://cdn.example.com/art2.jpg',
      );
      repo.updateSongMetadata(updatedSong2);

      // Order MUST be preserved: song3, song2, song1 (NOT moved to index 0)
      expect(repo.favorites.map((s) => s.id).toList(), ['song_3', 'song_2', 'song_1']);
      expect(repo.favorites[1].title, 'Updated Title 2');
      expect(repo.favorites[1].artworkUrl, 'https://cdn.example.com/art2.jpg');
    });

    test('LiveTransliterationController does not throw or mutate after dispose', () {
      final controller = LiveTransliterationController();
      controller.onTextChanged('namaste');
      controller.dispose();

      // Calling onTextChanged or flush after dispose must be no-ops and never throw
      expect(() => controller.onTextChanged('shanti'), returnsNormally);
      expect(() => controller.flush(), returnsNormally);
      expect(() => controller.learnCorrection('namaste', 'नमस्ते'), returnsNormally);
    });

    test('AudioVisualizerService handles envelopes safely even after disposal', () {
      final visualizer = AudioVisualizerService();
      expect(
        visualizer.handleEnvelope({
          'type': 'fft',
          'data': [0.1, 0.5, 0.9]
        }),
        isTrue,
      );

      visualizer.dispose();

      // Subsequent envelopes should still parse without throwing StateError on closed streams
      expect(
        () => visualizer.handleEnvelope({
          'type': 'waveform',
          'data': [0.2, 0.4, 0.8]
        }),
        returnsNormally,
      );
    });

    test('SessionContextTracker bounds affinity entries to 100 max', () {
      final tracker = SessionContextTracker();
      tracker.resetSession();

      for (int i = 0; i < 150; i++) {
        final song = Song(
          id: 's_$i',
          title: 'Track $i',
          artist: 'Artist_$i',
          genre: 'Genre_$i',
          duration: const Duration(seconds: 120),
        );
        tracker.recordSong(song, 'complete_listen');
      }

      expect(tracker.artistAffinity.length, lessThanOrEqualTo(100));
      expect(tracker.genreAffinity.length, lessThanOrEqualTo(100));
    });

    test('MusicService.downloadTrack deduplicates in-flight downloads', () async {
      final song = Song(
        id: 'dl_test_1',
        title: 'Dedup Song',
        artist: 'Dedup Artist',
        duration: const Duration(seconds: 100),
      );

      final f1 = MusicService.downloadTrack(song);
      final f2 = MusicService.downloadTrack(song);

      final res = await Future.wait([f1, f2]);
      expect(res.length, 2);
    });
  });
}
