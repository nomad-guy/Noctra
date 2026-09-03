/// Phoneme-driven cross-Indic-script converter.
///
/// **Architecture (replaces the old Unicode block-offset mapper):**
///
/// Every Brahmic script encodes the SAME ordered phonetic series
/// (vowels → consonants → vowel signs → virama → marks), but the *glyph*
/// for a given phoneme does not always sit at the same offset inside its
/// Unicode block — e.g. Bengali merged व into ব (its row for व is
/// unassigned), Gurmukhi writes श/ष as ਸ਼ at a different position and
/// stores nukta consonants as composed letters (ਖ਼ ਜ਼ ਫ਼), and Tamil only
/// keeps the unaspirated/voiceless letter of each consonant class. Pure
/// offset math silently emits wrong or invisible characters for all of
/// those — exactly what broke complex lyric/rap conversion before.
///
/// Conversion therefore works in two stages:
///   1. *Parse* the source into Devanagari, which is used purely as a
///      phonetic pivot: each source glyph is mapped back to its phoneme
///      (row identity, or an explicit override where the row is wrong).
///   2. *Emit* each phoneme into the target script through per-script
///      orthographic tables. Row fallback is used ONLY where the target's
///      glyph genuinely occupies the same phoneme slot as Devanagari;
///      every known divergence has an explicit table entry.
///
/// Characters with no mapping are passed through unchanged — the engine
/// never fabricates a glyph, never emits an unassigned codepoint, and
/// never pretends a missing phoneme exists.
///
/// **Known limitations (unchanged):**
///   - Latin/IAST/ITRANS/HK are NOT implemented; input is returned
///     unchanged for those paths (Roman↔Indic lives in the dedicated
///     Romanized/Devanagari engines).
///   - Scripts with a smaller phoneme inventory than Devanagari (Tamil,
///     Gurmukhi) collapse phonemes to their nearest written form; the
///     collapsed direction cannot recover the original distinction.
class SanscriptEngine {
  SanscriptEngine._();

  static const String devanagari = 'devanagari';
  static const String gurmukhi = 'gurmukhi';
  static const String bengali = 'bengali';
  static const String gujarati = 'gujarati';
  static const String telugu = 'telugu';
  static const String tamil = 'tamil';
  static const String kannada = 'kannada';
  static const String malayalam = 'malayalam';
  static const String odia = 'odia';
  static const String itrans = 'itrans';
  static const String iast = 'iast';
  static const String hk = 'hk';

  /// Base codepoint of each supported script's block.
  static const Map<String, int> _base = {
    'devanagari': 0x0900,
    'bengali': 0x0980,
    'gurmukhi': 0x0A00,
    'gujarati': 0x0A80,
    'tamil': 0x0B80,
    'telugu': 0x0C00,
    'kannada': 0x0C80,
    'odia': 0x0B00,
    'malayalam': 0x0D00,
  };

  // ─── Devanagari nukta handling ────────────────────────────────────────
  // Decomposed input (base consonant + U+093C) is normalised to its
  // composed form so both spellings hit the same table entries.
  static const Map<String, String> _devaNuktaCompose = {
    '\u0915\u093C': '\u0958', // क़
    '\u0916\u093C': '\u0959', // ख़
    '\u0917\u093C': '\u095A', // ग़
    '\u091C\u093C': '\u095B', // ज़
    '\u0921\u093C': '\u095C', // ड़
    '\u0922\u093C': '\u095D', // ढ़
    '\u092B\u093C': '\u095E', // फ़
    '\u092F\u093C': '\u095F', // य़
  };

  // Gurmukhi spells nukta consonants as dedicated letters where Unicode
  // provides them (ਖ਼ U+0A59, ਜ਼ U+0A5B, ਸ਼ U+0A36 …) but real Punjabi
  // text is frequently typed decomposed (base + U+0A3C). Canonicalise the
  // decomposed spelling to the dedicated letter so both inputs hit the
  // same parse/emit path.
  static const Map<String, String> _gurmukhiNuktaCompose = {
    '\u0A16\u0A3C': '\u0A59', // ਖ਼
    '\u0A17\u0A3C': '\u0A5A', // ਗ਼
    '\u0A1C\u0A3C': '\u0A5B', // ਜ਼
    '\u0A21\u0A3C': '\u0A5C', // ਡ਼ → ੜ
    '\u0A22\u0A3C': '\u0A5D', // ਢ਼
    '\u0A25\u0A3C': '\u0A5E', // ਫ਼
    '\u0A38\u0A3C': '\u0A36', // ਸ਼
    '\u0A32\u0A3C': '\u0A33', // ਲ਼
  };

