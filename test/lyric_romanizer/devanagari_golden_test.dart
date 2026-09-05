import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyrics/dynamic_lexicon.dart';
import 'package:noctra/services/lyrics/romanized_translation_engine.dart';

/// Golden tests for the Devanagari → Roman lyric romanization path.
///
/// The engine consults an exact-word lexicon BEFORE the phonetic parser,
/// so these tests isolate the parser with an empty lexicon
/// (`DynamicLexicon(seed: {})`) and assert exact deterministic phonetic
/// output — never merely `isNotEmpty`. A separate group locks the
/// lexicon-driven short forms that intentionally override the parser.
void main() {
  // Empty lexicon → pure phonetic parser.
  final phonetic =
      RomanizedTranslationEngine(lexicon: DynamicLexicon(seed: {}));
  // Ship lexicon (default built-in words win over the parser).
  final lexical = RomanizedTranslationEngine();

  group('vowel matrix (क + vowel / matra) — phonetic', () {
    test('independent and dependent vowels', () {
      expect(phonetic.toRoman('क'), 'K'); // word-final schwa deleted
      expect(phonetic.toRoman('का'), 'Kaa');
      expect(phonetic.toRoman('कि'), 'Ki');
      expect(phonetic.toRoman('की'), 'Kee');
      expect(phonetic.toRoman('कु'), 'Ku');
      expect(phonetic.toRoman('कू'), 'Koo');
      expect(phonetic.toRoman('के'), 'Ke');
      expect(phonetic.toRoman('कै'), 'Kai');
      expect(phonetic.toRoman('को'), 'Ko');
      expect(phonetic.toRoman('कौ'), 'Kau');
      expect(phonetic.toRoman('कृ'), 'Kri');
    });
  });

  group('virama / conjuncts — phonetic', () {
    test('halant suppresses the inherent vowel', () {
      expect(phonetic.toRoman('क्'), 'K'); // bare conjunct carrier
      expect(phonetic.toRoman('क्ष'), 'Ksh');
      expect(phonetic.toRoman('त्र'), 'Tr');
      expect(phonetic.toRoman('प्र'), 'Pr');
      expect(phonetic.toRoman('श्री'), 'Shree'); // श + ् + र + ी
    });

    test('mid-word conjunct keeps the following matra, not an extra vowel', () {
      expect(phonetic.toRoman('नमस्ते'), 'Namaste'); // न म स् त े
      expect(phonetic.toRoman('क्षमा'), 'Kshamaa'); // क् ष म ा
    });
  });

  group('anusvara / chandrabindu / visarga (regression) — phonetic', () {
    test('bare consonant + anusvara nasalises the INHERENT vowel', () {
      // Regression: the nasal used to be emitted BEFORE the vowel
      // (कं → "kn"); the inherent vowel must survive (कं → "kan").
      expect(phonetic.toRoman('कंपनी'), 'Kanpanee');
      expect(phonetic.toRoman('कंधा'), 'Kandhaa');
    });

    test('anusvara after an explicit vowel sign stays a pure nasal', () {
      expect(phonetic.toRoman('हिंदी'), 'Hindee'); // ि + ं — no extra 'a'
      expect(phonetic.toRoman('मैं'), 'Main'); // ै + ं
    });

    test('visarga aspirates the inherent vowel', () {
      expect(phonetic.toRoman('दुःख'), 'Duhkh'); // द ु ः ख
    });
  });

  group('nukta consonants (regression) — phonetic', () {
    test('composed nukta letters map to their Urdu phonemes', () {
      // Regression: ज़/फ़/क़ are base + U+093C (two code points) and were
      // never matched, silently degrading to the base consonant.
      expect(phonetic.toRoman('फ़िल्म'), 'Film');
      expect(phonetic.toRoman('क़िस्मत'), 'Qismat');
      expect(phonetic.toRoman('ज़रूरत'), 'Zaroorat');
    });
  });

  group('word-level — phonetic', () {
    test('multi-word input preserves spacing and punctuation', () {
      expect(phonetic.toRoman('नमस्ते दुनिया'), 'Namaste Duniyaa');
      expect(phonetic.toRoman('प्रेम, जीवन!'), 'Prem, Jeevan!');
    });
  });

  group('lexicon integration (default engine)', () {
    test('common words keep their preferred dictionary spellings', () {
      // The lexicon intentionally overrides the naive parser for the most
      // common function words — verify those overrides still apply.
      expect(lexical.toRoman('का'), 'Ka');
      expect(lexical.toRoman('ही'), 'Hi');
      expect(lexical.toRoman('है'), 'Hai');
    });

    test('uncommon words fall through to the phonetic parser', () {
      expect(lexical.toRoman('कंपनी'), 'Kanpanee');
      expect(lexical.toRoman('फ़िल्म'), 'Film');
    });
  });
}
