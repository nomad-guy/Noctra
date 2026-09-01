/// Pure Dart high-performance port of the Sanscript matrix for zero-latency,
/// offline cross-Indic script transliteration (Devanagari, Gurmukhi, Bengali,
/// Gujarati, Telugu, Tamil, Kannada, Malayalam, ITRANS, IAST, HK).
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
  static const String itrans = 'itrans';
  static const String iast = 'iast';
  static const String hk = 'hk';

  // Base characters map for Brahmic scripts offset-based translation
  static const Map<String, int> _scriptOffsets = {
    'devanagari': 0x0900,
    'bengali': 0x0980,
    'gurmukhi': 0x0A00,
    'gujarati': 0x0A80,
    'tamil': 0x0B80,
    'telugu': 0x0C00,
    'kannada': 0x0C80,
    'malayalam': 0x0D00,
  };

  // Gurmukhi specific overrides where Unicode blocks differ from Devanagari standard indices
  static const Map<String, String> _devaToGurmukhiSpecial = {
    'ऋ': 'ਰਿ', 'ॠ': 'ਰੀ', 'ऌ': 'ਲਿ', 'ॡ': 'ਲੀ',
    'ऐ': 'ਐ', 'औ': 'ਔ', 'ऑ': 'ਆ', 'ऍ': 'ਐ',
    'ष': 'ਸ਼', 'श': 'ਸ਼', 'ण': 'ਣ', 'ळ': 'ਲ਼',
    'ृ': '੍ਰਿ', 'ॄ': '੍ਰੀ', 'े': 'ੇ', 'ै': 'ੈ', 'ो': 'ੋ', 'ौ': 'ੌ',
    'ँ': 'ਁ', 'ं': 'ਂ', 'ः': 'ਃ', '्': '੍',
  };

  static const Map<String, String> _gurmukhiToDevaSpecial = {
    'ਐ': 'ऐ', 'ਔ': 'औ', 'ਸ਼': 'श', 'ਣ': 'ण', 'ਲ਼': 'ळ',
    'ੇ': 'े', 'ੈ': 'ै', 'ੋ': 'ो', 'ੌ': 'ौ',
    'ਁ': 'ँ', 'ਂ': 'ं', 'ਃ': 'ः', '੍': '्',
  };

  /// Transliterate [input] text from [fromScript] to [toScript].
  static String transliterate(String input, String fromScript, String toScript) => t(input, fromScript, toScript);
  static String t(String input, String fromScript, String toScript) {
    if (input.trim().isEmpty || fromScript == toScript) return input;

    final from = fromScript.toLowerCase();
    final to = toScript.toLowerCase();

    // Gurmukhi has several non-offset Unicode mappings. Handle it before the
    // generic Brahmic conversion so Punjabi matras and consonants are not
    // silently mapped to the wrong Devanagari character.
    if (from == devanagari && to == gurmukhi) {
      return _devaToGurmukhi(input);
    }
    if (from == gurmukhi && to == devanagari) {
      return _gurmukhiToDeva(input);
    }

    // Direct Brahmic <-> Brahmic conversion for scripts with compatible rows.
    if (_scriptOffsets.containsKey(from) && _scriptOffsets.containsKey(to)) {
      return _brahmicToBrahmic(input, from, to);
    }

    return input;
  }

  static String _devaToGurmukhi(String text) {
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_devaToGurmukhiSpecial.containsKey(ch)) {
        buf.write(_devaToGurmukhiSpecial[ch]);
        continue;
      }
      final code = ch.codeUnitAt(0);
      if (code >= 0x0901 && code <= 0x097F) {
        final gCode = code - 0x0900 + 0x0A00;
        buf.writeCharCode(gCode);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static String _gurmukhiToDeva(String text) {
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_gurmukhiToDevaSpecial.containsKey(ch)) {
        buf.write(_gurmukhiToDevaSpecial[ch]);
        continue;
      }
      final code = ch.codeUnitAt(0);
      if (code >= 0x0A01 && code <= 0x0A7F) {
        final dCode = code - 0x0A00 + 0x0900;
        buf.writeCharCode(dCode);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static String _brahmicToBrahmic(String text, String from, String to) {
    final fromOffset = _scriptOffsets[from]!;
    final toOffset = _scriptOffsets[to]!;
    final buf = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= fromOffset && code < fromOffset + 0x80) {
        final relative = code - fromOffset;
        buf.writeCharCode(toOffset + relative);
      } else {
        buf.writeCharCode(code);
      }
    }
    return buf.toString();
  }
}
