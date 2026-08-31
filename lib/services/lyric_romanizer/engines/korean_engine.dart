/// Korean Hangul romanization engine.
///
/// Pure-Dart implementation using Hangul Jamo decomposition
/// with Revised Romanization of Korean tables.

library;
import '../lyric_romanizer_types.dart';

class KoreanRomanizer {
  const KoreanRomanizer();

  static const List<String> _choseong = [
    'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp',
    's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'
  ];

  static const List<String> _jungseong = [
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o',
    'wa', 'wae', 'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu',
    'eu', 'ui', 'i'
  ];

  static const List<String> _jongseong = [
    '', 'k', 'k', 'ks', 'n', 'nj', 'nh', 't', 'l', 'lk',
    'lm', 'lb', 'ls', 'lt', 'lp', 'lh', 'm', 'p', 'ps', 't',
    't', 'ng', 't', 't', 'k', 't', 'p', 'h'
  ];

  Future<String> romanize(String line, RomanizeEngineContext context) async {
    final buf = StringBuffer();
    for (final rune in line.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final code = rune - 0xAC00;
        final cho = code ~/ (21 * 28);
        final jung = (code % (21 * 28)) ~/ 28;
        final jong = code % 28;
        buf.write(_choseong[cho]);
        buf.write(_jungseong[jung]);
        buf.write(_jongseong[jong]);
      } else {
        buf.write(String.fromCharCode(rune));
      }
    }
    return buf.toString();
  }
}
