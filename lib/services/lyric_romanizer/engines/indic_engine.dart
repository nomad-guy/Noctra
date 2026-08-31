/// Indic script romanization engine using Sanscript tables.
///
/// Covers Devanagari, Gujarati, Telugu, Kannada, and Odia
/// via Unicode block offsets and Brahmic script consonant/vowel tables.

library;
import '../lyric_romanizer_types.dart';

class IndicRomanizer {
  const IndicRomanizer();

  /// Romanize [line] which belongs to the given [script].
  Future<String> romanizeScript(String line, ScriptType script, RomanizeEngineContext context) async {
    return romanize(line, script);
  }

  /// Base code point for each Brahmic script.
  static const Map<ScriptType, int> _offsets = {
    ScriptType.devanagari: 0x0900,
    ScriptType.bengali: 0x0980,
    ScriptType.gujarati: 0x0A80,
    ScriptType.tamil: 0x0B80,
    ScriptType.telugu: 0x0C00,
    ScriptType.kannada: 0x0C80,
    ScriptType.malayalam: 0x0D00,
  };

  /// Independent vowels (Unicode positions relative to base offset).
  static const Map<int, String> _vowelMap = {
    0x05: 'a', 0x06: 'aa', 0x07: 'i', 0x08: 'ii',
    0x09: 'u', 0x0A: 'uu', 0x0B: 'ri', 0x0C: 'e',
    0x0D: 'ai', 0x0E: 'o', 0x0F: 'au',
  };

  /// Consonant positions relative to base offset (ka through ha).
  static const Map<int, String> _consonantMap = {
    0x15: 'ka', 0x16: 'kha', 0x17: 'ga', 0x18: 'gha', 0x19: 'nga',
    0x1A: 'cha', 0x1B: 'chha', 0x1C: 'ja', 0x1D: 'jha', 0x1E: 'nya',
    0x1F: 'ta', 0x20: 'tha', 0x21: 'da', 0x22: 'dha', 0x23: 'na',
    0x24: 'ta', 0x25: 'tha', 0x26: 'da', 0x27: 'dha', 0x28: 'na',
    0x2A: 'pa', 0x2B: 'pha', 0x2C: 'ba', 0x2D: 'bha', 0x2E: 'ma',
    0x2F: 'ya', 0x30: 'ra', 0x31: 'la', 0x32: 'va', 0x33: 'sha',
    0x34: 'sha', 0x35: 'sa', 0x36: 'ha',
  };

  /// Vowel signs (matras) relative to base offset.
  static const Map<int, String> _matraMap = {
    0x3E: 'aa', 0x3F: 'i', 0x40: 'ii', 0x41: 'u', 0x42: 'uu',
    0x43: 'ri', 0x47: 'e', 0x48: 'ai', 0x4B: 'o', 0x4C: 'au',
  };

  /// Anusvara / Chandrabindu / Virama positions.
  static const int _anusvara = 0x02;
  static const int _chandrabindu = 0x01;
  static const int _virama = 0x4D;

  Future<String> romanize(String line, ScriptType script) async {
    final buf = StringBuffer();
    final offset = _offsets[script] ?? 0x0900;
    bool consonantPending = false;

    for (int i = 0; i < line.length; i++) {
      final cp = line.codeUnitAt(i);
      final rel = cp - offset;

      // Virama (halant) — suppress inherent vowel
      if (rel == _virama) {
        consonantPending = false;
        continue;
      }

      // Anusvara
      if (rel == _anusvara) {
        buf.write(consonantPending ? '' : 'm');
        consonantPending = false;
        continue;
      }

      // Chandrabindu
      if (rel == _chandrabindu) {
        buf.write('m');
        consonantPending = false;
        continue;
      }

      // Independent vowel
      if (_vowelMap.containsKey(rel)) {
        buf.write(_vowelMap[rel]);
        consonantPending = false;
        continue;
      }

      // Vowel sign (matra)
      if (_matraMap.containsKey(rel)) {
        buf.write(_matraMap[rel]);
        consonantPending = false;
        continue;
      }

      // Consonant
      if (_consonantMap.containsKey(rel)) {
        if (consonantPending) buf.write('a'); // inherent vowel
        buf.write(_consonantMap[rel]);
        consonantPending = true;
        continue;
      }

      // Non-Brahmic character — pass through
      if (consonantPending) {
        buf.write('a');
        consonantPending = false;
      }
      buf.write(String.fromCharCode(cp));
    }

    if (consonantPending) buf.write('a');
    return buf.toString();
  }
}
