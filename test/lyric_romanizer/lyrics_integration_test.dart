import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyrics/lyrics_service.dart';
import 'package:noctra/data/models/song_model.dart';

void main() {
  // Integration tests — hit real APIs. Skip in CI with --define=skipIntegration=true
  Song makeSong(String title, String artist, {String id = 'test_001'}) => Song(
    id: id, title: title, artist: artist,
    duration: const Duration(minutes: 3, seconds: 30),
  );

  group('LRCLIB integration (Tier 1)', () {
    test('fetches English lyrics for "Shape of You"', () async {
      final song = makeSong('Shape of You', 'Ed Sheeran', id: 'lrclib_001');
      final lyrics = await LyricsService.fetchLyrics(song);
      expect(lyrics.plainText.isNotEmpty, true, reason: 'Should find lyrics');
      expect(lyrics.plainText.toLowerCase(), contains('shape'),
          reason: 'Lyrics should mention "shape"');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('fetches Hindi lyrics when preference is Hindi', () async {
      final song = makeSong('Tum Hi Ho', 'Arijit Singh', id: 'lrclib_002');
      final lyrics = await LyricsService.fetchLyrics(song, preference: 'Hindi');
      // Should either find Hindi lyrics or fall back to synced Latin
      expect(lyrics.plainText.isNotEmpty, true, reason: 'Should find some lyrics');
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Title verification prevents wrong lyrics', () {
    test('different song should NOT get lyrics for "Shape of You"', () async {
      // "Shape" alone is < 5 chars, so title match should fail
      final song = makeSong('Shape', 'Some Artist', id: 'verify_001');
      final lyrics = await LyricsService.fetchLyrics(song);
      // Should return empty since "Shape" won't match "Shape of You" title
      expect(lyrics.plainText.contains('I\'m in love with the shape of you'),
          false, reason: 'Should NOT get Shape of You lyrics for a song called "Shape"');
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Musixmatch tier (Tier 3)', () {
    test('raw title search finds lyrics for "Kesariya"', () async {
      final song = makeSong('Kesariya', 'Arijit Singh', id: 'mm_001');
      final lyrics = await LyricsService.fetchLyrics(song);
      expect(lyrics.plainText.isNotEmpty, true, reason: 'Should find Kesariya lyrics');
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('InnerTube tier (Tier 4)', () {
    test('YouTube ID-based lyrics fetch', () async {
      // Use a known YouTube video ID
      final song = makeSong('Some Song', 'Some Artist', id: 'yt_dQw4w9WgXcQ');
      final lyrics = await LyricsService.fetchLyrics(song);
      // May or may not find lyrics, but should not crash
      expect(lyrics, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 25)));
  });

  group('Cache behavior', () {
    test('second fetch returns cached result', () async {
      final song = makeSong('Shape of You', 'Ed Sheeran', id: 'cache_001');
      final lyrics1 = await LyricsService.fetchLyrics(song);
      final lyrics2 = await LyricsService.fetchLyrics(song);
      expect(lyrics1.plainText, equals(lyrics2.plainText),
          reason: 'Cached result should be identical');
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
