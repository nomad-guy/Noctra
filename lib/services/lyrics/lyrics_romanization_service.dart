import '../lyric_romanizer/lyric_romanizer_detector.dart' as lr;
import '../lyric_romanizer/lyric_romanizer_types.dart' as lr;
import 'devanagari_transliteration_service.dart';
import 'lyrics_service.dart';
import 'romanized_translation_engine.dart';
import 'sanscript_engine.dart';

part 'parts/lyrics_romanization_maps.dart';

/// Script type enum (matches old LyricScript for UI compatibility).
enum ScriptType {
  latin,
  japanese,
  korean,
  chinese,
  cyrillic,
  arabic,
  greek,
  thai,
  hebrew,
  devanagari,
  gurmukhi,
  bengali,
  tamil,
  telugu,
  gujarati,
  kannada,
  malayalam,
  odia,
  other,
}

class ScriptOption {
  final String code;
  final String label;
  const ScriptOption({required this.code, required this.label});
}

/// Cached lyrics romanization service using the lyric_romanizer detector.
class LyricsRomanizationService {
  LyricsRomanizationService._();

  static final Map<String, String> _cache = {};
  static const int _maxCache = 500;
  static final _devaToRomanEngine = RomanizedTranslationEngine();

  static void _put(String key, String value) {
    if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
    _cache[key] = value;
  }

  static ScriptType _map(lr.ScriptType s) => switch (s) {
        lr.ScriptType.japanese => ScriptType.japanese,
        lr.ScriptType.chinese => ScriptType.chinese,
        lr.ScriptType.korean => ScriptType.korean,
        lr.ScriptType.cyrillic => ScriptType.cyrillic,
        lr.ScriptType.devanagari => ScriptType.devanagari,
        lr.ScriptType.gurmukhi => ScriptType.gurmukhi,
        lr.ScriptType.gujarati => ScriptType.gujarati,
        lr.ScriptType.telugu => ScriptType.telugu,
        lr.ScriptType.kannada => ScriptType.kannada,
        lr.ScriptType.odia => ScriptType.odia,
        lr.ScriptType.tamil => ScriptType.tamil,
        lr.ScriptType.malayalam => ScriptType.malayalam,
        lr.ScriptType.bengali => ScriptType.bengali,
        lr.ScriptType.arabic => ScriptType.arabic,
        lr.ScriptType.hebrew => ScriptType.hebrew,
        lr.ScriptType.thai => ScriptType.thai,
        lr.ScriptType.latin => ScriptType.latin,
        lr.ScriptType.other => ScriptType.other,
      };

  /// Detect the dominant script in lyrics text.
  static ScriptType detectScript(String text) {
    if (text.trim().isEmpty) return ScriptType.latin;
    return _map(lr.detectScript([text]));
  }

