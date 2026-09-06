import 'akshara_engine.dart';
import 'sanscript_engine.dart';

/// AksharamukhaService: Fully offline, zero-latency script conversion engine
/// backed by [AksharaEngine] canonical phonetic matrix and [SanscriptEngine].
class AksharamukhaService {
  AksharamukhaService._();

  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 500;

  /// Converts [text] from [sourceScript] to [targetScript] with zero network latency.
  static Future<String> convert(
    String text, {
    required String sourceScript,
    required String targetScript,
  }) async {
    return convertSync(text,
        sourceScript: sourceScript, targetScript: targetScript);
  }

  /// Synchronous zero-allocation conversion suitable for real-time 60fps lyric rendering.
  static String convertSync(
    String text, {
    required String sourceScript,
    required String targetScript,
  }) {
    if (text.trim().isEmpty ||
        sourceScript.toLowerCase() == targetScript.toLowerCase()) {
      return text;
    }

    final cacheKey = '$sourceScript:$targetScript:${text.trim()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    String result;
    if (AksharaEngine.instance.supports(sourceScript) &&
        AksharaEngine.instance.supports(targetScript)) {
      result = AksharaEngine.instance
          .convert(text, from: sourceScript, to: targetScript);
    } else {
      result = SanscriptEngine.t(text, sourceScript, targetScript);
    }

    _saveToCache(cacheKey, result);
    return result;
  }

  static void _saveToCache(String key, String value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}
