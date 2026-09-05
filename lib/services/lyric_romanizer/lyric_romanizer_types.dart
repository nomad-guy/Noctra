/// Port of lyric-romanizer/src/types.ts
///
/// Core type definitions for the lyric romanizer engine.

/// Supported script types for detection and romanization.
library;
enum ScriptType {
  japanese,
  chinese,
  korean,
  cyrillic,
  devanagari,
  gurmukhi,
  gujarati,
  telugu,
  kannada,
  odia,
  tamil,
  malayalam,
  bengali,
  arabic,
  hebrew,
  thai,
  latin,
  other,
}

/// Chinese dialect option for romanization system selection.
enum ChineseDialect { mandarin, cantonese }

/// Options for romanization operations.
class RomanizeOptions {
  final ScriptType? script;
  final ChineseDialect? dialect;
  const RomanizeOptions({this.script, this.dialect});
}

/// Result of a multi-line romanization operation.
class RomanizeResult {
  final ScriptType script;
  final List<String> lines;
  final List<bool> fallbacks;

  const RomanizeResult({
    required this.script,
    required this.lines,
    required this.fallbacks,
  });

  @override
  String toString() =>
      'RomanizeResult(script: ${script.name}, lines: $lines, fallbacks: $fallbacks)';
}

/// Context passed to engine adapters during romanization.
class RomanizeEngineContext {
  final ChineseDialect dialect;
  const RomanizeEngineContext({this.dialect = ChineseDialect.mandarin});
}

/// An engine adapter: romanizes one line of its script.
typedef RomanizeEngine = Future<String> Function(
  String line,
  RomanizeEngineContext context,
);

/// Factory options for creating a Romanizer instance.
class RomanizerOptions {
  final String? japaneseDictPath;
  final Map<ScriptType, RomanizeEngine?>? engines;
  const RomanizerOptions({this.japaneseDictPath, this.engines});
}

/// Thrown when attempting to romanize a script that has no engine.
class UnsupportedRomanizationError implements Exception {
  final ScriptType script;
  const UnsupportedRomanizationError(this.script);

  @override
  String toString() =>
      "UnsupportedRomanizationError: Script '${script.name}' requires external romanization.";
}

/// The main romanizer interface.
abstract class Romanizer {
  Future<String> romanizeLine(String line, {RomanizeOptions? options});
  Future<RomanizeResult> romanizeLines(
    List<String> lines, {
    RomanizeOptions? options,
  });
  Future<void> warmup([List<ScriptType>? scripts]);
}
