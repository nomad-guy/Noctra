import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/services/lyrics/devanagari_transliteration_service.dart';
import 'package:noctra/core/utils/noctra_localization.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('TasteVectorEngine 32-Dimension Tests', () {
    test('Vector dimension is strictly 32', () {
      final defaultVec = TasteVectorEngine.getDefaultVector();
      expect(defaultVec.length, 32);
      expect(TasteVectorEngine.axisNames.length, 32);
    });

    test('Cosine similarity is 1.0 for identical vectors', () {
      final vec = [for (int i = 0; i < 32; i++) 0.6];
      final sim = TasteVectorEngine.cosineSimilarity(vec, vec);
      expect(sim, closeTo(1.0, 0.001));
    });

    test('Temporal decay decays toward default baseline', () {
      final vec = [for (int i = 0; i < 32; i++) 0.9];
      final decayed = TasteVectorEngine.applyTemporalDecay(vec, daysElapsed: 14);
      expect(decayed.length, 32);
      expect(decayed[0], lessThan(0.9));
      expect(decayed[0], greaterThan(0.5));
    });
  });

  group('Devanagari Transliteration Service Tests', () {
    test('Converts Roman lyrics to Devanagari accurately', () {
      const text = 'tere bin nahi lagda dil mera sukoon';
      final converted = DevanagariTransliterationService.toDevanagari(text);
      expect(converted.contains('तेरे'), isTrue);
      expect(converted.contains('दिल'), isTrue);
      expect(converted.contains('सुकून'), isTrue);
    });

    test('Word by word transliteration works accurately', () {
      expect(DevanagariTransliterationService.toDevanagari('sukoon'), 'सुकून');
      expect(DevanagariTransliterationService.toDevanagari('dil'), 'दिल');
    });
  });

  group('NoctraLocalization Tests', () {
    test('Translates keys into Hindi, Urdu, Spanish, and French', () {
      NoctraLocalization.currentLanguage = 'en';
      expect(NoctraLocalization.tr('app_name'), 'Noctra');

      NoctraLocalization.currentLanguage = 'hi';
      expect(NoctraLocalization.tr('app_name'), 'नोक्ट्रा');

      NoctraLocalization.currentLanguage = 'ur';
      expect(NoctraLocalization.tr('app_name'), 'نوکٹرا');

      NoctraLocalization.currentLanguage = 'es';
      expect(NoctraLocalization.tr('search_explore'), 'Buscar y Explorar');
    });
  });

  group('MusicRepository Folder Operations', () {
    test('Create and Delete custom folders safely', () {
      final repo = MusicRepository();
      repo.createFolder('Late Night Test');
      expect(repo.customFolders.containsKey('Late Night Test'), isTrue);

      final dummySong = Song(
        id: 'test_1',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        artworkUrl: null,
        streamUrl: null,
        duration: const Duration(seconds: 180),
      );
      repo.addSongToFolder('Late Night Test', dummySong);
      expect(repo.customFolders['Late Night Test']?.length, 1);

      repo.deleteFolder('Late Night Test');
      expect(repo.customFolders.containsKey('Late Night Test'), isFalse);
    });
  });
}
