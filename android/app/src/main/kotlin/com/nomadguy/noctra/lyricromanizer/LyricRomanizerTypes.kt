package com.nomadguy.noctra.lyricromanizer

/**
 * Port of lyric-romanizer/src/types.ts
 *
 * Core type definitions for the lyric romanizer engine.
 */

/** Supported script types for detection and romanization. */
enum class ScriptType {
    JAPANESE, CHINESE, KOREAN, CYRILLIC, DEVANAGARI, GUJARATI,
    TELUGU, KANNADA, ODIA, TAMIL, MALAYALAM, BENGALI, ARABIC, HEBREW,
    THAI, LATIN, OTHER
}

/** Chinese dialect option for romanization system selection. */
enum class ChineseDialect { MANDARIN, CANTONESE }

/** Options for romanization operations. */
data class RomanizeOptions(
    val script: ScriptType? = null,
    val dialect: ChineseDialect? = null
)

/** Result of a multi-line romanization operation. */
data class RomanizeResult(
    val script: ScriptType,
    val lines: List<String>,
    val fallbacks: List<Boolean>
)

/** Context passed to engine adapters during romanization. */
data class RomanizeEngineContext(
    val dialect: ChineseDialect = ChineseDialect.MANDARIN
)

/** An engine adapter: romanizes one line of its script. */
typealias RomanizeEngine = suspend (String, RomanizeEngineContext) -> String

/** Factory options for creating a Romanizer instance. */
data class RomanizerOptions(
    val japaneseDictPath: String? = null,
    val engines: Map<ScriptType, RomanizeEngine?>? = null
)

/** Thrown when attempting to romanize a script that has no engine. */
class UnsupportedRomanizationError(val script: ScriptType) :
    Exception("Script '${script.name}' requires external romanization.")

/** The main romanizer interface. */
interface Romanizer {
    suspend fun romanizeLine(line: String, options: RomanizeOptions? = null): String
    suspend fun romanizeLines(
        lines: List<String>,
        options: RomanizeOptions? = null
    ): RomanizeResult

    suspend fun warmup(scripts: List<ScriptType>? = null)
}
