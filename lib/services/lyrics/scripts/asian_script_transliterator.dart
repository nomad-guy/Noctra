class AsianScriptTransliterator {
  static String japaneseToRomaji(String text) {
    String processed = text
        .replaceAll('こんにちは', 'konnichiwa')
        .replaceAll('こんばんは', 'konbanwa')
        .replaceAll('コンニチハ', 'konnichiwa')
        .replaceAll('コンバンハ', 'konbanwa');

    final sb = StringBuffer();
    int i = 0;
    while (i < processed.length) {
      if (i + 1 < processed.length) {
        final pair = processed.substring(i, i + 2);
        if (_japaneseDigraphs.containsKey(pair)) {
          sb.write(_japaneseDigraphs[pair]);
          i += 2;
          continue;
        }
      }
      final ch = processed[i];
      if ((ch == 'っ' || ch == 'ッ') && i + 1 < processed.length) {
        final nextCh = processed[i + 1];
        final nextRomaji = _japaneseMonographs[nextCh] ?? '';
        if (nextRomaji.isNotEmpty) {
          sb.write(nextRomaji[0]);
        }
        i++;
        continue;
      }
      if (_japaneseMonographs.containsKey(ch)) {
        sb.write(_japaneseMonographs[ch]);
      } else {
        sb.write(ch);
      }
      i++;
    }
    return sb.toString();
  }

  static const _choseong = [
    'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp',
    's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'
  ];
  static const _jungseong = [
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o',
    'wa', 'wae', 'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu',
    'eu', 'ui', 'i'
  ];
  static const _jongseong = [
    '', 'k', 'k', 'ks', 'n', 'nj', 'nh', 't', 'l', 'lk',
    'lm', 'lb', 'ls', 'lt', 'lp', 'lh', 'm', 'p', 'ps',
    't', 't', 'ng', 't', 't', 'k', 't', 'p', 'h'
  ];

  static String koreanHangulToRoman(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final code = rune - 0xAC00;
        final cho = code ~/ (21 * 28);
        final jung = (code % (21 * 28)) ~/ 28;
        final jong = code % 28;

        sb.write(_choseong[cho]);
        sb.write(_jungseong[jung]);
        sb.write(_jongseong[jong]);
      } else {
        sb.write(String.fromCharCode(rune));
      }
    }
    return sb.toString();
  }

  static String chineseToPinyin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      if (_chineseCommonPinyin.containsKey(ch)) {
        sb.write('${_chineseCommonPinyin[ch]} ');
      } else {
        sb.write(ch);
      }
    }
    return sb.toString().trim();
  }

  static const Map<String, String> _japaneseMonographs = {
    'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
    'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
    'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
    'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
    'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
    'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
    'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
    'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
    'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
    'わ': 'wa', 'を': 'wo', 'ん': 'n',
    'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
    'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
    'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
    'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
    'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
    'ア': 'a', 'イ': 'i', 'ウ': 'u', 'エ': 'e', 'オ': 'o',
    'カ': 'ka', 'キ': 'ki', 'ク': 'ku', 'ケ': 'ke', 'コ': 'ko',
    'サ': 'sa', 'シ': 'shi', 'ス': 'su', 'セ': 'se', 'ソ': 'so',
    'タ': 'ta', 'チ': 'chi', 'ツ': 'tsu', 'テ': 'te', 'ト': 'to',
    'ナ': 'na', 'ニ': 'ni', 'ヌ': 'nu', 'ネ': 'ne', 'ノ': 'no',
    'ハ': 'ha', 'ヒ': 'hi', 'フ': 'fu', 'ヘ': 'he', 'ホ': 'ho',
    'マ': 'ma', 'ミ': 'mi', 'ム': 'mu', 'メ': 'me', 'モ': 'mo',
    'ヤ': 'ya', 'ユ': 'yu', 'ヨ': 'yo',
    'ラ': 'ra', 'リ': 'ri', 'ル': 'ru', 'レ': 're', 'ロ': 'ro',
    'ワ': 'wa', 'ヲ': 'wo', 'ン': 'n',
    'ガ': 'ga', 'ギ': 'gi', 'グ': 'gu', 'ゲ': 'ge', 'ゴ': 'go',
    'ザ': 'za', 'ジ': 'ji', 'ズ': 'zu', 'ゼ': 'ze', 'ゾ': 'zo',
    'ダ': 'da', 'ヂ': 'ji', 'ヅ': 'zu', 'デ': 'de', 'ド': 'do',
    'バ': 'ba', 'ビ': 'bi', 'ブ': 'bu', 'ベ': 'be', 'ボ': 'bo',
    'パ': 'pa', 'ピ': 'pi', 'プ': 'pu', 'ペ': 'pe', 'ポ': 'po',
  };

  static const Map<String, String> _japaneseDigraphs = {
    'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo',
    'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho',
    'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho',
    'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
    'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo',
    'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
    'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
    'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
    'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo',
    'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
    'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo',
    'キャ': 'kya', 'キュ': 'kyu', 'キョ': 'kyo',
    'シャ': 'sha', 'シュ': 'shu', 'ショ': 'sho',
    'チャ': 'cha', 'チュ': 'chu', 'チョ': 'cho',
    'ニャ': 'nya', 'ニュ': 'nyu', 'ニョ': 'nyo',
    'ヒャ': 'hya', 'ヒュ': 'hyu', 'ヒョ': 'hyo',
    'ミャ': 'mya', 'ミュ': 'myu', 'ミョ': 'myo',
    'リャ': 'rya', 'リュ': 'ryu', 'リョ': 'ryo',
    'ギャ': 'gya', 'ギュ': 'gyu', 'ギョ': 'gyo',
    'ジャ': 'ja', 'ジュ': 'ju', 'ジョ': 'jo',
    'ビャ': 'bya', 'ビュ': 'byu', 'ビョ': 'byo',
    'ピャ': 'pya', 'ピュ': 'pyu', 'ピョ': 'pyo',
  };

  static const Map<String, String> _chineseCommonPinyin = {
    '我': 'wo', '你': 'ni', '他': 'ta', '她': 'ta', '它': 'ta',
    '的': 'de', '是': 'shi', '不': 'bu', '在': 'zai', '有': 'you',
    '这': 'zhe', '个': 'ge', '们': 'men', '中': 'zhong', '来': 'lai',
    '上': 'shang', '大': 'da', '为': 'wei', '和': 'he', '国': 'guo',
    '地': 'di', '到': 'dao', '以': 'yi', '说': 'shuo', '时': 'shi',
    '要': 'yao', '就': 'jiu', '出': 'chu', '会': 'hui', '可': 'ke',
    '也': 'ye', '爱': 'ai', '心': 'xin', '情': 'qing', '天': 'tian',
    '夜': 'ye', '梦': 'meng', '想': 'xiang', '生': 'sheng', '世': 'shi',
    '界': 'jie', '美': 'mei', '好': 'hao', '雨': 'yu', '风': 'feng',
    '星': 'xing', '月': 'yue', '日': 'ri', '光': 'guang', '歌': 'ge',
  };
}
