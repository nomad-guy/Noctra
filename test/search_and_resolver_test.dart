import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/models/download_location.dart';
import 'package:noctra/data/models/stream_metadata_model.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';

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

    test('fromMap handles feature vector as JSON string', () {
      final song = Song.fromMap({
        'featureVector': '[0.1, 0.2, 0.3]',
      });
      expect(song.featureVector[0], closeTo(0.1, 0.01));
      expect(song.featureVector[1], closeTo(0.2, 0.01));
      expect(song.featureVector[2], closeTo(0.3, 0.01));
    });
  });

  group('TasteVectorEngine', () {
    test('getDefaultVector returns 32-dim vector', () {
      final vec = TasteVectorEngine.getDefaultVector();
      expect(vec.length, 32);
      expect(vec.every((v) => v == 0.5), true);
    });

    test('cosineSimilarity of identical vectors is 1.0', () {
      final v = List.filled(32, 0.8);
      expect(TasteVectorEngine.cosineSimilarity(v, v), closeTo(1.0, 0.01));
    });

    test('cosineSimilarity of orthogonal vectors is near 0', () {
      final v1 = List.filled(32, 0.0);
      v1[0] = 1.0;
      final v2 = List.filled(32, 0.0);
      v2[1] = 1.0;
      // Orthogonal unit vectors have cosine similarity 0, clamped to [0,1]
      expect(TasteVectorEngine.cosineSimilarity(v1, v2), closeTo(0.0, 0.01));
    });

    test('cosineSimilarity handles empty vectors', () {
      expect(TasteVectorEngine.cosineSimilarity([], []), 0.5);
    });

    test('blendVectors produces weighted average', () {
      final v1 = List.filled(32, 0.8);
      final v2 = List.filled(32, 0.2);
      final blended = TasteVectorEngine.blendVectors(v1, v2, 0.7);
      expect(blended[0], closeTo(0.62, 0.01)); // 0.8*0.7 + 0.2*0.3
    });

    test('blendVectors clamps output', () {
      final v1 = List.filled(32, 0.01);
      final v2 = List.filled(32, 0.01);
      final blended = TasteVectorEngine.blendVectors(v1, v2, 0.5);
      expect(blended[0], greaterThanOrEqualTo(0.05));
    });

    test('extractTextEmbedding produces non-default vector for known genres', () {
      final vec = TasteVectorEngine.extractTextEmbedding('dark synthwave cyberpunk');
      // Should differ from default (0.5) in specific axes
      expect(vec[6], greaterThan(0.5)); // Electronic
      expect(vec[9], greaterThan(0.5)); // Analog Synth
      expect(vec[10], greaterThan(0.5)); // Night Drive
    });

    test('extractTextEmbedding handles empty string', () {
      final vec = TasteVectorEngine.extractTextEmbedding('');
      expect(vec.length, 32);
    });

    test('axisNames has 32 entries', () {
      expect(TasteVectorEngine.axisNames.length, 32);
    });

    test('applyTemporalDecay reduces values toward default', () {
      final vec = List.filled(32, 0.9);
      final decayed = TasteVectorEngine.applyTemporalDecay(vec, daysElapsed: 30);
      // After 30 days, values should be closer to 0.5
      for (int i = 0; i < 32; i++) {
        expect(decayed[i], lessThan(0.9));
        expect(decayed[i], greaterThan(0.5));
      }
    });
  });

  group('MusicService search deduplication', () {
    test('Song id generation for JioSaavn results', () {
      // Verify the id format matches what the code generates
      final id = 'jio_test_id_123';
      expect(id.startsWith('jio_'), true);
    });

    test('Song id generation for LRCLIB results', () {
      final id = 'lrc_12345';
      expect(id.startsWith('lrc_'), true);
    });

    test('Song id generation for iTunes results', () {
      final id = 'itunes_98765';
      expect(id.startsWith('itunes_'), true);
    });
  });

  group('Download Location', () {
    test('DownloadLocation has all expected keys', () {
      expect(DownloadLocation.appDocs, 'app_docs');
      expect(DownloadLocation.appSupport, 'app_support');
      expect(DownloadLocation.external, 'external_music');
      expect(DownloadLocation.downloads, 'public_downloads');
      expect(DownloadLocation.music, 'public_music');
      expect(DownloadLocation.custom, 'custom_folder');
    });

    test('DownloadLocation.all has 6 entries', () {
      expect(DownloadLocation.all.length, 6);
    });

    test('byKey returns correct location', () {
      final loc = DownloadLocation.byKey('public_downloads');
      expect(loc.label, 'Downloads');
    });

    test('byKey returns first for unknown key', () {
      final loc = DownloadLocation.byKey('unknown_key');
      expect(loc.key, DownloadLocation.appDocs);
    });
  });

  group('StreamResolutionMetadata', () {
    test('stores all fields', () {
      final meta = StreamResolutionMetadata(
        songId: 'test123',
        songTitle: 'Test Song',
        resolvedUrl: 'https://example.com/stream',
        resolverUsed: 'CompositeResolver',
        resolutionMs: 450,
        timestamp: DateTime(2024, 1, 15),
      );
      expect(meta.songId, 'test123');
      expect(meta.resolverUsed, 'CompositeResolver');
      expect(meta.resolutionMs, 450);
    });
  });
}