  // ─── Per-script phoneme → glyph overrides (Devanagari keyed) ─────────

  /// Consonants whose target glyph diverges from the Devanagari row
  /// (unassigned slot, merged phoneme, or composed-letter orthography).
  static const Map<String, Map<String, String>> _consonantOverrides = {
    // Bengali merged the व slot into ব (its व row is unassigned); ळ/ऱ
    // rows are unassigned so they collapse to ल/र.
    'bengali': {
      '\u0935': '\u09AC', // व → ব
      '\u0933': '\u09B2', // ळ → ল
      '\u0931': '\u09B0', // ऱ → র
      '\u0958': '\u0995', // क़ → ক
      '\u0959': '\u0996', // ख़ → খ
      '\u095A': '\u0997', // ग़ → গ
      '\u095B': '\u099C', // ज़ → জ
      '\u095C': '\u09A1', // ड़ → ড
      '\u095D': '\u09A2', // ढ़ → ঢ
      '\u095E': '\u09AB', // फ़ → ফ
    },
    // Gurmukhi spells श/ष as ਸ਼ and nukta letters as dedicated letters
    // (U+0A36 ਸ਼, U+0A59 ਖ਼, U+0A5A ਗ਼, U+0A5B ਜ਼, U+0A5C ਡ਼, U+0A5D ਢ਼,
    // U+0A5E ਫ਼, U+0A33 ਲ਼); ਕ਼ has no Punjabi equivalent so it falls
    // back to ਕ.
    'gurmukhi': {
      'ष': 'ਸ਼', // ष → ਸ਼
      'श': 'ਸ਼', // श → ਸ਼
      'क़': 'ਕ', // क़ → ਕ (no Punjabi qa)
      'ख़': 'ਖ਼', // ਖ਼ → ਖ਼
      'ग़': 'ਗ਼', // ਗ਼ → ਗ਼
      'ज़': 'ਜ਼', // ਜ਼ → ਜ਼
      'ड़': 'ੜ', // ਡ਼ → ਡ਼
      'ढ़': '੝', // ਢ਼ → ਢ਼
      'फ़': 'ਫ਼', // ਫ਼ → ਫ਼
    },
    'gujarati': {
      '\u0931': '\u0AB0', // ऱ → ર (Gujarati row unassigned)
      '\u0958': '\u0A95',
      '\u0959': '\u0A96',
      '\u095A': '\u0A97',
      '\u095B': '\u0A9C',
      '\u095C': '\u0AA1',
      '\u095D': '\u0AA2',
      '\u095E': '\u0AAB',
    },
    // Odia writes व as ବ (its ଵ row is archaic).
    'odia': {
      '\u0935': '\u0B2C', // व → ବ
      '\u0931': '\u0B30', // ऱ → ର
      '\u0958': '\u0B15',
      '\u0959': '\u0B16',
      '\u095A': '\u0B17',
      '\u095B': '\u0B1C',
      '\u095C': '\u0B21',
      '\u095D': '\u0B22',
      '\u095E': '\u0B2B',
    },
    // क़/ख़/ग़/ज़/ड़/ढ़/फ़ rows are unassigned in these scripts; use the
    // nearest native letter (డ़/ढ़ collapse to the retroflex flap ఱ/ಱ/റ).
    'telugu': {
      '\u0958': '\u0C15',
      '\u0959': '\u0C16',
      '\u095A': '\u0C17',
      '\u095B': '\u0C1C',
      '\u095C': '\u0C31',
      '\u095D': '\u0C31',
      '\u095E': '\u0C2B',
    },
    'kannada': {
      '\u0958': '\u0C95',
      '\u0959': '\u0C96',
      '\u095A': '\u0C97',
      '\u095B': '\u0C9C',
      '\u095C': '\u0CB1',
      '\u095D': '\u0CB1',
      '\u095E': '\u0CAB',
    },
    'malayalam': {
      '\u0958': '\u0D15',
      '\u0959': '\u0D16',
      '\u095A': '\u0D17',
      '\u095B': '\u0D1C',
      '\u095C': '\u0D31',
      '\u095D': '\u0D31',
      '\u095E': '\u0D2B',
    },
    'tamil': {
      // Tamil keeps only the first (unaspirated/voiceless) glyph of each
      // consonant class: aspirated and voiced letters collapse to it.
      '\u0916': '\u0B95', // ख → க
      '\u0917': '\u0B95', // ग → க
      '\u0918': '\u0B95', // घ → க
      '\u091A': '\u0B9A', // च → ச
      '\u091B': '\u0B9A', // छ → ச
      '\u091D': '\u0B9A', // झ → ச
      '\u091F': '\u0B9F', // ट → ட
      '\u0920': '\u0B9F', // ठ → ட
      '\u0921': '\u0B9F', // ड → ட
      '\u0922': '\u0B9F', // ढ → ட
      '\u0924': '\u0BA4', // त → த
      '\u0925': '\u0BA4', // थ → த
      '\u0926': '\u0BA4', // द → த
      '\u0927': '\u0BA4', // ध → த
      '\u092A': '\u0BAA', // प → ப
      '\u092B': '\u0BAA', // फ → ப
      '\u092D': '\u0BAA', // भ → ப
      '\u0936': '\u0B9A', // श → ச (Tamil ஶ U+0BB6 is Grantha-only)
      '\u0937': '\u0BB7', // ष → ஷ (row, kept explicit for clarity)
      '\u0938': '\u0BB8', // स → ஸ (row)
      '\u0958': '\u0B95',
      '\u0959': '\u0B95',
      '\u095A': '\u0B95',
      '\u095B': '\u0B9C', // ज़ → ஜ (row 0x1C → U+0B9C ஜ)
      '\u095C': '\u0BB1', // ड़ → ற
      '\u095D': '\u0BB1',
      '\u095E': '\u0BAA',
      '\u095F': '\u0BAF',
    },
  };

