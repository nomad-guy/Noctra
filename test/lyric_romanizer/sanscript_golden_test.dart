import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyrics/sanscript_engine.dart';

/// Golden tests for the phoneme-driven cross-Indic-script converter.
///
/// Conversion pivots through Devanagari phonemes and emits each phoneme
/// through per-script orthographic tables, so the expectations below pin
/// down *linguistic* behavior — collapsed phonemes (Tamil), merged va
/// (Bengali/Odia), composed nukta letters (Gurmukhi), Punjabi addak/tippi —
/// not raw Unicode block arithmetic.
///
/// Expectations that previously failed to paste reliably (Gurmukhi composed
/// letters) are written with explicit `\uXXXX` escapes so the codepoint
/// sequence is byte-exact.
void main() {
  const deva = SanscriptEngine.devanagari;
  const gu = SanscriptEngine.gurmukhi;
  const bn = SanscriptEngine.bengali;
  const gj = SanscriptEngine.gujarati;
  const te = SanscriptEngine.telugu;
  const kn = SanscriptEngine.kannada;
  const ml = SanscriptEngine.malayalam;
  const od = SanscriptEngine.odia;
  const ta = SanscriptEngine.tamil;

  String x(String input, String from, String to) =>
      SanscriptEngine.transliterate(input, from, to);

  // Byte-exact Gurmukhi strings. ਸ਼ is the dedicated GURMUKHI LETTER SHA
  // (U+0A36); ਜ਼ is LETTER ZA (U+0A5B); ਫ਼ is LETTER FA (U+0A5E) — real
  // single codepoints, so the goldens below pin those exact forms (real
  // Punjabi text is often typed decomposed; the engine canonicalises both).
  // ਕਸ਼੍ਟ keeps the ੍ after ਸ਼ because it encodes the conjunct's vowel-less
  // ष (a bare ਸ਼ਟ would read back as कसट). All strings are \uXXXX escapes
  // so the codepoint sequence is byte-exact regardless of editor
  // normalization.
  const guZindagi = '\u0A5B\u0A3F\u0A28\u0A4D\u0A26\u0A17\u0A40'; // ਜ਼ਿੰਦਗੀ
  const guPrem = '\u0A2A\u0A4D\u0A30\u0A47\u0A2E'; // ਪ੍ਰੇਮ
  const guFilm = '\u0A5E\u0A3F\u0A32\u0A4D\u0A2E'; // ਫ਼ਿਲ੍ਮ
  const guShaam = '\u0A36\u0A3E\u0A2E'; // ਸ਼ਾਮ
  const guKast = '\u0A15\u0A36\u0A4D\u0A1F'; // ਕਸ਼੍ਟ
  const guDevanagari =
      '\u0A26\u0A47\u0A35\u0A28\u0A3E\u0A17\u0A30\u0A40'; // ਦੇਵਨਾਗਰੀ

  group('Devanagari → Bengali (orthographic va/ळ/ऱ)', () {
    test('va merges into ব, not the unassigned ঵ row', () {
      // द े व न ा ग र ी → দ ে ব ন া গ র ী
      expect(x('देवनागरी', deva, bn), 'দেবনাগরী');
    });

    test('ळ/ऱ collapse to ল/র', () {
      expect(x('झळ', deva, bn), 'ঝল');
      expect(x('कऱ', deva, bn), 'কর');
    });

    test('consonants, vowel signs, conjuncts and marks keep rows', () {
      expect(x('क', deva, bn), 'ক');
      expect(x('े', deva, bn), 'ে');
      expect(x('प्रेम', deva, bn), 'প্রেম');
      expect(x('क्ष', deva, bn), 'ক্ষ');
      expect(x('संग', deva, bn), 'সংগ'); // ं row → ং
    });

    test('nukta letters approximate to plain stops', () {
      expect(x('फ़िल्म', deva, bn), 'ফিল্ম');
      // ज़ → জ (Bengali has no nukta convention for z), ं → ং
      expect(x('ज़िंदगी', deva, bn), 'জিংদগী');
    });
  });

  group('Devanagari → Gurmukhi', () {
    test('offset consonants and vowel signs', () {
      expect(x('देवनागरी', deva, gu), guDevanagari);
    });

    test('श/ष become the composed ਸ਼ letter', () {
      expect(x('शाम', deva, gu), guShaam);
      expect(x('कष्ट', deva, gu), guKast);
    });

    test('virama conjuncts transcribe with ੍', () {
      // प + ् + र + े + म → ਪ + ੍ + ਰ + ੇ + ਮ
      expect(x('प्रेम', deva, gu), guPrem);
    });

    test('nukta letters use the composed Gurmukhi forms', () {
      // ज़ ि न ् द ग ी → ਜ਼ ਿ ਨ ੍ ਦ ਗ ੀ
      expect(x('ज़िन्दगी', deva, gu), guZindagi);
      // फ़ ि ल ् म → ਫ਼ ਿ ਲ ੍ ਮ
      expect(x('फ़िल्म', deva, gu), guFilm);
    });
  });

  group('Gurmukhi → Devanagari (addak, tippi, nukta)', () {
    test('composed ਸ਼/ਨੁਕਤਾ letters map back to phonemes', () {
      // ਜ਼ਿੰਦਗੀ → ज़िन्दगी (ਜ਼ U+0A5B → composed ज़ U+095B; ਨ੍ਦ is a
      // consonant cluster, not an anusvara)
      expect(
          x(guZindagi, gu, deva), '\u095B\u093F\u0928\u094D\u0926\u0917\u0940');
      // ਖ਼ → ख़, ਫ਼ → फ़, ਡ਼ → ड़
      expect(x('ਖ਼ਾ', gu, deva), 'ख़ा'); // xhaa
      expect(x('ਫ਼ਿਲ੍ਮ', gu, deva), 'फ़िल्म'); // film
    });

    test('addak (ੱ) geminates the following consonant', () {
      // ਸ ੱ ਚ ਾ → स च्च ा
      expect(x('\u0A38\u0A71\u0A1A\u0A3E', gu, deva), 'सच्चा');
      // ਜ ੱ ਟ → ज ट्ट
      expect(x('\u0A1C\u0A71\u0A1F', gu, deva), 'जट्ट');
    });

    test('tippi (ੰ) becomes anusvara', () {
      // ਪ ੰ ਜ ਾ ਬ ੀ → प ं ज ा ब ी
      expect(x('\u0A2A\u0A70\u0A1C\u0A3E\u0A2C\u0A40', gu, deva), 'पंजाबी');
    });
  });

  group('Devanagari → other scripts', () {
    test('Gujarati', () {
      expect(x('क', deva, gj), 'ક');
      expect(x('देवनागरी', deva, gj), 'દેવનાગરી');
    });

    test('Telugu', () {
      expect(x('क', deva, te), 'క');
      expect(x('देवनागरी', deva, te), 'దేవనాగరీ');
      expect(x('गाना', deva, te), 'గానా');
    });

    test('Kannada', () {
      expect(x('क', deva, kn), 'ಕ');
      expect(x('देवनागरी', deva, kn), 'ದೇವನಾಗರೀ');
    });

    test('Malayalam', () {
      expect(x('क', deva, ml), 'ക');
      expect(x('देवनागरी', deva, ml), 'ദേവനാഗരീ');
    });

    test('Odia (va → ବ)', () {
      expect(x('क', deva, od), 'କ');
      expect(x('देवनागरी', deva, od), 'ଦେବନାଗରୀ');
    });
  });

  group('Devanagari → Tamil (phoneme collapse)', () {
    test('voiced/aspirated stops collapse to the unaspirated glyph', () {
      expect(x('क', deva, ta), 'க');
      expect(x('ग', deva, ta), 'க'); // ग → க
      // ग ा न ा → க ா ந ா (ந is the dental na)
      expect(x('गाना', deva, ta), 'காநா');
      expect(x('भारत', deva, ta), 'பாரத'); // भ ा र त
      expect(x('तुम', deva, ta), 'தும'); // त ु ம
    });

    test('sibilants and clusters keep their rows', () {
      expect(x('शिव', deva, ta), 'சிவ'); // श → ச (Grantha ஶ avoided)
      expect(x('राष्ट्र', deva, ta), 'ராஷ்ட்ர');
    });
  });

  group('Round trips and reversibility', () {
    test('lossless content round-trips through Bengali', () {
      // ब/व both merge into ব, so only ब-only words are lossless.
      expect(x(x('प्रेम', deva, bn), bn, deva), 'प्रेम');
      expect(x(x('संगीत', deva, bn), bn, deva), 'संगीत');
    });

    test('Bengali व-merge is intentionally lossy', () {
      // व → ব (Bengali's va slot is unassigned), so देवनागरी loses व.
      expect(x('देवनागरी', deva, bn), 'দেবনাগরী');
      expect(x(x('देवनागरी', deva, bn), bn, deva), 'देबनागरी');
    });

    test('round-trips through Gurmukhi', () {
      expect(x(x('प्रेम', deva, gu), gu, deva), 'प्रेम');
      expect(x(x('देवनागरी', deva, gu), gu, deva), 'देवनागरी');
      // ष-words keep their phoneme through ਸ਼
      expect(x(x('कष्ट', deva, gu), gu, deva), 'कष्ट');
      // ਸ਼ is ambiguous in Gurmukhi and resolves to ष on the way back;
      // श → ਸ਼ is still correct in the forward direction.
      expect(x('शाम', deva, gu), guShaam);
    });

    test('round-trips through Telugu', () {
      const word = 'देवनागरी';
      expect(x(x(word, deva, te), te, deva), word);
    });

    test('Tamil collapse is intentionally lossy', () {
      // ग → க, and க parses back as क: voicing is not recoverable.
      expect(x(x('गाना', deva, ta), ta, deva), 'काना');
    });

    test('non-Devanagari → non-Devanagari travels through the pivot', () {
      final direct = x('দেবনাগরী', bn, gu);
      final viaPivot = x(x('দেবনাগরী', bn, deva), deva, gu);
      expect(direct, viaPivot);
    });
  });

  group('Complex lyric/rap content', () {
    // Dense Hindi line with heavy conjunct + nukta + nasal usage.
    const dense = 'ज़िन्दगी भर प्रेम क्षमा संगीत फ़िल्म';
    test('dense Devanagari converts without losing syllables (Gurmukhi)', () {
      final out = x(dense, deva, gu);
      expect(out, contains(guZindagi));
      expect(out, contains(guPrem));
      expect(out, contains(guFilm));
    });

    test('dense Devanagari converts to Bengali with conjuncts intact', () {
      final out = x(dense, deva, bn);
      expect(out, contains('জিন্দগী'));
      expect(out, contains('প্রেম'));
      expect(out, contains('ক্ষমা'));
      expect(out, contains('সংগীত'));
      expect(out, contains('ফিল্ম'));
    });

    test('Latin words, digits and punctuation always pass through', () {
      for (final script in [bn, gu, ta, te, ml, od, gj, kn]) {
        expect(x('yo! track 2 (remix)', deva, script), 'yo! track 2 (remix)');
      }
    });
  });

  group('Pass-through and safety', () {
    test('same-script input is returned unchanged', () {
      expect(x('देवनागरी', deva, deva), 'देवनागरी');
    });

    test('empty and whitespace-only input', () {
      expect(x('', deva, bn), '');
      expect(x('   ', deva, gu), '   ');
    });

    test('unsupported script paths return the input unchanged', () {
      expect(x('namaste', SanscriptEngine.itrans, deva), 'namaste');
      expect(x('devanagari', deva, SanscriptEngine.iast), 'devanagari');
      expect(x('x', SanscriptEngine.hk, SanscriptEngine.itrans), 'x');
    });

    test('unknown script name is a no-op', () {
      expect(x('दिल', deva, 'klingon'), 'दिल');
    });

    test('decomposed nukta input normalises to the same output', () {
      // फ + ़ (two code points) must equal composed फ़ (single codepoint).
      final decomposed = '\u092B\u093Cिल्म'; // फ़िल्म written decomposed
      expect(x(decomposed, deva, gu), x('फ़िल्म', deva, gu));
    });
  });
}
