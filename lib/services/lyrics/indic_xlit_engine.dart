import 'devanagari_transliteration_service.dart';
import 'aksharamukha_service.dart';
import 'sanscript_engine.dart';
import 'lyrics_service.dart';

/// IndicXlitEngine: Neural and algorithmic Roman <-> Native Indic transliteration engine
/// inspired by AI4Bharat IndicXlit and Aksharamukha.
class IndicXlitEngine {
  IndicXlitEngine._();

  static final Map<String, String> _xlitCache = {};
  static const int _maxCache = 300;

  /// Transliterates Romanized [text] to target script ([targetLang]: 'hi' (Hindi/Devanagari), etc.)
  static Future<String> transliterate(
    String text, {
    String sourceLang = 'en',
    String targetLang = 'hi',
  }) async {
    if (text.trim().isEmpty) return text;
    final cacheKey = '$sourceLang:$targetLang:${text.trim()}';
    if (_xlitCache.containsKey(cacheKey)) {
      return _xlitCache[cacheKey]!;
    }

    // 1. Primary on-device high-speed Devanagari transliteration
    final devanagariText = DevanagariTransliterationService.toDevanagari(text);

    // 2. If target is Bengali
    if (targetLang == 'bn' || targetLang == 'bengali') {
      final bengali = await AksharamukhaService.convert(
        devanagariText,
        sourceScript: SanscriptEngine.devanagari,
        targetScript: SanscriptEngine.bengali,
      );
      _putCache(cacheKey, bengali);
      return bengali;
    }

    // 4. Default Devanagari output
    _putCache(cacheKey, devanagariText);
    return devanagariText;
  }

  /// Transliterates an entire [LyricsData] payload across Roman or Devanagari.
  static Future<LyricsData> transliterateLyrics(
    LyricsData data, {
    required String targetScript,
  }) async {
    final cleanTarget = targetScript.toLowerCase();
    final newLines = <LyricLine>[];

    for (final line in data.lines) {
      final converted = await transliterate(line.text, targetLang: cleanTarget);
      newLines.add(LyricLine(timestamp: line.timestamp, text: converted));
    }

    final newPlain = data.lines.isNotEmpty
        ? newLines.map((l) => l.text).join('\n')
        : await transliterate(data.plainText, targetLang: cleanTarget);

    return LyricsData(isSynced: data.isSynced, lines: newLines, plainText: newPlain);
  }

  static void _putCache(String key, String value) {
    if (_xlitCache.length >= _maxCache) {
      _xlitCache.remove(_xlitCache.keys.first);
    }
    _xlitCache[key] = value;
  }
}
