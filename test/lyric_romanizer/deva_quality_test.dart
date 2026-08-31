import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyrics/devanagari_transliteration_service.dart';
import 'package:noctra/services/lyrics/lyrics_service.dart';

void main() {
  final engine = DevanagariTransliterationEngine();

  // ─────────────────────────────────────────────────
  // 1. Lexicon accuracy — words that MUST be exact
  // ─────────────────────────────────────────────────
  group('Lexicon accuracy', () {
    final lexiconTests = {
      // Core pronouns
      'tera': 'तेरा', 'teri': 'तेरी', 'tere': 'तेरे',
      'mera': 'मेरा', 'meri': 'मेरी', 'mere': 'मेरे',
      'tum': 'तुम', 'hum': 'हम', 'aap': 'आप',
      'main': 'मैं', 'mujhe': 'मुझे', 'mujhse': 'मुझसे',
      'tumhe': 'तुम्हें', 'tumhara': 'तुम्हारा',
      'woh': 'वो', 'wo': 'वो', 'yeh': 'यह', 'ye': 'ये',
      'jo': 'जो', 'koi': 'कोई',

      // Verbs
      'hai': 'है', 'hain': 'हैं', 'ho': 'हो',
      'tha': 'था', 'the': 'थे', 'thi': 'थी',
      'hoga': 'होगा', 'hogi': 'होगी', 'honge': 'होंगे',
      'karna': 'करना', 'karta': 'करता', 'karti': 'करती',
      'kiya': 'किया', 'gaya': 'गया', 'gayi': 'गई',
      'raha': 'रहा', 'rahi': 'रही', 'rahe': 'रहे',
      'dekha': 'देखा', 'dekho': 'देखो',
      'chahta': 'चाहता', 'chahti': 'चाहती', 'chahiye': 'चाहिए',
      'bol': 'बोल', 'bolo': 'बोलो', 'bole': 'बोले',
      'sochta': 'सोचता', 'bhula': 'भुला',

      // Emotions & nouns
      'dil': 'दिल', 'ishq': 'इश्क़', 'pyaar': 'प्यार', 'pyar': 'प्यार',
      'mohabbat': 'मोहब्बत', 'zindagi': 'ज़िंदगी',
      'dard': 'दर्द', 'sukoon': 'सुकून',
      'khushi': 'ख़ुशी', 'gham': 'ग़म',
      'intezaar': 'इंतेज़ार', 'armaan': 'अरमान',
      'sapna': 'सपना', 'sapne': 'सपने',
      'khwab': 'ख़्वाब', 'tamanna': 'तमन्ना',
      'chahat': 'चाहत', 'junoon': 'जूनून',
      'nazar': 'नज़र', 'mehfil': 'महफ़िल',
      'kesariya': 'केसरिया',

      // Nature
      'raat': 'रात', 'din': 'दिन', 'shaam': 'शाम', 'subah': 'सुबह',
      'chand': 'चाँद', 'suraj': 'सूरज',
      'baarish': 'बारिश', 'hawa': 'हवा',
      'khamoshi': 'ख़ामोशी', 'awaz': 'आवाज़',

      // Connectors
      'aur': 'और', 'lekin': 'लेकिन', 'phir': 'फिर',
      'nahi': 'नहीं', 'kuch': 'कुछ', 'bahut': 'बहुत',
      'kya': 'क्या', 'kyun': 'क्यों',
      'kabhi': 'कभी', 'hamesha': 'हमेशा',

      // Spiritual
      'dua': 'दुआ', 'rooh': 'रूह',
    };

    for (final entry in lexiconTests.entries) {
      test('lexicon: "${entry.key}" → "${entry.value}"', () {
        expect(engine.toDevanagari(entry.key), entry.value);
      });
    }
  });

  // ─────────────────────────────────────────────────
  // 2. Nasalization (anusvara) — 'n'/'m' before consonant
  // ─────────────────────────────────────────────────
  group('Nasalization (anusvara)', () {
    final nasalTests = {
      'rang': 'रंग',
      'sang': 'संग',
      'man': 'मन',
      'gungroo': 'गुंग्रू',
      'ghungroo': 'घुंघरू',
    };

    for (final entry in nasalTests.entries) {
      test('nasal: "${entry.key}" → "${entry.value}"', () {
        expect(engine.toDevanagari(entry.key), entry.value);
      });
    }
  });

  // ─────────────────────────────────────────────────
  // 3. Word-final standalone 'a' → long आ/ा
  // ─────────────────────────────────────────────────
  group('Word-final a → long aa', () {
    final finalATests = {
      'hua': 'हुआ',
      'gaya': 'गया',
      'dekha': 'देखा',
      'raha': 'रहा',
      'kiya': 'किया',
      'aaya': 'आया',
    };

    for (final entry in finalATests.entries) {
      test('final-a: "${entry.key}" → "${entry.value}"', () {
        expect(engine.toDevanagari(entry.key), entry.value);
      });
    }
  });

  // ─────────────────────────────────────────────────
  // 4. Digraph handling (ch, sh, th, dh, bh, etc.)
  // ─────────────────────────────────────────────────
  group('Digraphs', () {
    final digraphTests = {
      'chaha': 'चाहा',
      'shaam': 'शाम',
      'thoda': 'थोड़ा',
      'dhadkan': 'धड़कन',
      'bhula': 'भुला',
      'kuch': 'कुछ',
      'shayad': 'शायद',
    };

    for (final entry in digraphTests.entries) {
      test('digraph: "${entry.key}" → "${entry.value}"', () {
        expect(engine.toDevanagari(entry.key), entry.value);
      });
    }
  });

  // ─────────────────────────────────────────────────
  // 5. Multi-word phrases
  // ─────────────────────────────────────────────────
  group('Multi-word phrases', () {
    final phraseTests = {
      'dil se': 'दिल से',
      'mera dil': 'मेरा दिल',
      'kya hua': 'क्या हुआ',
      'tumhe pyar': 'तुम्हें प्यार',
      'mujhe chahiye': 'मुझे चाहिए',
      'hai kya': 'है क्या',
      'nahi hai': 'नहीं है',
    };

    for (final entry in phraseTests.entries) {
      test('phrase: "${entry.key}" → "${entry.value}"', () {
        expect(engine.toDevanagari(entry.key), entry.value);
      });
    }
  });

  // ─────────────────────────────────────────────────
  // 6. Vowel matras
  // ─────────────────────────────────────────────────
  group('Vowel matras', () {
    final matraTests = {
      'kabhi': 'कभी',
      'sunke': 'सुनके',
      'bolke': 'बोलके',
      'dekhe': 'देखे',
      'raatein': 'रातें',
      'yaadein': 'यादें',
    };

    for (final entry in matraTests.entries) {
      test('matra: "${entry.key}" → "${entry.value}"', () {
        expect(engine.toDevanagari(entry.key), entry.value);
      });
    }
  });

  // ─────────────────────────────────────────────────
  // 7. Real song lyric lines (famous Hindi songs)
  // ─────────────────────────────────────────────────
  group('Real song lyrics', () {
    test('Tum Hi Ho — "hum tere bin ab reh nahi sakte"', () {
      expect(engine.toDevanagari('hum tere bin ab reh nahi sakte'),
          'हम तेरे बिन अब रह नहीं सकते');
    });

    test('Kabira — "tere jaisa na koi"', () {
      expect(engine.toDevanagari('tere jaisa na koi'),
          'तेरे जैसा ना कोई');
    });

    test('Agar Tum Saath Ho — "agar tum saath ho"', () {
      expect(engine.toDevanagari('agar tum saath ho'),
          'अगर तुम साथ हो');
    });

    test('Chaiyya Chaiyya — "chal chaiyya chaiyya"', () {
      expect(engine.toDevanagari('chal chaiyya chaiyya'),
          'चल चैय्या चैय्या');
    });

    test('Kal Ho Naa Ho — "har ghadi badal rahi hai"', () {
      expect(engine.toDevanagari('har ghadi badal rahi hai'),
          'हर घडी बदल रही है');
    });

    test('Tujhe Dekha To — "tujhe dekha to ye jana sanam"', () {
      expect(engine.toDevanagari('tujhe dekha to ye jana sanam'),
          'तुझे देखा तो ये जाना सनम');
    });

    test('Gerua — "tere sang ishq main rang de"', () {
      final result = engine.toDevanagari('tere sang ishq main rang de');
      expect(result, contains('तेरे'));
      expect(result, contains('इश्क़'));
      expect(result, contains('रंग'));
    });

    test('Maula — "maula mere le le meri jaan"', () {
      final result = engine.toDevanagari('maula mere le le meri jaan');
      expect(result, contains('मौला'));
      expect(result, contains('मेरे'));
      expect(result, contains('जान'));
    });
  });

  // ─────────────────────────────────────────────────
  // 8. Edge cases
  // ─────────────────────────────────────────────────
  group('Edge cases', () {
    test('empty string', () {
      expect(engine.toDevanagari(''), '');
    });

    test('whitespace only', () {
      expect(engine.toDevanagari('   '), '   ');
    });

    test('already Devanagari — passthrough', () {
      expect(engine.toDevanagari('दिल से'), 'दिल से');
    });

    test('mixed Latin + Devanagari', () {
      final result = engine.toDevanagari('dil दिल');
      expect(result, contains('दिल'));
    });

    test('punctuation preserved', () {
      expect(engine.toDevanagari('kya?'), 'क्या?');
      expect(engine.toDevanagari('ha!'), 'हा!');
    });

    test('single character', () {
      expect(engine.toDevanagari('a'), 'अ');
      expect(engine.toDevanagari('i'), 'इ');
    });
  });

  // ─────────────────────────────────────────────────
  // 9. Fuzzy lookup — near-miss spellings
  // ─────────────────────────────────────────────────
  group('Fuzzy lookup', () {
    test('"pyaaar" → matches "pyaar" → प्यार', () {
      expect(engine.toDevanagari('pyaaar'), 'प्यार');
    });

    test('"zindgi" → matches "zindagi" → ज़िंदगी', () {
      expect(engine.toDevanagari('zindgi'), 'ज़िंदगी');
    });

    test('"kabhii" → matches "kabhi" → कभी', () {
      expect(engine.toDevanagari('kabhii'), 'कभी');
    });
  });

  // ─────────────────────────────────────────────────
  // 10. batchTransliterateLyrics — full lyrics data
  // ─────────────────────────────────────────────────
  group('transliterateLyrics', () {
    test('converts lyrics data to Devanagari', () {
      final data = LyricsData(
        isSynced: true,
        lines: [
          LyricLine(timestamp: Duration.zero, text: 'dil se'),
          LyricLine(timestamp: Duration(seconds: 3), text: 'pyar hai'),
        ],
        plainText: 'dil se\npyar hai',
      );

      final result = engine.transliterateLyrics(data, 'devanagari');
      expect(result.lines[0].text, 'दिल से');
      expect(result.lines[1].text, 'प्यार है');
      expect(result.plainText, 'दिल से\nप्यार है');
    });

    test('non-devanagari target returns unchanged', () {
      final data = LyricsData(
        isSynced: true,
        lines: [LyricLine(timestamp: Duration.zero, text: 'dil se')],
        plainText: 'dil se',
      );

      final result = engine.transliterateLyrics(data, 'roman');
      expect(result.lines[0].text, 'dil se');
    });
  });
}
