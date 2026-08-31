package com.nomadguy.noctra.lyricromanizer.engines

import com.nomadguy.noctra.lyricromanizer.RomanizeEngineContext

/** Korean Hangul romanizer using Jamo decomposition. */
class KoreanEngine {

    private val choseong = listOf(
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp",
        "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"
    )

    private val jungseong = listOf(
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o",
        "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu",
        "eu", "ui", "i"
    )

    private val jongseong = listOf(
        "", "k", "k", "ks", "n", "nj", "nh", "t", "l", "lk",
        "lm", "lb", "ls", "lt", "lp", "lh", "m", "p", "ps", "t",
        "t", "ng", "t", "t", "k", "t", "p", "h"
    )

    suspend fun romanize(line: String, context: RomanizeEngineContext): String {
        val buf = StringBuilder()
        for (rune in line.codePoints()) {
            if (rune in 0xAC00..0xD7A3) {
                val code = rune - 0xAC00
                val cho = code / (21 * 28)
                val jung = (code % (21 * 28)) / 28
                val jong = code % 28
                buf.append(choseong[cho])
                buf.append(jungseong[jung])
                buf.append(jongseong[jong])
            } else {
                buf.appendCodePoint(rune)
            }
        }
        return buf.toString()
    }
}
