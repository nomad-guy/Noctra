/// Chinese romanization engine.
///
/// Pure-Dart Pinyin romanizer for common Chinese characters.
/// Supports Mandarin (Pinyin) and Cantonese (Jyutping) dialects.

library;
import '../lyric_romanizer_types.dart';

/// Chinese romanizer using character-mapping tables.
class ChineseRomanizer {
  const ChineseRomanizer();

  /// Common Chinese characters to Pinyin mapping (Mandarin).
  static final Map<String, String> _pinyinMap = {
    '我': 'wǒ', '你': 'nǐ', '他': 'tā', '她': 'tā', '它': 'tā',
    '的': 'de', '是': 'shì', '不': 'bù', '在': 'zài', '有': 'yǒu',
    '这': 'zhè', '个': 'gè', '们': 'men', '中': 'zhōng', '来': 'lái',
    '上': 'shàng', '大': 'dà', '为': 'wèi', '和': 'hé', '国': 'guó',
    '地': 'dì', '到': 'dào', '以': 'yǐ', '说': 'shuō', '时': 'shí',
    '要': 'yào', '就': 'jiù', '出': 'chū', '会': 'huì', '可': 'kě',
    '也': 'yě', '爱': 'ài', '心': 'xīn', '情': 'qíng', '天': 'tiān',
    '夜': 'yè', '梦': 'mèng', '想': 'xiǎng', '生': 'shēng', '世': 'shì',
    '界': 'jiè', '美': 'měi', '好': 'hǎo', '雨': 'yǔ', '风': 'fēng',
    '星': 'xīng', '月': 'yuè', '日': 'rì', '光': 'guāng', '歌': 'gē',
    '花': 'huā', '雪': 'xuě', '水': 'shuǐ', '火': 'huǒ', '山': 'shān',
    '海': 'hǎi', '河': 'hé', '树': 'shù', '草': 'cǎo', '鸟': 'niǎo',
    '鱼': 'yú', '马': 'mǎ', '龙': 'lóng', '云': 'yún', '春': 'chūn',
    '夏': 'xià', '秋': 'qiū', '冬': 'dōng', '红': 'hóng', '白': 'bái',
    '黑': 'hēi', '蓝': 'lán', '绿': 'lǜ', '黄': 'huáng', '紫': 'zǐ',
    '一': 'yī', '二': 'èr', '三': 'sān', '四': 'sì', '五': 'wǔ',
    '六': 'liù', '七': 'qī', '八': 'bā', '九': 'jiǔ', '十': 'shí',
    '百': 'bǎi', '千': 'qiān', '万': 'wàn', '亿': 'yì',
    '请': 'qǐng', '问': 'wèn', '知': 'zhī', '道': 'dào', '走': 'zǒu',
    '见': 'jiàn', '看': 'kàn', '听': 'tīng', '吃': 'chī', '喝': 'hē',
    '睡': 'shuì', '做': 'zuò', '学': 'xué', '读': 'dú', '写': 'xiě',
    '飞': 'fēi', '跑': 'pǎo', '坐': 'zuò', '站': 'zhàn', '开': 'kāi',
    '关': 'guān', '拿': 'ná', '放': 'fàng', '给': 'gěi',
    '很': 'hěn', '太': 'tài', '真': 'zhēn', '最': 'zuì', '更': 'gèng',
    '还': 'hái', '都': 'dōu', '只': 'zhǐ', '没': 'méi', '别': 'bié',
    '能': 'néng', '让': 'ràng', '把': 'bǎ', '被': 'bèi', '对': 'duì',
    '从': 'cóng', '向': 'xiàng', '与': 'yǔ',
    '人': 'rén', '子': 'zǐ', '男': 'nán', '老': 'lǎo', '少': 'shǎo',
    '新': 'xīn', '旧': 'jiù', '长': 'cháng', '短': 'duǎn',
    '高': 'gāo', '低': 'dī', '远': 'yuǎn', '近': 'jìn', '快': 'kuài',
    '慢': 'màn', '早': 'zǎo', '晚': 'wǎn', '东': 'dōng', '西': 'xī',
    '南': 'nán', '北': 'běi', '左': 'zuǒ', '右': 'yòu', '前': 'qián',
    '后': 'hòu', '里': 'lǐ', '外': 'wài', '家': 'jiā',
    '城': 'chéng', '村': 'cūn', '路': 'lù', '门': 'mén', '窗': 'chuāng',
    '书': 'shū', '笔': 'bǐ', '画': 'huà', '琴': 'qín',
    '酒': 'jiǔ', '茶': 'chá', '饭': 'fàn', '菜': 'cài', '肉': 'ròu',
    '米': 'mǐ', '面': 'miàn', '蛋': 'dàn', '糖': 'táng',
    '恨': 'hèn', '喜': 'xǐ', '怒': 'nù', '哀': 'āi',
    '乐': 'lè', '苦': 'kǔ', '甜': 'tián', '酸': 'suān', '辣': 'là',
    '冷': 'lěng', '热': 'rè', '温': 'wēn', '凉': 'liáng',
    '今': 'jīn', '昨': 'zuó', '明': 'míng', '年': 'nián',
    '空': 'kōng', '满': 'mǎn', '深': 'shēn', '浅': 'qiǎn',
    '重': 'zhòng', '轻': 'qīng', '强': 'qiáng', '弱': 'ruò',
    '善': 'shàn', '恶': 'è',
    '假': 'jiǎ', '虚': 'xū', '实': 'shí',
    '无': 'wú', '死': 'sǐ',
    '去': 'qù', '回': 'huí', '离': 'lí',
    '聚': 'jù', '散': 'sàn', '合': 'hé',
    '始': 'shǐ', '终': 'zhōng', '起': 'qǐ', '止': 'zhǐ',
    '动': 'dòng', '静': 'jìng',
    '金': 'jīn', '银': 'yín', '铁': 'tiě', '玉': 'yù',
    '石': 'shí', '土': 'tǔ', '冰': 'bīng', '雷': 'léi', '电': 'diàn',
    '缘': 'yuán', '份': 'fèn', '运': 'yùn', '命': 'mìng',
    '恩': 'ēn', '怨': 'yuàn',
    '思': 'sī', '念': 'niàn', '忆': 'yì', '忘': 'wàng',
    '记': 'jì', '醒': 'xǐng', '醉': 'zuì', '痴': 'chī', '迷': 'mí',
    '悟': 'wù', '觉': 'jué', '感': 'gǎn',
    '神': 'shén', '仙': 'xiān',
    '谁': 'shuí', '哪': 'nǎ', '什': 'shén', '怎': 'zěn',
    '因': 'yīn', '所': 'suǒ', '如': 'rú', '若': 'ruò',
    '而': 'ér', '但': 'dàn', '虽': 'suī', '却': 'què',
    '已': 'yǐ', '曾': 'céng', '正': 'zhèng', '将': 'jiāng',
    '永': 'yǒng', '久': 'jiǔ',
    '多': 'duō', '全': 'quán', '半': 'bàn',
    '刚': 'gāng', '柔': 'róu',
    '丑': 'chǒu', '朝': 'zhāo', '夕': 'xī', '晨': 'chén', '暮': 'mù',
    '晓': 'xiǎo', '昏': 'hūn', '午': 'wǔ',
    '飘': 'piāo', '谢': 'xiè', '落': 'luò',
  };