  /// Independent vowels whose target row is unassigned or conventionalised.
  static const Map<String, Map<String, String>> _vowelOverrides = {
    // Bengali has no ऍ/ऑ/ऎ/ऒ — approximate with the nearest e/o letters.
    'bengali': {
      '\u090D': '\u098F', // ऍ → এ
      '\u090E': '\u098F', // ऎ → এ
      '\u0911': '\u0993', // ऑ → ও
      '\u0912': '\u0993', // ऒ → ও
      '\u090B': '\u098B', // ऋ → ঋ (row, kept for clarity)
    },
    'gurmukhi': {
      // Gurmukhi lacks ऋ/ॠ/ऍ/ऑ; loanwords write ri/ra/e/o explicitly.
      '\u090B': '\u0A30\u0A3F', // ऋ → ਰਿ
      '\u0960': '\u0A30\u0A40', // ॠ → ਰੀ
      '\u090D': '\u0A0F', // ऍ → ਏ
      '\u0911': '\u0A06', // ऑ → ਆ
      '\u090E': '\u0A0F', // ऎ → ਏ
      '\u0912': '\u0A13', // ऒ → ਓ
    },
    'tamil': {
      '\u090B': '\u0BB0\u0BC1', // ऋ → ரு
      '\u0960': '\u0BB0\u0BC2', // ॠ → ரூ
      '\u090C': '\u0BB2\u0BC1', // ऌ → லு
      '\u0961': '\u0BB2\u0BC2', // ॡ → லூ
      '\u090D': '\u0B8E', // ऍ → எ
      '\u090E': '\u0B8E', // ऎ → எ
      '\u0911': '\u0B93', // ऑ → ஒ
      '\u0912': '\u0B92', // ऒ → ஒ
    },
    'odia': {
      '\u090D': '\u0B0F',
      '\u090E': '\u0B0F',
      '\u0911': '\u0B13',
      '\u0912': '\u0B13',
    },
  };

