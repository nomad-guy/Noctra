import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';

void main() {
  group('Song Model', () {
    test('creates with required fields', () {
      final song = Song(
        id: 'test123',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        duration: const Duration(minutes: 4, seconds: 12),
      );
      expect(song.id, 'test123');
      expect(song.title, 'Tum Hi Ho');
      expect(song.artist, 'Arijit Singh');
      expect(song.album, 'Single');
      expect(song.isDownloaded, false);
      expect(song.featureVector.length, 32);
    });

    test('song without a feature vector is marked invalid (never fake data)',
        () {
      final song = Song(
        id: 'test123',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        duration: const Duration(minutes: 4),
      );
      expect(song.featureVector.length, 32);
      expect(song.hasValidFeatureVector, false);
      expect(song.hasUsableEmbedding, false);
    });

    test('song with a valid 32-dim vector is usable', () {
      final vec = List.generate(32, (i) => 0.05 + i * 0.01);
      final song = Song(
        id: 'test123',
        title: 'T',
        artist: 'A',
        duration: const Duration(seconds: 1),
        featureVector: vec,
      );
      expect(song.hasValidFeatureVector, true);
      expect(song.hasUsableEmbedding, true);
    });

    test('explicit all-0.5 vector is valid data but not usable embedding', () {
      final song = Song(
        id: 'test123',
        title: 'T',
        artist: 'A',
        duration: const Duration(seconds: 1),
        featureVector: List.filled(32, 0.5),
      );
      expect(song.hasValidFeatureVector, true);
      expect(song.hasUsableEmbedding, false);
    });

    test('wrong-dimension or non-finite vectors are rejected, not padded', () {
      final tooShort = Song(
        id: 'a',
        title: 'T',
        artist: 'A',
        duration: const Duration(seconds: 1),
        featureVector: List.filled(16, 0.7),
      );
      expect(tooShort.featureVector.length, 32);
      expect(tooShort.hasValidFeatureVector, false);
      expect(tooShort.hasUsableEmbedding, false);

      final tooLong = Song(
        id: 'b',
        title: 'T',
        artist: 'A',
        duration: const Duration(seconds: 1),
        featureVector: List.filled(33, 0.7),
      );
      expect(tooLong.featureVector.length, 32);
      expect(tooLong.hasValidFeatureVector, false);

      final withNaN = Song(
        id: 'c',
        title: 'T',
        artist: 'A',
        duration: const Duration(seconds: 1),
        featureVector: List.generate(32, (i) => i == 3 ? double.nan : 0.5),
      );
      expect(withNaN.hasValidFeatureVector, false);
      expect(withNaN.hasUsableEmbedding, false);
    });

    test('copyWith keeps an explicit validity flag', () {
      final invalid = Song(
        id: 'x',
        title: 'T',
        artist: 'A',
        duration: const Duration(seconds: 1),
      );
      final copy = invalid.copyWith(title: 'New');
      expect(copy.hasValidFeatureVector, false);
      expect(copy.hasUsableEmbedding, false);
    });

    test('copyWith preserves all fields', () {
      final song = Song(
        id: 'test123',
        title: 'Original',
        artist: 'Artist',
        duration: const Duration(seconds: 200),
        genre: 'Pop',
      );
      final copy = song.copyWith(title: 'Modified');
      expect(copy.title, 'Modified');
      expect(copy.artist, 'Artist');
      expect(copy.genre, 'Pop');
      expect(copy.id, 'test123');
    });

    test('copyWith can clear optional fields', () {
      final song = Song(
        id: 'test123',
        title: 'Test',
        artist: 'Artist',
        artworkUrl: 'https://example.com/art.jpg',
        duration: const Duration(seconds: 200),
      );
      final copy = song.copyWith(clearArtworkUrl: true);
      expect(copy.artworkUrl, isNull);
    });

    test('toMap/fromMap roundtrip', () {
      final song = Song(
        id: 'test123',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        artworkUrl: 'https://example.com/art.jpg',
        duration: const Duration(minutes: 3, seconds: 30),
        genre: 'Pop',
        isDownloaded: true,
        featureVector: List.filled(32, 0.7),
        replayCount: 5,
        skipCount: 1,
      );
      final map = song.toMap();
      final restored = Song.fromMap(map);
      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.artworkUrl, song.artworkUrl);
      expect(restored.duration.inMilliseconds, song.duration.inMilliseconds);
      expect(restored.genre, song.genre);
      expect(restored.isDownloaded, true);
      expect(restored.replayCount, 5);
      expect(restored.skipCount, 1);
    });

    test('fromMap handles missing fields gracefully', () {
      final song = Song.fromMap({});
      expect(song.id, '');
      expect(song.title, 'Unknown Track');
      expect(song.artist, 'Unknown Artist');
      expect(song.featureVector.length, 32);
    });

    test('fromMap handles duration as seconds', () {
      final song = Song.fromMap({'duration': 210});
      expect(song.duration.inSeconds, 210);
    });

    test('fromMap handles duration as milliseconds', () {
      final song = Song.fromMap({'durationMs': 210000});
      expect(song.duration.inSeconds, 210);
    });

    test('fromMap handles valid 32-dim feature vector as JSON string', () {
      final vec32 = List.generate(32, (i) => 0.1 + i * 0.01);
      final song = Song.fromMap({
        'featureVector': jsonEncode(vec32),
      });
      expect(song.hasValidFeatureVector, true);
      expect(song.featureVector[0], closeTo(vec32[0], 0.001));
      expect(song.featureVector[31], closeTo(vec32[31], 0.001));
    });

    test('fromMap marks short feature vectors invalid (no silent padding)', () {
      final song = Song.fromMap({
        'featureVector': '[0.1, 0.2, 0.3]',
      });
      expect(song.hasValidFeatureVector, false);
      expect(song.featureVector.length, 32);
      expect(song.featureVector[0], closeTo(0.5, 0.001));
    });

    test('fromMap marks NaN/Infinity feature vectors invalid', () {
      final badVec = List.filled(32, double.nan);
      final song = Song.fromMap({'featureVector': badVec});
      expect(song.hasValidFeatureVector, false);
    });

    test('fromMap throws on invalid id types', () {
      expect(() => Song.fromMap({'id': 123}), throwsFormatException);
      expect(() => Song.fromMap({'id': true}), throwsFormatException);
      expect(() => Song.fromMap({'id': {'a': 1}}), throwsFormatException);
      expect(() => Song.fromMap({'id': '  '}), throwsFormatException);
    });
  });
}