  /// Cantonese Jyutping for common characters.
  static final Map<String, String> _jyutpingMap = {
    '我': 'ngo5', '你': 'nei5', '他': 'keoi5', '她': 'keoi5',
    '的': 'ge3', '是': 'hai6', '不': 'bat1', '在': 'zoi6', '有': 'jau5',
    '这': 'ni1', '个': 'go3', '们': 'mun4', '中': 'zung1', '来': 'loi4',
    '爱': 'oi3', '心': 'sam1', '情': 'cing4', '天': 'tin1', '夜': 'je6',
    '梦': 'mung6', '想': 'soeng2', '生': 'saang1', '世': 'sai3',
    '界': 'gaai3', '美': 'mei5', '好': 'hou2', '雨': 'jyu5', '风': 'fung1',
    '星': 'sing1', '月': 'jyut6', '日': 'jat6', '光': 'gwong1', '歌': 'go1',
    '花': 'faa1', '雪': 'syut3', '水': 'seoi2', '火': 'fo2', '山': 'saan1',
    '海': 'hoi2', '河': 'ho4', '红': 'hung4', '白': 'baak6', '黑': 'hak1',
    '蓝': 'laam4', '绿': 'luk6', '黄': 'wong4', '人': 'jan4',
    '家': 'gaa1', '路': 'lou6', '门': 'mun4', '酒': 'zau2', '茶': 'caa4',
    '春': 'ceon1', '秋': 'cau1',
  };

  Future<String> romanize(String line, RomanizeEngineContext context) async {
    final isCantonese = context.dialect == ChineseDialect.cantonese;
    final map = isCantonese ? _jyutpingMap : _pinyinMap;
    final buf = StringBuffer();
    for (final ch in line.split('')) {
      final roman = map[ch];
      if (roman != null) {
        buf.write('$roman ');
      } else {
        buf.write(ch);
      }
    }
    return buf.toString().trimRight();
  }
}