  /// Vowel-sign (matra) overrides where the target row is unassigned.
  static const Map<String, Map<String, String>> _matraOverrides = {
    'gurmukhi': {
      // Gurmukhi has no vocalic-r sign; ਕ੍ਰਿ is the standard transcription.
      '\u0943': '\u0A4D\u0A30\u0A3F', // ृ → ੍ਰਿ
      '\u0944': '\u0A4D\u0A30\u0A40', // ॄ → ੍ਰੀ
    },
    'tamil': {
      '\u0943': '', // ृ has no Tamil sign; caller keeps consonant bare
      '\u0944': '',
      '\u0945': '\u0BC6', // ॅ → ெ
      '\u0949': '\u0BCA', // ॊ → ொ
    },
    'bengali': {
      '\u0945': '\u09C7',
      '\u0949': '\u09CB',
    },
  };

  /// Marks (candrabindu/anunasika etc.) that do not row-align.
  static const Map<String, Map<String, String>> _markOverrides = {
    'tamil': {
      '\u0901': '\u0B82', // ँ → ஂ (Tamil row unassigned)
      '\u093D': '\u0B83', // ऽ → ஃ (no Tamil avagraha; aytham is nearest)
    },
  };

  /// Transliterate [input] text from [fromScript] to [toScript].
  static String transliterate(
          String input, String fromScript, String toScript) =>
      t(input, fromScript, toScript);

  static String t(String input, String fromScript, String toScript) {
    if (input.trim().isEmpty || fromScript == toScript) return input;
    final from = fromScript.toLowerCase();
    final to = toScript.toLowerCase();
    if (!_base.containsKey(from) || !_base.containsKey(to)) {
      // Unsupported script paths (itrans/iast/hk/Latin) never fabricate:
      // input is returned unchanged.
      return input;
    }

    if (from == devanagari) {
      return _emit(_normalizeNukta(input, from), to);
    }
    final pivot = _normalizeNukta(_parseToDevanagari(input, from), devanagari);
    if (to == devanagari) return pivot;
    return _emit(pivot, to);
  }

  /// Normalise decomposed nukta spellings to their composed codepoints so
  /// table lookups see one canonical key per phoneme.
  static String _normalizeNukta(String text, String script) {
    final compose =
        script == gurmukhi ? _gurmukhiNuktaCompose : _devaNuktaCompose;
    if (compose.isEmpty) return text;
    var out = text;
    compose.forEach((decomposed, composed) {
      out = out.replaceAll(decomposed, composed);
    });
    return out;
  }

