package com.nomadguy.noctra.lyricromanizer

import com.nomadguy.noctra.lyricromanizer.engines.*

/**
 * Port of lyric-romanizer/src/romanizer.ts
 *
 * Core romanizer orchestrator with lazy-loaded engines, pluggable engine
 * injection, universal-fallback transliteration, and warmup support.
 */
object LyricRomanizer {

    private val ukraineRe = Regex("[іїєґ]", RegexOption.IGNORE_CASE)

    /** Selects the Cyrillic transliteration preset per line. */
    fun selectCyrillicPreset(line: String): String =
        if (ukraineRe.containsMatchIn(line)) "uk" else "ru"

    /** Creates a [Romanizer] instance with the given options. */
    fun create(options: RomanizerOptions? = null): Romanizer {
        return DefaultRomanizer(options)
    }
}

private class DefaultRomanizer(
    private val options: RomanizerOptions?
) : Romanizer {

    private val engines = mutableMapOf<ScriptType, RomanizeEngine>()
    private val defaultEngines = buildDefaultEngines()

    init {
        engines.putAll(defaultEngines)
        options?.engines?.forEach { (script, engine) ->
            if (engine != null) engines[script] = engine
        }
    }

    override suspend fun warmup(scripts: List<ScriptType>?) {
        val requested = scripts ?: defaultEngines.keys.toList()
        for (script in requested) {
            if (engines[script] != defaultEngines[script]) continue
            // Pure Kotlin engines — no async init needed.
        }
    }

    override suspend fun romanizeLine(
        line: String,
        options: RomanizeOptions?
    ): String {
        val result = resolveLine(line, options?.script, options)
        return result.first
    }

    override suspend fun romanizeLines(
        lines: List<String>,
        options: RomanizeOptions?
    ): RomanizeResult {
        val script = options?.script ?: detectScript(lines)

        if (script != ScriptType.LATIN && !engines.containsKey(script)) {
            throw UnsupportedRomanizationError(script)
        }
        if (script == ScriptType.LATIN) {
            return RomanizeResult(
                script = script,
                lines = lines.toList(),
                fallbacks = lines.map { false }
            )
        }

        val resolved = lines.map { line -> resolveLine(line, script, options) }
        return RomanizeResult(
            script = script,
            lines = resolved.map { it.first },
            fallbacks = resolved.map { it.second }
        )
    }

    private suspend fun resolveLine(
        line: String,
        script: ScriptType?,
        options: RomanizeOptions?
    ): Pair<String, Boolean> {
        if (line.isBlank() || !line.any { it in 'a'..'z' || it in 'A'..'Z' }) {
            return line to false
        }

        val resolved = script ?: detectScript(listOf(line))
        if (resolved == ScriptType.LATIN) return line to false

        val engine = engines[resolved]
            ?: throw UnsupportedRomanizationError(resolved)

        // Latin guard
        val hasAscii = line.any { it in 'a'..'z' || it in 'A'..'Z' }
        val hasNonLatin = nonLatinRe.containsMatchIn(line)
        if (hasAscii && !hasNonLatin) {
            return line to false
        }

        val context = RomanizeEngineContext(
            dialect = options?.dialect ?: ChineseDialect.MANDARIN
        )

        return try {
            engine(line, context) to false
        } catch (_: Exception) {
            // Universal fallback
            try {
                UniversalFallback.transliterate(line) to true
            } catch (_: Exception) {
                line to true
            }
        }
    }

    private fun buildDefaultEngines(): Map<ScriptType, RomanizeEngine> {
        val japanese = JapaneseEngine()
        val chinese = ChineseEngine()
        val korean = KoreanEngine()
        val cyrillic = CyrillicEngine()
        val thai = ThaiEngine()
        val tamil = TamilEngine()
        val indic = IndicEngine()

        return mapOf(
            ScriptType.JAPANESE to { line, ctx -> japanese.romanize(line, ctx) },
            ScriptType.CHINESE to { line, ctx -> chinese.romanize(line, ctx) },
            ScriptType.KOREAN to { line, ctx -> korean.romanize(line, ctx) },
            ScriptType.CYRILLIC to { line, ctx -> cyrillic.romanize(line, ctx) },
            ScriptType.DEVANAGARI to { line, _ -> indic.romanize(line, ScriptType.DEVANAGARI) },
            ScriptType.GUJARATI to { line, _ -> indic.romanize(line, ScriptType.GUJARATI) },
            ScriptType.TELUGU to { line, _ -> indic.romanize(line, ScriptType.TELUGU) },
            ScriptType.KANNADA to { line, _ -> indic.romanize(line, ScriptType.KANNADA) },
            ScriptType.ODIA to { line, _ -> indic.romanize(line, ScriptType.ODIA) },
            ScriptType.TAMIL to { line, ctx -> tamil.romanize(line, ctx) },
            ScriptType.THAI to { line, ctx -> thai.romanize(line, ctx) }
        )
    }

    companion object {
        private val nonLatinRe = ScriptMetadata.nonLatinPattern
    }
}

/** Universal fallback transliterator. */
object UniversalFallback {
    private val fallbackMap = mapOf(
        0x0410 to "A", 0x0411 to "B", 0x0412 to "V", 0x0413 to "G",
        0x0414 to "D", 0x0415 to "E", 0x0416 to "Zh", 0x0417 to "Z",
        0x0418 to "I", 0x0419 to "Y", 0x041A to "K", 0x041B to "L",
        0x041C to "M", 0x041D to "N", 0x041E to "O", 0x041F to "P",
        0x0420 to "R", 0x0421 to "S", 0x0422 to "T", 0x0423 to "U",
        0x0424 to "F", 0x0425 to "Kh", 0x0426 to "Ts", 0x0427 to "Ch",
        0x0428 to "Sh", 0x0429 to "Shch", 0x042A to "", 0x042B to "Y",
        0x042C to "", 0x042D to "E", 0x042E to "Yu", 0x042F to "Ya",
        0x0430 to "a", 0x0431 to "b", 0x0432 to "v", 0x0433 to "g",
        0x0434 to "d", 0x0435 to "e", 0x0436 to "zh", 0x0437 to "z",
        0x0438 to "i", 0x0439 to "y", 0x043A to "k", 0x043B to "l",
        0x043C to "m", 0x043D to "n", 0x043E to "o", 0x043F to "p",
        0x0440 to "r", 0x0441 to "s", 0x0442 to "t", 0x0443 to "u",
        0x0444 to "f", 0x0445 to "kh", 0x0446 to "ts", 0x0447 to "ch",
        0x0448 to "sh", 0x0449 to "shch", 0x044A to "", 0x044B to "y",
        0x044C to "", 0x044D to "e", 0x044E to "yu", 0x044F to "ya",
        0x0406 to "i", 0x0407 to "yi", 0x0404 to "ye", 0x0490 to "g",
        0x0456 to "i", 0x0457 to "yi", 0x0454 to "ye", 0x0491 to "g"
    )

    fun transliterate(line: String): String {
        val buf = StringBuilder()
        for (rune in line.codePoints()) {
            val mapped = fallbackMap[rune]
            if (mapped != null) {
                buf.append(mapped)
            } else if (rune < 0x0080) {
                buf.appendCodePoint(rune)
            } else {
                buf.appendCodePoint(rune)
            }
        }
        return buf.toString()
    }
}
