/// Port of lyric-romanizer/src/detector.ts
///
/// Script detection engine for lyrics text. Uses Unicode BMP code ranges
/// to identify scripts with zero API calls.

library;
import 'lyric_romanizer_types.dart';

/// A Unicode code range [start, end] inclusive.
class CodeRange {
  final int start;
  final int end;
  const CodeRange(this.start, this.end);
}

/// Metadata for a single script's detection behavior.
class ScriptMeta {
  final List<CodeRange> ranges;
  final bool definitive;
  final bool external;
  const ScriptMeta({
    required this.ranges,
    this.definitive = false,
    this.external = false,
  });
}

/// Single source of truth for per-script detection ranges and classification.
///
/// Entry order is load-bearing: tie-break priority of [detectScript]
/// — on an equal character count, the earlier entry wins.
const Map<ScriptType, ScriptMeta> scriptMetadata = {
  ScriptType.japanese: ScriptMeta(
    ranges: [CodeRange(0x3040, 0x30FF)],
    definitive: true,
  ),
  ScriptType.chinese: ScriptMeta(ranges: [CodeRange(0x4E00, 0x9FFF)]),
  ScriptType.korean: ScriptMeta(ranges: [CodeRange(0xAC00, 0xD7AF)]),
  ScriptType.cyrillic: ScriptMeta(ranges: [CodeRange(0x0400, 0x04FF)]),
  ScriptType.devanagari: ScriptMeta(ranges: [CodeRange(0x0900, 0x097F)]),
  ScriptType.gujarati: ScriptMeta(ranges: [CodeRange(0x0A80, 0x0AFF)]),
  ScriptType.telugu: ScriptMeta(ranges: [CodeRange(0x0C00, 0x0C7F)]),
  ScriptType.kannada: ScriptMeta(ranges: [CodeRange(0x0C80, 0x0CFF)]),
  ScriptType.gurmukhi: ScriptMeta(ranges: [CodeRange(0x0A00, 0x0A7F)]),
  ScriptType.odia: ScriptMeta(ranges: [CodeRange(0x0B00, 0x0B7F)]),
  ScriptType.tamil: ScriptMeta(ranges: [CodeRange(0x0B80, 0x0BFF)]),
  ScriptType.malayalam:
      ScriptMeta(ranges: [CodeRange(0x0D00, 0x0D7F)], external: true),
  ScriptType.bengali:
      ScriptMeta(ranges: [CodeRange(0x0980, 0x09FF)], external: true),
  ScriptType.arabic:
      ScriptMeta(ranges: [CodeRange(0x0600, 0x06FF)], external: true),
  ScriptType.hebrew:
      ScriptMeta(ranges: [CodeRange(0x0590, 0x05FF)], external: true),
  ScriptType.thai: ScriptMeta(ranges: [CodeRange(0x0E00, 0x0E7F)]),
  ScriptType.latin: ScriptMeta(ranges: []),
  ScriptType.other: ScriptMeta(ranges: [], external: true),
};

/// Precomputed regex for any non-Latin script character.
final RegExp nonLatinScriptRegex = _buildNonLatinRegex();

RegExp _buildNonLatinRegex() {
  final allRanges = scriptMetadata.entries
      .where((e) => e.key != ScriptType.latin && e.key != ScriptType.other)
      .expand((e) => e.value.ranges)
      .toList();
  final merged = _mergeRanges(allRanges);
  final buf = StringBuffer('[');
  for (final r in merged) {
    buf.write(
        '\\u${r.start.toRadixString(16).toUpperCase().padLeft(4, '0')}');
    if (r.start != r.end) {
      buf.write(
          '-\\u${r.end.toRadixString(16).toUpperCase().padLeft(4, '0')}');
    }
  }
  buf.write(']');
  return RegExp(buf.toString());
}

List<CodeRange> _mergeRanges(List<CodeRange> ranges) {
  if (ranges.isEmpty) return [];
  final sorted = List<CodeRange>.from(ranges)..sort((a, b) => a.start - b.start);
  final merged = <CodeRange>[];
  for (final r in sorted) {
    if (merged.isEmpty || r.start > merged.last.end + 1) {
      merged.add(r);
    } else {
      final last = merged.last;
      merged[merged.length - 1] =
          CodeRange(last.start, last.end > r.end ? last.end : r.end);
    }
  }
  return merged;
}

/// Returns `true` if text contains only Latin letters (no CJK, Cyrillic, etc.).
bool isLatinScript(List<String> lines) {
  final text = lines.join();
  return !nonLatinScriptRegex.hasMatch(text) &&
      RegExp(r'\p{L}', unicode: true).hasMatch(text);
}

/// Detects the dominant script in the given text lines.
///
/// Checks for Japanese kana first (definitive), then scores all other
/// scripts by character count. Entry order in [scriptMetadata] is the
/// tie-breaker.
ScriptType detectScript(List<String> lines) {
  final text = lines.join();

  // Check definitive scripts first (Japanese kana is definitive)
  for (final entry in scriptMetadata.entries) {
    if (!entry.value.definitive) continue;
    for (final range in entry.value.ranges) {
      for (int i = 0; i < text.length; i++) {
        final cp = text.codeUnitAt(i);
        if (cp >= range.start && cp <= range.end) return entry.key;
      }
    }
  }

  // Score non-definitive scripts by character count
  ScriptType best = ScriptType.other;
  int bestScore = 0;
  for (final entry in scriptMetadata.entries) {
    if (entry.value.ranges.isEmpty || entry.value.definitive) continue;
    int score = 0;
    for (int i = 0; i < text.length; i++) {
      final cp = text.codeUnitAt(i);
      for (final range in entry.value.ranges) {
        if (cp >= range.start && cp <= range.end) {
          score++;
          break;
        }
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = entry.key;
    }
  }

  if (bestScore > 0) return best;
  return RegExp(r'\p{L}', unicode: true).hasMatch(text)
      ? ScriptType.latin
      : ScriptType.other;
}

/// Returns `true` for scripts that have no built-in engine and require
/// an external API.
bool requiresExternalRomanization(ScriptType script) {
  final meta = scriptMetadata[script];
  if (meta == null) return false;
  return meta.external;
}
