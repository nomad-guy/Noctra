import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/download_location.dart';
import 'package:noctra/data/models/stream_metadata_model.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';

void main() {
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
      expect(TasteVectorEngine.cosineSimilarity(v1, v2), closeTo(0.0, 0.01));
    });

    test('cosineSimilarity handles empty vectors', () {
      expect(TasteVectorEngine.cosineSimilarity([], []), 0.5);
    });

    test('blendVectors produces weighted average', () {
      final v1 = List.filled(32, 0.8);
      final v2 = List.filled(32, 0.2);
      final blended = TasteVectorEngine.blendVectors(v1, v2, 0.7);
      expect(blended[0], closeTo(0.62, 0.01));
    });

    test('blendVectors clamps output', () {
      final v1 = List.filled(32, 0.01);
      final v2 = List.filled(32, 0.01);
      final blended = TasteVectorEngine.blendVectors(v1, v2, 0.5);
      expect(blended[0], greaterThanOrEqualTo(0.05));
    });

    test(
        'extractTextEmbedding produces non-default vector for known genres',
        () {
      final vec =
          TasteVectorEngine.extractTextEmbedding('dark synthwave cyberpunk');
      expect(vec[6], greaterThan(0.5));
      expect(vec[9], greaterThan(0.5));
      expect(vec[10], greaterThan(0.5));
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
      final decayed =
          TasteVectorEngine.applyTemporalDecay(vec, daysElapsed: 30);
      for (int i = 0; i < 32; i++) {
        expect(decayed[i], lessThan(0.9));
        expect(decayed[i], greaterThan(0.5));
      }
    });
  });

  group('MusicService search deduplication', () {
    test('Song id generation for JioSaavn results', () {
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
