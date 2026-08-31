import 'package:http/http.dart' as http;
import 'sanscript_engine.dart';
import '../../core/utils/noctra_logger.dart';

/// AksharamukhaService: Script conversion engine supporting 120+ scripts
/// with full orthographic conventions (Devanagari, Gurmukhi, Roman/IAST, Bengali, etc.).
class AksharamukhaService {
  AksharamukhaService._();

  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 250;
  static const String _endpoint = 'https://aksharamukha-plugin.appspot.com/api/public';

  /// Converts [text] from [sourceScript] to [targetScript].
  /// Uses offline [SanscriptEngine] as immediate baseline and falls back gracefully.
  static Future<String> convert(
    String text, {
    required String sourceScript,
    required String targetScript,
  }) async {
    if (text.trim().isEmpty || sourceScript.toLowerCase() == targetScript.toLowerCase()) {
      return text;
    }

    final cacheKey = '$sourceScript:$targetScript:${text.trim()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Try online Aksharamukha API for precise orthographic nuance
    try {
      final uri = Uri.parse('$_endpoint?source=$sourceScript&target=$targetScript&text=${Uri.encodeComponent(text)}');
      final resp = await http.get(uri).timeout(const Duration(milliseconds: 1800));
      if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
        final result = resp.body.trim();
        _saveToCache(cacheKey, result);
        return result;
      }
    } catch (e) {
      NoctraLogger.d('Aksharamukha API fallback to local SanscriptEngine: $e');
    }

    // High-speed zero-latency local fallback
    final localResult = SanscriptEngine.t(text, sourceScript, targetScript);
    _saveToCache(cacheKey, localResult);
    return localResult;
  }

  static void _saveToCache(String key, String value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}
