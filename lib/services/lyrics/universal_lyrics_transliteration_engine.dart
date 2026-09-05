import 'devanagari_transliteration_service.dart';
import 'lyrics_service.dart';
import 'romanized_translation_engine.dart';
import 'sanscript_engine.dart';
import 'scripts/asian_script_transliterator.dart';
import 'scripts/lyric_script_detector.dart';
import 'scripts/mideast_and_european_transliterator.dart';

export 'scripts/lyric_script_detector.dart';

class UniversalLyricsTransliterationEngine {
  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 3000;
  static int _lexiconVersion = 0;
  static final RomanizedTranslationEngine _romanizer =
      RomanizedTranslationEngine();

  static void invalidateCache() {
    _lexiconVersion++;
    _cache.clear();
  }

  static LyricScript detectScript(String text) =>
      LyricScriptDetector.detectScript(text);

  static List<ScriptOption> getAvailableScriptOptions(LyricsData data) =>
      LyricScriptDetector.getAvailableScriptOptions(data);

  static LyricsData transliterateLyrics(
      LyricsData lyrics, String targetScript) {
    if (targetScript == 'original' || targetScript == 'raw') return lyrics;

    final cacheKeyPrefix = 'v$_lexiconVersion:$targetScript:';
    if (lyrics.isSynced) {
      final convertedLines = lyrics.lines.map((line) {
        final cacheKey = '$cacheKeyPrefix${line.text}';
        if (_cache.containsKey(cacheKey)) {
          return LyricLine(
              timestamp: line.timestamp, text: _cache[cacheKey]!);
        }
        final converted = transliterateText(line.text, targetScript);
        if (_cache.length >= _maxCacheSize) _cache.remove(_cache.keys.first);
        _cache[cacheKey] = converted;
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

  static String transliterateText(String input, String targetScript) {
    if (input.trim().isEmpty) return input;
    final clean = input.trim();
    final sourceScript = detectScript(clean);

    String romanText;
    switch (sourceScript) {
      case LyricScript.japanese:
        romanText = AsianScriptTransliterator.japaneseToRomaji(clean);
        break;
      case LyricScript.korean:
        romanText = AsianScriptTransliterator.koreanHangulToRoman(clean);
        break;
      case LyricScript.chinese:
        romanText = AsianScriptTransliterator.chineseToPinyin(clean);
        break;
      case LyricScript.cyrillic:
        romanText = MideastAndEuropeanTransliterator.cyrillicToLatin(clean);
        break;
      case LyricScript.arabic:
        romanText = MideastAndEuropeanTransliterator.arabicToLatin(clean);
        break;
      case LyricScript.greek:
        romanText = MideastAndEuropeanTransliterator.greekToLatin(clean);
        break;
      case LyricScript.thai:
        romanText = MideastAndEuropeanTransliterator.thaiToLatin(clean);
        break;
      case LyricScript.hebrew:
        romanText = MideastAndEuropeanTransliterator.hebrewToLatin(clean);
        break;
      case LyricScript.devanagari:
        romanText = _romanizer.toRomanized(clean);
        break;
      case LyricScript.gurmukhi:
        romanText = MideastAndEuropeanTransliterator.gurmukhiToRoman(clean);
        break;
      case LyricScript.bengali:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.bengali, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.gujarati:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.gujarati, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.telugu:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.telugu, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.tamil:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.tamil, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.kannada:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.kannada, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.malayalam:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.malayalam, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.odia:
        final deva = SanscriptEngine.t(
            clean, SanscriptEngine.odia, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.latin:
        romanText = clean;
        break;
    }

    if (targetScript == 'roman' ||
        targetScript == 'english' ||
        targetScript == 'romaji' ||
        targetScript == 'pinyin') {
      return romanText;
    }

    if (targetScript == 'devanagari') {
      if (sourceScript == LyricScript.devanagari) return clean;
      if (sourceScript == LyricScript.bengali) {
        return SanscriptEngine.t(
            clean, SanscriptEngine.bengali, SanscriptEngine.devanagari);
      }
      if (sourceScript == LyricScript.gurmukhi) {
        return SanscriptEngine.t(
            clean, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari);
      }
      return DevanagariTransliterationService.toDevanagari(romanText);
    }

    return romanText;
  }
}