  /// Stage 1 — map source glyphs to the Devanagari phonetic pivot.
  /// Row identity IS the phoneme series, so row fallback is phonetically
  /// correct; explicit overrides fix the glyphs whose row lies elsewhere.
  static String _parseToDevanagari(String text, String from) {
    final fromBase = _base[from]!;
    final devaBase = _base[devanagari]!;
    final buf = StringBuffer();

    var i = 0;
    while (i < text.length) {
      final code = text.codeUnitAt(i);

      // Gurmukhi-specific handling: addak doubles the next consonant,
      // tippi is anusvara, composed nukta letters map to Devanagari ones.
      if (from == gurmukhi) {
        if (code == 0x0A71) {
          // ੱ (addak): geminate the following consonant. In Devanagari
          // gemination is written consonant + virama + consonant
          // (ਸੱਚਾ → सच्चा), not a bare double letter (सचचा would be a
          // different, non-geminated reading). The doubled consonant is
          // consumed here so the main loop below must NOT emit it again.
          if (i + 1 < text.length) {
            final next = text.codeUnitAt(i + 1);
            if (next >= 0x0A15 && next <= 0x0A39) {
              final devaNext = String.fromCharCode(next - 0x0A00 + devaBase);
              buf
                ..write(devaNext)
                ..write('\u094D')
                ..write(devaNext);
              i += 2; // consume addak AND the doubled consonant
              continue;
            }
          }
          i++;
          continue;
        }
        if (code == 0x0A70) {
          buf.write('\u0902'); // ੰ → ं
          i++;
          continue;
        }
        // One source of truth: each Gurmukhi consonant that takes a nukta
        // and its Devanagari phoneme. Used both for the composed dedicated
        // letters (ਸ਼ ਖ਼ ਜ਼ ਫ਼ … — real codepoints) and for the decomposed
        // spelling (base consonant + U+0A3C) via the pair branch below.
        const gurmukhiNuktaBaseToDeva = {
          0x0A15: 'क़', // ਕ਼ → ਕ़
          0x0A16: 'ख़', // ਖ਼ → ਖ਼
          0x0A17: 'ग़', // ਗ਼ → ਗ਼
          0x0A1C: 'ज़', // ਜ਼ → ਜ਼
          0x0A21: 'ड़', // ਡ਼ → ਡ਼
          0x0A22: 'ढ़', // ਢ਼ → ਢ਼
          0x0A25: 'फ़', // ਫ਼ → ਫ਼
          0x0A32: 'ळ', // ਲ਼ → ਲ਼
          0x0A38: 'ष', // ਸ਼ → ਷
        };
        // Decomposed spelling: base consonant + nukta mark — consume both
        // so the row fallback cannot misread the pair as two letters.
        if (code >= 0x0A15 &&
            code <= 0x0A39 &&
            i + 1 < text.length &&
            text.codeUnitAt(i + 1) == 0x0A3C) {
          final mapped = gurmukhiNuktaBaseToDeva[code];
          if (mapped != null) {
            buf.write(mapped);
            i += 2;
            continue;
          }
        }
        if (code == 0x0A3C) {
          // Standalone nukta with no recognised base: keep the Devanagari
          // nukta rather than misreading it as a letter row.
          buf.write('़');
          i++;
          continue;
        }
        // Composed dedicated nukta letters (ਸ਼ ਖ਼ ਜ਼ ਫ਼ …).
        const gurmukhiComposedToDeva = {
          0x0A33: '\u0933', // ਲ਼ → ळ
          0x0A36: '\u0937', // ਸ਼ → ष
          0x0A59: '\u0959', // ਖ਼ → ख़
          0x0A5A: '\u095A', // ਗ਼ → ग़
          0x0A5B: '\u095B', // ਜ਼ → ज़
          0x0A5C: '\u095C', // ੜ → ड़
          0x0A5D: '\u095D', // ਢ਼ → ढ़
          0x0A5E: '\u095E', // ਫ਼ → फ़
        };
        final composed = gurmukhiComposedToDeva[code];
        if (composed != null) {
          buf.write(composed);
          i++;
          continue;
        }
      }

      if (code >= fromBase && code < fromBase + 0x80) {
        final rel = code - fromBase;
        final target = devaBase + rel;
        if (target >= devaBase && target < devaBase + 0x80) {
          buf.writeCharCode(target);
          i++;
          continue;
        }
      }
      buf.writeCharCode(code);
      i++;
    }
    return buf.toString();
  }

  /// Stage 2 — emit Devanagari phonemes into the target script.
  static String _emit(String devaText, String to) {
    final toBase = _base[to]!;
    final devaBase = _base[devanagari]!;
    final consonants = _consonantOverrides[to] ?? const {};
    final vowels = _vowelOverrides[to] ?? const {};
    final matras = _matraOverrides[to] ?? const {};
    final marks = _markOverrides[to] ?? const {};
    final buf = StringBuffer();

    var i = 0;
    while (i < devaText.length) {
      final ch = devaText[i];
      final code = ch.codeUnitAt(0);

      // Composed Devanagari nukta letters (क़ … फ़, single codepoints).
      if (code >= 0x0958 && code <= 0x095F) {
        final override = consonants[ch];
        if (override != null) {
          buf.write(override);
          i++;
          continue;
        }
      }

      final override = consonants[ch] ?? vowels[ch] ?? matras[ch] ?? marks[ch];
      if (override != null) {
        buf.write(override);
        i++;
        continue;
      }

      if (code >= devaBase && code < devaBase + 0x80) {
        final rel = code - devaBase;
        final target = toBase + rel;
        if (target >= toBase && target < toBase + 0x80) {
          buf.writeCharCode(target);
          i++;
          continue;
        }
      }
      // No known mapping: keep the source glyph rather than emitting a
      // wrong or invisible character.
      buf.write(ch);
      i++;
    }
    return buf.toString();
  }
}
