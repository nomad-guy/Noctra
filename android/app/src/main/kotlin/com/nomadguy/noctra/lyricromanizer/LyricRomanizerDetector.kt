package com.nomadguy.noctra.lyricromanizer

/**
 * Port of lyric-romanizer/src/detector.ts
 *
 * Script detection engine for lyrics text. Uses Unicode BMP code ranges
 * to identify scripts with zero API calls.
 */

/** A Unicode code range [start, end] inclusive. */
data class CodeRange(val start: Int, val end: Int)

/** Metadata for a single script's detection behavior. */
data class ScriptMeta(
    val ranges: List<CodeRange>,
    val definitive: Boolean = false,
    val external: Boolean = false
)

/**
 * Single source of truth for per-script detection ranges and classification.
 * Entry order is load-bearing: tie-break priority of [detectScript].
 */
object ScriptMetadata {
    val entries: Map<ScriptType, ScriptMeta> = linkedMapOf(
        ScriptType.JAPANESE to ScriptMeta(
            ranges = listOf(CodeRange(0x3040, 0x30FF)),
            definitive = true
        ),
        ScriptType.CHINESE to ScriptMeta(ranges = listOf(CodeRange(0x4E00, 0x9FFF))),
        ScriptType.KOREAN to ScriptMeta(ranges = listOf(CodeRange(0xAC00, 0xD7AF))),
        ScriptType.CYRILLIC to ScriptMeta(ranges = listOf(CodeRange(0x0400, 0x04FF))),
        ScriptType.DEVANAGARI to ScriptMeta(ranges = listOf(CodeRange(0x0900, 0x097F))),
        ScriptType.GUJARATI to ScriptMeta(ranges = listOf(CodeRange(0x0A80, 0x0AFF))),
        ScriptType.TELUGU to ScriptMeta(ranges = listOf(CodeRange(0x0C00, 0x0C7F))),
        ScriptType.KANNADA to ScriptMeta(ranges = listOf(CodeRange(0x0C80, 0x0CFF))),
        ScriptType.ODIA to ScriptMeta(ranges = listOf(CodeRange(0x0B00, 0x0B7F))),
        ScriptType.TAMIL to ScriptMeta(ranges = listOf(CodeRange(0x0B80, 0x0BFF))),
        ScriptType.MALAYALAM to ScriptMeta(ranges = listOf(CodeRange(0x0D00, 0x0D7F)), external = true),
        ScriptType.BENGALI to ScriptMeta(ranges = listOf(CodeRange(0x0980, 0x09FF)), external = true),
        ScriptType.ARABIC to ScriptMeta(ranges = listOf(CodeRange(0x0600, 0x06FF)), external = true),
        ScriptType.HEBREW to ScriptMeta(ranges = listOf(CodeRange(0x0590, 0x05FF)), external = true),
        ScriptType.THAI to ScriptMeta(ranges = listOf(CodeRange(0x0E00, 0x0E7F))),
        ScriptType.LATIN to ScriptMeta(ranges = emptyList()),
        ScriptType.OTHER to ScriptMeta(ranges = emptyList(), external = true)
    )

    /** Precomputed regex pattern for non-Latin script characters. */
    val nonLatinPattern: Regex by lazy {
        val allRanges = entries.entries
            .filter { it.key != ScriptType.LATIN && it.key != ScriptType.OTHER }
            .flatMap { it.value.ranges }
        val merged = mergeRanges(allRanges)
        val pattern = merged.joinToString("") { r ->
            val s = "\\u${r.start.toString(16).uppercase().padStart(4, '0')}"
            val e = "\\u${r.end.toString(16).uppercase().padStart(4, '0')}"
            if (r.start == r.end) s else "$s-$e"
        }
        Regex("[$pattern]")
    }

    private fun mergeRanges(ranges: List<CodeRange>): List<CodeRange> {
        if (ranges.isEmpty()) return emptyList()
        val sorted = ranges.sortedBy { it.start }
        val merged = mutableListOf<CodeRange>()
        for (r in sorted) {
            val last = merged.lastOrNull()
            if (last == null || r.start > last.end + 1) {
                merged.add(r)
            } else {
                merged[merged.lastIndex] = CodeRange(last.start, maxOf(last.end, r.end))
            }
        }
        return merged
    }
}

/** Returns true if text contains only Latin letters. */
fun isLatinScript(lines: List<String>): Boolean {
    val text = lines.joinToString("")
    return !ScriptMetadata.nonLatinPattern.containsMatchIn(text) &&
            text.any { it in 'a'..'z' || it in 'A'..'Z' }
}

/** Detects the dominant script in the given text lines. */
fun detectScript(lines: List<String>): ScriptType {
    val text = lines.joinToString("")

    // Check definitive scripts first (Japanese kana is definitive)
    for ((script, meta) in ScriptMetadata.entries) {
        if (!meta.definitive) continue
        for (range in meta.ranges) {
            for (ch in text) {
                val cp = ch.code
                if (cp in range.start..range.end) return script
            }
        }
    }

    // Score non-definitive scripts by character count
    var best = ScriptType.OTHER
    var bestScore = 0
    for ((script, meta) in ScriptMetadata.entries) {
        if (meta.ranges.isEmpty() || meta.definitive) continue
        var score = 0
        for (ch in text) {
            val cp = ch.code
            for (range in meta.ranges) {
                if (cp in range.start..range.end) {
                    score++
                    break
                }
            }
        }
        if (score > bestScore) {
            bestScore = score
            best = script
        }
    }

    if (bestScore > 0) return best
    return if (text.any { it in 'a'..'z' || it in 'A'..'Z' }) ScriptType.LATIN else ScriptType.OTHER
}

/** Returns true for scripts that have no built-in engine. */
fun requiresExternalRomanization(script: ScriptType): Boolean {
    return ScriptMetadata.entries[script]?.external ?: false
}
