/// Port of lyric-romanizer/src/romanizer.ts
///
/// Core romanizer orchestrator. Provides the [createRomanizer] factory
/// that returns a [Romanizer] with lazy-loaded engines, pluggable engine
/// injection, universal-fallback transliteration, and warmup support.

library;
import 'lyric_romanizer_types.dart';
import 'lyric_romanizer_detector.dart';
import 'engines/japanese_engine.dart';
import 'engines/chinese_engine.dart';
import 'engines/korean_engine.dart';
import 'engines/cyrillic_engine.dart';
import 'engines/thai_engine.dart';
import 'engines/tamil_engine.dart';
import 'engines/indic_engine.dart';
import 'engines/universal_fallback.dart';

final _asciiLetterRe = RegExp(r'[A-Za-z]');
final _hasLetterRe = RegExp(r'\p{L}', unicode: true);

/// Selects the Cyrillic transliteration preset per line.
///
/// Ukrainian-specific characters (і, ї, є, ґ) pick the Ukrainian preset;
/// all other Cyrillic romanizes as Russian.
String selectCyrillicPreset(String line) {
  return RegExp(r'[іїєґ]', caseSensitive: false).hasMatch(line) ? 'uk' : 'ru';
}

/// Creates a [Romanizer] instance with the given options.
///
/// Every engine is lazily loaded on first use and cached. Failed loads
/// clear the cache so the next call retries.
///
/// ```dart
/// final romanizer = createRomanizer();
/// final result = await romanizer.romanizeLines(['你好世界']);
/// ```
Romanizer createRomanizer([RomanizerOptions? options]) {
  return _DefaultRomanizer(options);
}

class _DefaultRomanizer implements Romanizer {
  final Map<ScriptType, RomanizeEngine> _engines;
  final Map<ScriptType, RomanizeEngine> _defaultEngines;

  _DefaultRomanizer(RomanizerOptions? options)
      : _defaultEngines = _buildDefaultEngines(),
        _engines = {} {
    // Start with default engines
    _engines.addAll(_defaultEngines);
    // Apply user overrides
    if (options?.engines != null) {
      for (final entry in options!.engines!.entries) {
        if (entry.value != null) {
          _engines[entry.key] = entry.value!;
        }
      }
    }
  }

  @override
  Future<void> warmup([List<ScriptType>? scripts]) async {
    final requested = scripts ?? _defaultEngines.keys.toList();
    for (final script in requested) {
      if (_engines[script] != _defaultEngines[script]) continue;
      // Pure Dart engines — no async init needed. Placeholder for
      // when native libs (kuroshiro/kuromoji) are injected.
    }
  }

  @override
  Future<String> romanizeLine(String line,
      {RomanizeOptions? options}) async {
    final result = await _resolveLine(line, options?.script, options);
    return result.text;
  }

  @override
  Future<RomanizeResult> romanizeLines(
    List<String> lines, {
    RomanizeOptions? options,
  }) async {
    final script = options?.script ?? detectScript(lines);

    if (script != ScriptType.latin && !_engines.containsKey(script)) {
      throw UnsupportedRomanizationError(script);
    }
    if (script == ScriptType.latin) {
      return RomanizeResult(
        script: script,
        lines: List<String>.from(lines),
        fallbacks: List<bool>.filled(lines.length, false),
      );
    }

    final resolved = await Future.wait(
      lines.map((line) => _resolveLine(line, script, options)),
    );
    return RomanizeResult(
      script: script,
      lines: resolved.map((r) => r.text).toList(),
      fallbacks: resolved.map((r) => r.fallback).toList(),
    );
  }

  Future<_ResolvedLine> _resolveLine(
    String line,
    ScriptType? script,
    RomanizeOptions? options,
  ) async {
    if (line.trim().isEmpty || !_hasLetterRe.hasMatch(line)) {
      return _ResolvedLine(text: line, fallback: false);
    }

    final resolved = script ?? detectScript([line]);
    if (resolved == ScriptType.latin) {
      return _ResolvedLine(text: line, fallback: false);
    }

    // Check engine existence before latin guard
    final engine = _engines[resolved];
    if (engine == null) {
      throw UnsupportedRomanizationError(resolved);
    }

    // Latin guard: pure ASCII letters with no non-Latin chars → no-op
    if (_asciiLetterRe.hasMatch(line) && !nonLatinScriptRegex.hasMatch(line)) {
      return _ResolvedLine(text: line, fallback: false);
    }

    final context = RomanizeEngineContext(
      dialect: options?.dialect ?? ChineseDialect.mandarin,
    );

    try {
      final text = await engine(line, context);
      return _ResolvedLine(text: text, fallback: false);
    } catch (_) {
      // Universal-fallback: degrade to transliteration
      try {
        final text = UniversalFallbackEngine.transliterate(line);
        return _ResolvedLine(text: text, fallback: true);
      } catch (_) {
        return _ResolvedLine(text: line, fallback: true);
      }
    }
  }

  static Map<ScriptType, RomanizeEngine> _buildDefaultEngines() {
    final japanese = JapaneseRomanizer();
    final chinese = ChineseRomanizer();
    final korean = KoreanRomanizer();
    final cyrillic = CyrillicRomanizer();
    final thai = ThaiRomanizer();
    final tamil = TamilRomanizer();
    final indic = IndicRomanizer();

    return {
      ScriptType.japanese: (line, ctx) => japanese.romanize(line, ctx),
      ScriptType.chinese: (line, ctx) => chinese.romanize(line, ctx),
      ScriptType.korean: (line, ctx) => korean.romanize(line, ctx),
      ScriptType.cyrillic: (line, ctx) => cyrillic.romanize(line, ctx),
      ScriptType.devanagari: (line, ctx) => indic.romanize(line, ScriptType.devanagari),
      ScriptType.gujarati: (line, ctx) => indic.romanize(line, ScriptType.gujarati),
      ScriptType.telugu: (line, ctx) => indic.romanize(line, ScriptType.telugu),
      ScriptType.kannada: (line, ctx) => indic.romanize(line, ScriptType.kannada),
      ScriptType.odia: (line, ctx) => indic.romanize(line, ScriptType.odia),
      ScriptType.tamil: (line, ctx) => tamil.romanize(line, ctx),
      ScriptType.thai: (line, ctx) => thai.romanize(line, ctx),
    };
  }
}

class _ResolvedLine {
  final String text;
  final bool fallback;
  const _ResolvedLine({required this.text, required this.fallback});
}
