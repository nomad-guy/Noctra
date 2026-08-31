/// Tamil to Latin romanization engine.
///
/// Character-mapping romanizer for Tamil script (U+0B80–U+0BFF).

library;
import '../lyric_romanizer_types.dart';

class TamilRomanizer {
  const TamilRomanizer();

  static const Map<String, String> _vowels = {
    'அ': 'a', 'ஆ': 'aa', 'இ': 'i', 'ஈ': 'ee', 'உ': 'u',
    'ஊ': 'uu', 'எ': 'e', 'ஏ': 'ee', 'ஐ': 'ai', 'ஒ': 'o',
    'ஓ': 'oo', 'ஔ': 'au',
  };

  static const Map<String, String> _vowelSigns = {
    'ா': 'aa', 'ி': 'i', 'ீ': 'ee', 'ு': 'u', 'ூ': 'uu',
    'ெ': 'e', 'ே': 'ee', 'ை': 'ai', 'ொ': 'o', 'ோ': 'oo', 'ௌ': 'au',
  };

  static const Map<String, String> _consonants = {
    'க': 'ka', 'ங': 'nga', 'ச': 'sa', 'ஞ': 'nya', 'ட': 'da',
    'ண': 'na', 'த': 'tha', 'ந': 'na', 'ப': 'ba', 'ம': 'ma',
    'ய': 'ya', 'ர': 'ra', 'ல': 'la', 'வ': 'va', 'ழ': 'zha',
    'ள': 'la', 'ற': 'ra', 'ன': 'na',
  };

  Future<String> romanize(String line, RomanizeEngineContext context) async {
    final buf = StringBuffer();
    for (final ch in line.split('')) {
      if (_vowels.containsKey(ch)) {
        buf.write(_vowels[ch]);
      } else if (_consonants.containsKey(ch)) {
        buf.write(_consonants[ch]);
      } else if (_vowelSigns.containsKey(ch)) {
        buf.write(_vowelSigns[ch]);
      } else if (ch == '்') {
        // virama — no output, suppresses inherent 'a'
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }
}
