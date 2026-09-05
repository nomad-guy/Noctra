package com.nomadguy.noctra.lyricromanizer.engines

import com.nomadguy.noctra.lyricromanizer.RomanizeEngineContext
import com.nomadguy.noctra.lyricromanizer.ScriptType

/** Sanscript-based Indic script romanizer. */
class IndicEngine {

    private val offsets = mapOf(
        ScriptType.DEVANAGARI to 0x0900,
        ScriptType.BENGALI to 0x0980,
        ScriptType.GUJARATI to 0x0A80,
        ScriptType.TAMIL to 0x0B80,
        ScriptType.TELUGU to 0x0C00,
        ScriptType.KANNADA to 0x0C80,
        ScriptType.MALAYALAM to 0x0D00
    )

    private val vowelMap = mapOf(
        0x05 to "a", 0x06 to "aa", 0x07 to "i", 0x08 to "ii",
        0x09 to "u", 0x0A to "uu", 0x0B to "ri", 0x0C to "e",
        0x0D to "ai", 0x0E to "o", 0x0F to "au"
    )

    private val consonantMap = mapOf(
        0x15 to "ka", 0x16 to "kha", 0x17 to "ga", 0x18 to "gha", 0x19 to "nga",
        0x1A to "cha", 0x1B to "chha", 0x1C to "ja", 0x1D to "jha", 0x1E to "nya",
        0x1F to "ta", 0x20 to "tha", 0x21 to "da", 0x22 to "dha", 0x23 to "na",
        0x24 to "ta", 0x25 to "tha", 0x26 to "da", 0x27 to "dha", 0x28 to "na",
        0x2A to "pa", 0x2B to "pha", 0x2C to "ba", 0x2D to "bha", 0x2E to "ma",
        0x2F to "ya", 0x30 to "ra", 0x31 to "la", 0x32 to "va", 0x33 to "sha",
        0x34 to "sha", 0x35 to "sa", 0x36 to "ha"
    )

    private val matraMap = mapOf(
        0x3E to "aa", 0x3F to "i", 0x40 to "ii", 0x41 to "u", 0x42 to "uu",
        0x43 to "ri", 0x47 to "e", 0x48 to "ai", 0x4B to "o", 0x4C to "au"
    )

    private val anusvara = 0x02
    private val chandrabindu = 0x01
    private val virama = 0x4D

    suspend fun romanize(line: String, script: ScriptType): String {
        val buf = StringBuilder()
        val offset = offsets[script] ?: 0x0900
        var consonantPending = false

        for (rune in line.codePoints()) {
            val rel = rune - offset

            if (rel == virama) {
                consonantPending = false
                continue
            }
            if (rel == anusvara) {
                consonantPending = false
                continue
            }
            if (rel == chandrabindu) {
                consonantPending = false
                continue
            }

            val vow = vowelMap[rel]
            if (vow != null) {
                buf.append(vow)
                consonantPending = false
                continue
            }

            val matra = matraMap[rel]
            if (matra != null) {
                buf.append(matra)
                consonantPending = false
                continue
            }

            val cons = consonantMap[rel]
            if (cons != null) {
                if (consonantPending) buf.append('a')
                buf.append(cons)
                consonantPending = true
                continue
            }

            if (consonantPending) {
                buf.append('a')
                consonantPending = false
            }
            buf.appendCodePoint(rune)
        }

        if (consonantPending) buf.append('a')
        return buf.toString()
    }
}
