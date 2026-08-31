package com.nomadguy.noctra.lyricromanizer.engines

import com.nomadguy.noctra.lyricromanizer.RomanizeEngineContext

/** Tamil to Latin romanizer. */
class TamilEngine {

    private val vowels = mapOf(
        'அ' to "a", 'ஆ' to "aa", 'இ' to "i", 'ஈ' to "ee", 'உ' to "u",
        'ஊ' to "uu", 'எ' to "e", 'ஏ' to "ee", 'ஐ' to "ai", 'ஒ' to "o",
        'ஓ' to "oo", 'ஔ' to "au"
    )

    private val vowelSigns = mapOf(
        'ா' to "aa", 'ி' to "i", 'ீ' to "ee", 'ு' to "u", 'ூ' to "uu",
        'ெ' to "e", 'ே' to "ee", 'ை' to "ai", 'ொ' to "o", 'ோ' to "oo", 'ௌ' to "au"
    )

    private val consonants = mapOf(
        'க' to "ka", 'ங' to "nga", 'ச' to "sa", 'ஞ' to "nya", 'ட' to "da",
        'ண' to "na", 'த' to "tha", 'ந' to "na", 'ப' to "ba", 'ம' to "ma",
        'ய' to "ya", 'ர' to "ra", 'ல' to "la", 'வ' to "va", 'ழ' to "zha",
        'ள' to "la", 'ற' to "ra", 'ன' to "na"
    )

    suspend fun romanize(line: String, context: RomanizeEngineContext): String {
        val buf = StringBuilder()
        for (ch in line) {
            val v = vowels[ch]
            if (v != null) { buf.append(v); continue }
            val c = consonants[ch]
            if (c != null) { buf.append(c); continue }
            val vs = vowelSigns[ch]
            if (vs != null) { buf.append(vs); continue }
            if (ch == '்') continue  // virama — suppress inherent vowel
            buf.append(ch)
        }
        return buf.toString()
    }
}
