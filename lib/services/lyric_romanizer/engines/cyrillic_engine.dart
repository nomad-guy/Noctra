/// Cyrillic to Latin romanization engine.
///
/// Auto-detects Ukrainian vs Russian per line using the presence of
/// Ukrainian-specific characters (і, ї, є, ґ).

library;
import '../lyric_romanizer_types.dart';

class CyrillicRomanizer {
  const CyrillicRomanizer();

  /// Ukrainian-specific characters that trigger the Ukrainian preset.
  static final RegExp _ukrainePresetRe = RegExp(r'[іїєґ]', caseSensitive: false);

  /// Detects whether the line contains Ukrainian-specific characters.
  static String selectPreset(String line) =>
      _ukrainePresetRe.hasMatch(line) ? 'uk' : 'ru';

  static const Map<String, String> _ruMap = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e',
    'ё': 'yo', 'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k',
    'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
    'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
    'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '',
    'э': 'e', 'ю': 'yu', 'я': 'ya',
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E',
    'Ё': 'Yo', 'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K',
    'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R',
    'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts',
    'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch', 'Ъ': '', 'Ы': 'Y', 'Ь': '',
    'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
  };

  static const Map<String, String> _ukMap = {
    'і': 'i', 'ї': 'yi', 'є': 'ye', 'ґ': 'g',
    // Ukrainian и maps to 'y' (differs from Russian и → 'i')
    'и': 'y', 'И': 'Y',
    'І': 'I', 'Ї': 'Yi', 'Є': 'Ye', 'Ґ': 'G',
  };

  Future<String> romanize(String line, RomanizeEngineContext context) async {
    final preset = selectPreset(line);
    final buf = StringBuffer();
    for (final ch in line.split('')) {
      if (preset == 'uk' && _ukMap.containsKey(ch)) {
        buf.write(_ukMap[ch]);
      } else {
        buf.write(_ruMap[ch] ?? ch);
      }
    }
    return buf.toString();
  }
}
