package com.nomadguy.noctra.lyricromanizer.engines

import com.nomadguy.noctra.lyricromanizer.RomanizeEngineContext

/** Cyrillic to Latin romanizer with Ukrainian auto-detection. */
class CyrillicEngine {

    private val ukraineRe = Regex("[іїєґ]", RegexOption.IGNORE_CASE)

    private val ruMap = mapOf(
        'а' to "a", 'б' to "b", 'в' to "v", 'г' to "g", 'д' to "d",
        'е' to "e", 'ё' to "yo", 'ж' to "zh", 'з' to "z", 'и' to "i",
        'й' to "y", 'к' to "k", 'л' to "l", 'м' to "m", 'н' to "n",
        'о' to "o", 'п' to "p", 'р' to "r", 'с' to "s", 'т' to "t",
        'у' to "u", 'ф' to "f", 'х' to "kh", 'ц' to "ts", 'ч' to "ch",
        'ш' to "sh", 'щ' to "shch", 'ъ' to "", 'ы' to "y", 'ь' to "",
        'э' to "e", 'ю' to "yu", 'я' to "ya",
        'А' to "A", 'Б' to "B", 'В' to "V", 'Г' to "G", 'Д' to "D",
        'Е' to "E", 'Ё' to "Yo", 'Ж' to "Zh", 'З' to "Z", 'И' to "I",
        'Й' to "Y", 'К' to "K", 'Л' to "L", 'М' to "M", 'Н' to "N",
        'О' to "O", 'П' to "P", 'Р' to "R", 'С' to "S", 'Т' to "T",
        'У' to "U", 'Ф' to "F", 'Х' to "Kh", 'Ц' to "Ts", 'Ч' to "Ch",
        'Ш' to "Sh", 'Щ' to "Shch", 'Ъ' to "", 'Ы' to "Y", 'Ь' to "",
        'Э' to "E", 'Ю' to "Yu", 'Я' to "Ya"
    )

    private val ukMap = mapOf(
        'і' to "i", 'ї' to "yi", 'є' to "ye", 'ґ' to "g",
        'І' to "I", 'Ї' to "Yi", 'Є' to "Ye", 'Ґ' to "G"
    )

    /** Selects the Ukrainian preset for Ukrainian-specific characters. */
    fun selectPreset(line: String): String =
        if (ukraineRe.containsMatchIn(line)) "uk" else "ru"

    suspend fun romanize(line: String, context: RomanizeEngineContext): String {
        val preset = selectPreset(line)
        val buf = StringBuilder()
        for (ch in line) {
            if (preset == "uk" && ukMap.containsKey(ch)) {
                buf.append(ukMap[ch])
            } else {
                buf.append(ruMap[ch] ?: ch)
            }
        }
        return buf.toString()
    }
}
