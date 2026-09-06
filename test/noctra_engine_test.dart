import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/services/lyrics/devanagari_transliteration_service.dart';
import 'package:noctra/services/lyrics/dynamic_lexicon.dart';
import 'package:noctra/services/lyrics/romanized_translation_engine.dart';
import 'package:noctra/services/lyrics/akshara_engine.dart';
import 'package:noctra/services/lyrics/sanscript_engine.dart';
import 'package:noctra/services/lyrics/indic_xlit_engine.dart';
import 'package:noctra/services/lyrics/universal_lyrics_transliteration_engine.dart';
import 'package:noctra/core/utils/noctra_localization.dart';
import 'package:noctra/core/theme/noir_theme.dart';

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

  group('Dynamic theme tokens', () {
    test('each built-in theme exposes distinct semantic tokens', () {
      final black = NoirTheme.getTheme(NoirThemeMode.noirBlack);
      final white = NoirTheme.getTheme(NoirThemeMode.noirWhite);
      final glass = NoirTheme.getTheme(NoirThemeMode.liquidGlass);
      expect(black.extension<NoctraThemeTokens>()?.canvas, isNotNull);
      expect(white.brightness, Brightness.light);
      expect(glass.extension<NoctraThemeTokens>()?.glassBlurSigma, 18);
      expect(black.extension<NoctraThemeTokens>()?.surface,
          isNot(white.extension<NoctraThemeTokens>()?.surface));
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

    test('DynamicLexicon learning and user overrides work reliably', () {
      final lexicon = DynamicLexicon();
      expect(lexicon.lookup('customnewword'), isNull);
      lexicon.learnWord('customnewword', 'कस्टम');
      expect(lexicon.lookup('customnewword'), 'कस्टम');
    });
  });

  group('Romanized Translation Engine Tests', () {
    test('Converts Devanagari text to Romanized script', () {
      final engine = RomanizedTranslationEngine();
      final roman = engine.toRoman('दिल मेरा सुकून');
      expect(roman.toLowerCase().contains('dil'), isTrue);
      expect(roman.toLowerCase().contains('sukoon'), isTrue);
    });

    test('Translates poetic words to English meanings', () {
      final engine = RomanizedTranslationEngine();
      expect(engine.translateWord('sukoon'), 'peace / solace');
      expect(engine.translateWord('dil'), 'heart / soul');
    });

    test('Preserves whitespace and safely handles punctuation-only tokens', () {
      final engine = RomanizedTranslationEngine();
      expect(engine.toRoman('दिल   !!! मेरा'), 'Dil   !!! Mera');
    });
  });

  group('NoctraLocalization Tests', () {
    test('Translates keys into Hindi, Punjabi, Urdu, and Kannada', () {
      NoctraLocalization.currentLanguage = 'en';
      expect(NoctraLocalization.tr('app_name'), 'Noctra');

      NoctraLocalization.currentLanguage = 'hi';
      expect(NoctraLocalization.tr('app_name'), 'नोक्ट्रा');

      NoctraLocalization.currentLanguage = 'pa';
      expect(NoctraLocalization.tr('app_name'), 'ਨੋਕਟ੍ਰਾ');

      NoctraLocalization.currentLanguage = 'ur';
      expect(NoctraLocalization.tr('app_name'), 'نوکٹرا');

      NoctraLocalization.currentLanguage = 'kn';
      expect(NoctraLocalization.tr('app_name'), 'ನೋಕ್ಟ್ರಾ');
    });
  });

  group('Multi-Script Aksharamukha & Sanscript Tests', () {
    test('Converts Devanagari to Gurmukhi accurately', () {
      final gurmukhi = SanscriptEngine.t('दिल', SanscriptEngine.devanagari, SanscriptEngine.gurmukhi);
      expect(gurmukhi.isNotEmpty, isTrue);
      expect(gurmukhi, contains('ਦਿਲ'));
    });

    test('Converts across Indic scripts using compiled SchemeMaps', () {
      const text = 'तेरे बिना ज़िन्दगी से कोई शिकवा तो नहीं';
      final gurmukhi = SanscriptEngine.t(text, SanscriptEngine.devanagari, SanscriptEngine.gurmukhi);
      final bengali = SanscriptEngine.t(text, SanscriptEngine.devanagari, SanscriptEngine.bengali);
      final tamil = SanscriptEngine.t(text, SanscriptEngine.devanagari, SanscriptEngine.tamil);
      final telugu = SanscriptEngine.t(text, SanscriptEngine.devanagari, SanscriptEngine.telugu);
      final iast = SanscriptEngine.t(text, SanscriptEngine.devanagari, SanscriptEngine.iast);

      expect(gurmukhi, contains('ਤੇਰੇ'));
      expect(bengali, contains('তেরে'));
      expect(tamil, contains('தேரே'));
      expect(telugu, contains('తేరే'));
      expect(iast, contains('tere binā'));

      // Bidirectional verification
      final roundTripDeva = SanscriptEngine.t(gurmukhi, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari);
      expect(roundTripDeva, contains('तेरे बिना'));
    });

    test('Converts Devanagari to Urdu and Urdu to Devanagari', () {
      final urdu = SanscriptEngine.t('तेरे दर पर सनम', SanscriptEngine.devanagari, SanscriptEngine.urdu);
      expect(urdu.trim(), 'تیرے در پر سنم');

      final deva = SanscriptEngine.t('تیرے در پر سنم', SanscriptEngine.urdu, SanscriptEngine.devanagari);
      expect(deva.isNotEmpty, isTrue);
    });

    test('AksharaEngine canonical matrix converts Devanagari to Gurmukhi, IAST, and Urdu', () {
      const lyricLine = 'तेरे दर पर सनम';
      final gurmukhi = AksharaEngine.instance.convert(lyricLine, from: 'Devanagari', to: 'Gurmukhi');
      expect(gurmukhi.trim(), 'ਤੇਰੇ ਦਰ ਪਰ ਸਨਮ');

      final iast = AksharaEngine.instance.convert(lyricLine, from: 'Devanagari', to: 'IAST');
      expect(iast.trim(), 'tere dar par sanam');

      final urdu = AksharaEngine.instance.convert(lyricLine, from: 'Devanagari', to: 'Urdu');
      expect(urdu.trim(), 'تیرے در پر سنم');
    });

    test('IndicXlit transliterates Romanized input to Hindi and Punjabi', () async {
      final hindi = await IndicXlitEngine.transliterate('mera dil', targetLang: 'hi');
      expect(hindi.contains('दिल'), isTrue);

      final punjabi = await IndicXlitEngine.transliterate('mera dil', targetLang: 'pa');
      expect(punjabi.isNotEmpty, isTrue);
    });
  });

  group('Universal Lyrics Transliteration Engine Tests', () {
    test('Detects and converts short Devanagari lyric lines', () {
      expect(UniversalLyricsTransliterationEngine.detectScript('दिल'), LyricScript.devanagari);
      expect(UniversalLyricsTransliterationEngine.transliterateText('दिल', 'roman').toLowerCase(), contains('dil'));
      expect(UniversalLyricsTransliterationEngine.transliterateText('dil', 'devanagari'), contains('दिल'));
    });

    test('Detects Japanese, Korean, Cyrillic, Devanagari, and Latin scripts accurately', () {
      expect(UniversalLyricsTransliterationEngine.detectScript('こんにちは 世界'), LyricScript.japanese);
      expect(UniversalLyricsTransliterationEngine.detectScript('안녕하세요'), LyricScript.korean);
      expect(UniversalLyricsTransliterationEngine.detectScript('Привет мир'), LyricScript.cyrillic);
      expect(UniversalLyricsTransliterationEngine.detectScript('मेरा दिल ये पुकारे'), LyricScript.devanagari);
      expect(UniversalLyricsTransliterationEngine.detectScript('Shape of You'), LyricScript.latin);
      expect(UniversalLyricsTransliterationEngine.detectScript('ਸਾਰੇ ਰੰਗ'), LyricScript.gurmukhi);
    });

    test('Transliterates Japanese Kana to Romaji accurately', () {
      final romaji = UniversalLyricsTransliterationEngine.transliterateText('こんにちは', 'roman');
      expect(romaji.toLowerCase(), 'konnichiwa');
    });

    test('Transliterates Korean Hangul to Romanized text accurately', () {
      final roman = UniversalLyricsTransliterationEngine.transliterateText('안녕하세요', 'roman');
      expect(roman.isNotEmpty, isTrue);
      expect(roman.contains('annyeong'), isTrue);
    });

    test('Transliterates Russian Cyrillic to Latin text accurately', () {
      final latin = UniversalLyricsTransliterationEngine.transliterateText('Привет мир', 'roman');
      expect(latin.toLowerCase().contains('privet'), isTrue);
    });

    test('Transliterates Roman lyrics into Devanagari accurately', () {
      final dev = UniversalLyricsTransliterationEngine.transliterateText('mera dil', 'devanagari');
      expect(dev.contains('दिल'), isTrue);
    });

    test('Converts Gurmukhi lyrics to Roman and Devanagari', () {
      final roman = UniversalLyricsTransliterationEngine.transliterateText('ਸਾਰੇ ਰੰਗ', 'roman');
      final devanagari = UniversalLyricsTransliterationEngine.transliterateText('ਸਾਰੇ ਰੰਗ', 'devanagari');
      expect(roman, isNot(contains('ਸਾਰੇ')));
      expect(devanagari, isNot(contains('ਸਾਰੇ')));
      expect(devanagari, contains('सा'));
    });

    test('Transliterates Devanagari lyrics to Gurmukhi and Urdu', () {
      const line = 'तेरे बिना ज़िन्दगी';
      final gurmukhi = UniversalLyricsTransliterationEngine.transliterateText(line, 'gurmukhi');
      final urdu = UniversalLyricsTransliterationEngine.transliterateText(line, 'urdu');

      expect(gurmukhi, contains('ਤੇਰੇ'));
      expect(urdu, contains('تیرے'));
    });

    test('Transliterates Arabic/Urdu lyrics to Devanagari and Gurmukhi', () {
      const line = 'مشک علی ظفر';
      final devanagari = UniversalLyricsTransliterationEngine.transliterateText(line, 'devanagari');
      final gurmukhi = UniversalLyricsTransliterationEngine.transliterateText(line, 'gurmukhi');

      expect(devanagari.isNotEmpty, isTrue);
      expect(devanagari, isNot(contains('مشک')));
      expect(gurmukhi.isNotEmpty, isTrue);
      expect(gurmukhi, isNot(contains('مشک')));
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