  /// Get available script options for the given lyrics data.
  static List<ScriptOption> getAvailableScriptOptions(LyricsData data) {
    final sample = data.lines.isNotEmpty
        ? data.lines.map((l) => l.text).take(10).join(' ')
        : data.plainText;
    final script = detectScript(sample);

    return switch (script) {
      ScriptType.japanese => const [
          ScriptOption(code: 'original', label: 'Original (日本語)'),
          ScriptOption(code: 'roman', label: 'Romaji (Latin)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
      ScriptType.korean => const [
          ScriptOption(code: 'original', label: 'Original (한국어)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
      ScriptType.chinese => const [
          ScriptOption(code: 'original', label: 'Original (中文)'),
          ScriptOption(code: 'roman', label: 'Pinyin'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
      ScriptType.cyrillic => const [
          ScriptOption(code: 'original', label: 'Original (Русский)'),
          ScriptOption(code: 'roman', label: 'Romanized (Latin)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
      ScriptType.arabic => const [
          ScriptOption(code: 'original', label: 'Original (العربية)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
      ScriptType.greek => const [
          ScriptOption(code: 'original', label: 'Original (Ελληνικά)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ],
      ScriptType.thai => const [
          ScriptOption(code: 'original', label: 'Original (ไทย)'),
          ScriptOption(code: 'roman', label: 'Romanized (RTGS)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ],
      ScriptType.hebrew => const [
          ScriptOption(code: 'original', label: 'Original (עברית)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ],
      ScriptType.devanagari => const [
          ScriptOption(code: 'original', label: 'मूल (देवनागरी)'),
          ScriptOption(code: 'roman', label: 'Roman (English)'),
        ],
      ScriptType.latin || ScriptType.other => const [
          ScriptOption(code: 'original', label: 'Original (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
      _ => const [
          ScriptOption(code: 'original', label: 'Original Script'),
          ScriptOption(code: 'roman', label: 'Romanized (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ],
    };
  }

  /// Transliterate full lyrics to the target script (cached).
  static LyricsData transliterateLyrics(
      LyricsData lyrics, String targetScript) {
    if (targetScript == 'original' || targetScript == 'raw') return lyrics;

    if (lyrics.isSynced && lyrics.lines.isNotEmpty) {
      final convertedLines = lyrics.lines.map((line) {
        final cacheKey = '$targetScript:${line.text}';
        final cached = _cache[cacheKey];
        if (cached != null) {
          return LyricLine(timestamp: line.timestamp, text: cached);
        }
        final converted = transliterateText(line.text, targetScript);
        _put(cacheKey, converted);
        return LyricLine(timestamp: line.timestamp, text: converted);
      }).toList();

      return LyricsData(
        plainText: convertedLines.map((l) => l.text).join('\n'),
        lines: convertedLines,
        isSynced: true,
      );
    } else {
      final convertedText = transliterateText(lyrics.plainText, targetScript);
      return LyricsData(
        plainText: convertedText,
        lines: const [],
        isSynced: false,
      );
    }
  }

  /// Transliterate a single line to the target script.
  static String transliterateText(String input, String targetScript) {
    if (input.trim().isEmpty) return input;
    final sourceScript = detectScript(input);

    final romanText = _toRoman(input, sourceScript);

    if (targetScript == 'roman' ||
        targetScript == 'english' ||
        targetScript == 'romaji' ||
        targetScript == 'pinyin') {
      return romanText;
    }

    if (targetScript == 'devanagari') {
      if (sourceScript == ScriptType.devanagari) return input;
      return DevanagariTransliterationService.toDevanagari(romanText);
    }

    return romanText;
  }

  static String _toRoman(String text, ScriptType source) => switch (source) {
        ScriptType.devanagari => _devaToRomanEngine.toRomanized(text),
        ScriptType.bengali => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.bengali, SanscriptEngine.devanagari)),
        ScriptType.gujarati => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.gujarati, SanscriptEngine.devanagari)),
        ScriptType.telugu => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.telugu, SanscriptEngine.devanagari)),
        ScriptType.tamil => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.tamil, SanscriptEngine.devanagari)),
        ScriptType.kannada => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.kannada, SanscriptEngine.devanagari)),
        ScriptType.malayalam => _devaToRomanEngine.toRomanized(
            SanscriptEngine.t(
                text, SanscriptEngine.malayalam, SanscriptEngine.devanagari)),
        ScriptType.gurmukhi => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari)),
        ScriptType.odia => _devaToRomanEngine.toRomanized(SanscriptEngine.t(
            text, SanscriptEngine.odia, SanscriptEngine.devanagari)),
        ScriptType.japanese => _japaneseToRomaji(text),
        ScriptType.korean => _koreanToRoman(text),
        ScriptType.chinese => _chineseToPinyin(text),
        ScriptType.cyrillic =>
          _mapChars(text, LyricsRomanizationMaps.cyrillicMap),
        ScriptType.arabic =>
          _mapChars(text, LyricsRomanizationMaps.arabicMap),
        ScriptType.greek =>
          _mapChars(text, LyricsRomanizationMaps.greekMap),
        ScriptType.thai =>
          _mapChars(text, LyricsRomanizationMaps.thaiMap),
        ScriptType.hebrew =>
          _mapChars(text, LyricsRomanizationMaps.hebrewMap),
        ScriptType.latin || ScriptType.other => text,
      };

  static String _mapChars(String text, Map<String, String> map) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static String _japaneseToRomaji(String text) {
    String p = text
        .replaceAll('こんにちは', 'konnichiwa')
        .replaceAll('こんばんは', 'konbanwa')
        .replaceAll('コンニチハ', 'konnichiwa')
        .replaceAll('コンバンハ', 'konbanwa');
    final sb = StringBuffer();
    int i = 0;
    while (i < p.length) {
      if (i + 1 < p.length) {
        final pair = p.substring(i, i + 2);
        final dig = LyricsRomanizationMaps.jpDigraphs[pair];
        if (dig != null) {
          sb.write(dig);
          i += 2;
          continue;
        }
      }
      final ch = p[i];
      if ((ch == 'っ' || ch == 'ッ') && i + 1 < p.length) {
        final nr = LyricsRomanizationMaps.jpMono[p[i + 1]] ?? '';
        if (nr.isNotEmpty) sb.write(nr[0]);
        i++;
        continue;
      }
      sb.write(LyricsRomanizationMaps.jpMono[ch] ?? ch);
      i++;
    }
    return sb.toString();
  }

  static String _koreanToRoman(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final c = rune - 0xAC00;
        sb.write(LyricsRomanizationMaps.cho[c ~/ (21 * 28)]);
        sb.write(LyricsRomanizationMaps.jung[(c % (21 * 28)) ~/ 28]);
        sb.write(LyricsRomanizationMaps.jong[c % 28]);
      } else {
        sb.write(String.fromCharCode(rune));
      }
    }
    return sb.toString();
  }

  static String _chineseToPinyin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write('${LyricsRomanizationMaps.py[ch] ?? ch} ');
    }
    return sb.toString().trim();
  }
}
