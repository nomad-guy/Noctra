/// Thai to Latin romanization engine.
///
/// Uses a character-mapping approach based on RTGS
/// (Royal Thai General System of Transcription).

library;
import '../lyric_romanizer_types.dart';

class ThaiRomanizer {
  const ThaiRomanizer();

  static const Map<String, String> _consonants = {
    'ก': 'k', 'ข': 'kh', 'ค': 'kh', 'ง': 'ng', 'จ': 'ch', 'ฉ': 'ch',
    'ช': 'ch', 'ซ': 's', 'ด': 'd', 'ต': 't', 'ถ': 'th', 'ท': 'th',
    'น': 'n', 'บ': 'b', 'ป': 'p', 'ผ': 'ph', 'ฝ': 'f', 'พ': 'ph',
    'ฟ': 'f', 'ม': 'm', 'ย': 'y', 'ร': 'r', 'ล': 'l', 'ว': 'w',
    'ส': 's', 'ห': 'h', 'อ': '', 'ฮ': 'h',
  };

  static const Map<String, String> _vowels = {
    'ะ': 'a', 'า': 'a', 'ิ': 'i', 'ี': 'i', 'ึ': 'ue', 'ื': 'ue',
    'ุ': 'u', 'ู': 'u', 'เ': 'e', 'แ': 'ae', 'โ': 'o', 'ใ': 'ai',
    'ไ': 'ai', 'ๅ': 'aa',
  };

  static const Map<String, String> _tones = {
    '่': '', '้': '', '๊': '', '๋': '',
  };

  static const Map<String, String> _combining = {
    'ำ': 'am', 'ๅ': 'aa',
  };

  Future<String> romanize(String line, RomanizeEngineContext context) async {
    final buf = StringBuffer();
    int i = 0;
    while (i < line.length) {
      final ch = line[i];
      if (_combining.containsKey(ch)) {
        buf.write(_combining[ch]);
        i++;
        continue;
      }
      if (_consonants.containsKey(ch)) {
        buf.write(_consonants[ch]);
        i++;
        continue;
      }
      if (_vowels.containsKey(ch)) {
        buf.write(_vowels[ch]);
        i++;
        continue;
      }
      if (_tones.containsKey(ch)) {
        // Tone marks are silent in RTGS
        i++;
        continue;
      }
      buf.write(ch);
      i++;
    }
    return buf.toString();
  }
}
