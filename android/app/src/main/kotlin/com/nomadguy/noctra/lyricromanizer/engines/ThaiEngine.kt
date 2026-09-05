package com.nomadguy.noctra.lyricromanizer.engines

import com.nomadguy.noctra.lyricromanizer.RomanizeEngineContext

/** Thai to Latin romanizer (RTGS-based). */
class ThaiEngine {

    private val consonants = mapOf(
        'ก' to "k", 'ข' to "kh", 'ค' to "kh", 'ง' to "ng", 'จ' to "ch",
        'ฉ' to "ch", 'ช' to "ch", 'ซ' to "s", 'ด' to "d", 'ต' to "t",
        'ถ' to "th", 'ท' to "th", 'น' to "n", 'บ' to "b", 'ป' to "p",
        'ผ' to "ph", 'ฝ' to "f", 'พ' to "ph", 'ฟ' to "f", 'ม' to "m",
        'ย' to "y", 'ร' to "r", 'ล' to "l", 'ว' to "w", 'ส' to "s",
        'ห' to "h", 'อ' to "", 'ฮ' to "h"
    )

    private val vowels = mapOf(
        'ะ' to "a", 'า' to "a", 'ิ' to "i", 'ี' to "i",
        'ึ' to "ue", 'ื' to "ue", 'ุ' to "u", 'ู' to "u",
        'เ' to "e", 'แ' to "ae", 'โ' to "o", 'ใ' to "ai", 'ไ' to "ai"
    )

    private val toneMarks = setOf('่', '้', '๊', '๋')

    private val combining = mapOf('ำ' to "am")

    suspend fun romanize(line: String, context: RomanizeEngineContext): String {
        val buf = StringBuilder()
        var i = 0
        while (i < line.length) {
            val ch = line[i]
            val comb = combining[ch]
            if (comb != null) {
                buf.append(comb)
                i++; continue
            }
            val cons = consonants[ch]
            if (cons != null) {
                buf.append(cons)
                i++; continue
            }
            val vow = vowels[ch]
            if (vow != null) {
                buf.append(vow)
                i++; continue
            }
            if (ch in toneMarks) {
                i++; continue
            }
            buf.append(ch)
            i++
        }
        return buf.toString()
    }
}
