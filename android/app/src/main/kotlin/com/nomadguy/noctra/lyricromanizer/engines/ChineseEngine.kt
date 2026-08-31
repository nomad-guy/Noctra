package com.nomadguy.noctra.lyricromanizer.engines

import com.nomadguy.noctra.lyricromanizer.ChineseDialect
import com.nomadguy.noctra.lyricromanizer.RomanizeEngineContext

/** Chinese romanizer using Pinyin (Mandarin) and Jyutping (Cantonese) tables. */
class ChineseEngine {

    private val pinyinMap = mapOf(
        '我' to "wǒ", '你' to "nǐ", '他' to "tā", '她' to "tā", '它' to "tā",
        '的' to "de", '是' to "shì", '不' to "bù", '在' to "zài", '有' to "yǒu",
        '这' to "zhè", '个' to "gè", '们' to "men", '中' to "zhōng", '来' to "lái",
        '上' to "shàng", '大' to "dà", '为' to "wèi", '和' to "hé", '国' to "guó",
        '地' to "dì", '到' to "dào", '以' to "yǐ", '说' to "shuō", '时' to "shí",
        '要' to "yào", '就' to "jiù", '出' to "chū", '会' to "huì", '可' to "kě",
        '也' to "yě", '爱' to "ài", '心' to "xīn", '情' to "qíng", '天' to "tiān",
        '夜' to "yè", '梦' to "mèng", '想' to "xiǎng", '生' to "shēng", '世' to "shì",
        '界' to "jiè", '美' to "měi", '好' to "hǎo", '雨' to "yǔ", '风' to "fēng",
        '星' to "xīng", '月' to "yuè", '日' to "rì", '光' to "guāng", '歌' to "gē",
        '花' to "huā", '雪' to "xuě", '水' to "shuǐ", '火' to "huǒ", '山' to "shān",
        '海' to "hǎi", '河' to "hé", '红' to "hóng", '白' to "bái", '黑' to "hēi",
        '人' to "rén", '家' to "jiā", '路' to "lù", '门' to "mén",
        '酒' to "jiǔ", '茶' to "chá", '风' to "fēng", '月' to "yuè",
        '春' to "chūn", '夏' to "xià", '秋' to "qiū", '冬' to "dōng",
        '一' to "yī", '二' to "èr", '三' to "sān", '四' to "sì", '五' to "wǔ",
        '六' to "liù", '七' to "qī", '八' to "bā", '九' to "jiǔ", '十' to "shí",
        '很' to "hěn", '太' to "tài", '真' to "zhēn", '最' to "zuì",
        '都' to "dōu", '只' to "zhǐ", '没' to "méi", '能' to "néng",
        '飞' to "fēi", '走' to "zǒu", '见' to "jiàn", '看' to "kàn",
        '听' to "tīng", '吃' to "chī", '喝' to "hē", '睡' to "shuì",
        '做' to "zuò", '学' to "xué", '读' to "dú", '写' to "xiě",
        '开' to "kāi", '关' to "guān", '拿' to "ná", '放' to "fàng",
        '给' to "gěi", '请' to "qǐng", '问' to "wèn", '知' to "zhī", '道' to "dào",
        '快' to "kuài", '慢' to "màn", '早' to "zǎo", '晚' to "wǎn",
        '今' to "jīn", '昨' to "zuó", '明' to "míng", '年' to "nián",
        '长' to "cháng", '短' to "duǎn", '高' to "gāo", '低' to "dī",
        '远' to "yuǎn", '近' to "jìn", '新' to "xīn", '旧' to "jiù",
        '多' to "duō", '少' to "shǎo", '全' to "quán", '半' to "bàn",
        '空' to "kōng", '满' to "mǎn", '深' to "shēn", '浅' to "qiǎn",
        '重' to "zhòng", '轻' to "qīng", '强' to "qiáng", '弱' to "ruò",
        '有' to "yǒu", '无' to "wú", '来' to "lái", '去' to "qù",
        '回' to "huí", '离' to "lí", '聚' to "jù", '散' to "sàn",
        '始' to "shǐ", '终' to "zhōng", '起' to "qǐ", '止' to "zhǐ",
        '动' to "dòng", '静' to "jìng", '黑' to "hēi", '白' to "bái",
        '红' to "hóng", '蓝' to "lán", '黄' to "huáng", '紫' to "zǐ",
        '金' to "jīn", '银' to "yín", '铁' to "tiě", '玉' to "yù",
        '冰' to "bīng", '霜' to "shuāng", '雷' to "léi", '电' to "diàn",
        '朝' to "zhāo", '夕' to "xī", '晨' to "chén", '暮' to "mù",
        '缘' to "yuán", '情' to "qíng", '爱' to "ài", '恨' to "hèn",
        '喜' to "xǐ", '怒' to "nù", '哀' to "āi", '乐' to "lè",
        '苦' to "kǔ", '甜' to "tián", '冷' to "lěng", '热' to "rè",
        '花' to "huā", '开' to "kāi", '落' to "luò", '谢' to "xiè",
        '飘' to "piāo", '散' to "sàn", '谁' to "shuí", '哪' to "nǎ",
        '如' to "rú", '若' to "ruò", '而' to "ér", '但' to "dàn",
        '虽' to "suī", '却' to "què", '已' to "yǐ", '曾' to "céng",
        '正' to "zhèng", '将' to "jiāng", '永' to "yǒng", '久' to "jiǔ",
        '全' to "quán", '半' to "bàn"
    )

    private val jyutpingMap = mapOf(
        '我' to "ngo5", '你' to "nei5", '他' to "keoi5", '她' to "keoi5",
        '的' to "ge3", '是' to "hai6", '不' to "bat1", '在' to "zoi6",
        '有' to "jau5", '这' to "ni1", '个' to "go3", '爱' to "oi3",
        '心' to "sam1", '情' to "cing4", '天' to "tin1", '夜' to "je6",
        '梦' to "mung6", '想' to "soeng2", '生' to "saang1",
        '花' to "faa1", '雪' to "syut3", '水' to "seoi2", '火' to "fo2",
        '山' to "saan1", '海' to "hoi2", '风' to "fung1", '月' to "jyut6",
        '日' to "jat6", '歌' to "go1", '红' to "hung4", '白' to "baak6",
        '人' to "jan4", '家' to "gaa1", '酒' to "zau2", '茶' to "caa4",
        '春' to "ceon1", '秋' to "cau1", '中' to "zung1", '来' to "loi4"
    )

    suspend fun romanize(line: String, context: RomanizeEngineContext): String {
        val map = if (context.dialect == ChineseDialect.CANTONESE) jyutpingMap else pinyinMap
        val buf = StringBuilder()
        for (ch in line) {
            val roman = map[ch]
            if (roman != null) {
                buf.append("$roman ")
            } else {
                buf.append(ch)
            }
        }
        return buf.toString().trimEnd()
    }
}
