import 'lyrics_service.dart';
import 'devanagari_transliteration_service.dart';
import 'romanized_translation_engine.dart';
import 'sanscript_engine.dart';
import '../lyric_romanizer/lyric_romanizer_detector.dart' as lr;
import '../lyric_romanizer/lyric_romanizer_types.dart' as lr;

/// Script type enum (matches old LyricScript for UI compatibility).
enum ScriptType {
  latin, japanese, korean, chinese, cyrillic, arabic, greek,
  thai, hebrew, devanagari, gurmukhi, bengali, tamil, telugu, gujarati,
  kannada, malayalam, odia, other,
}

class ScriptOption {
  final String code;
  final String label;
  const ScriptOption({required this.code, required this.label});
}

/// Cached lyrics romanization service using the lyric_romanizer detector.
class LyricsRomanizationService {
  LyricsRomanizationService._();

  static final Map<String, String> _cache = {};
  static const int _maxCache = 500;
  static final _devaToRomanEngine = RomanizedTranslationEngine();

  static void _put(String key, String value) {
    if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
    _cache[key] = value;
  }

  static ScriptType _map(lr.ScriptType s) => switch (s) {
    lr.ScriptType.japanese => ScriptType.japanese,
    lr.ScriptType.chinese => ScriptType.chinese,
    lr.ScriptType.korean => ScriptType.korean,
    lr.ScriptType.cyrillic => ScriptType.cyrillic,
    lr.ScriptType.devanagari => ScriptType.devanagari,
    lr.ScriptType.gurmukhi => ScriptType.gurmukhi,
    lr.ScriptType.gujarati => ScriptType.gujarati,
    lr.ScriptType.telugu => ScriptType.telugu,
    lr.ScriptType.kannada => ScriptType.kannada,
    lr.ScriptType.odia => ScriptType.odia,
    lr.ScriptType.tamil => ScriptType.tamil,
    lr.ScriptType.malayalam => ScriptType.malayalam,
    lr.ScriptType.bengali => ScriptType.bengali,
    lr.ScriptType.arabic => ScriptType.arabic,
    lr.ScriptType.hebrew => ScriptType.hebrew,
    lr.ScriptType.thai => ScriptType.thai,
    lr.ScriptType.latin => ScriptType.latin,
    lr.ScriptType.other => ScriptType.other,
  };

  /// Detect the dominant script in lyrics text.
  static ScriptType detectScript(String text) {
    if (text.trim().isEmpty) return ScriptType.latin;
    return _map(lr.detectScript([text]));
  }

  /// Get available script options for the given lyrics data.
  static List<ScriptOption> getAvailableScriptOptions(LyricsData data) {
    final sample = data.lines.isNotEmpty
        ? data.lines.map((l) => l.text).take(10).join(' ')
        : data.plainText;
    final script = detectScript(sample);

    return switch (script) {
      ScriptType.japanese => const [
        ScriptOption(code: 'original', label: 'Original (日本語)'),
        ScriptOption(code: 'roman', label: 'Romaji (Latin)'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
      ScriptType.korean => const [
        ScriptOption(code: 'original', label: 'Original (한국어)'),
        ScriptOption(code: 'roman', label: 'Romanized'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
      ScriptType.chinese => const [
        ScriptOption(code: 'original', label: 'Original (中文)'),
        ScriptOption(code: 'roman', label: 'Pinyin'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
      ScriptType.cyrillic => const [
        ScriptOption(code: 'original', label: 'Original (Русский)'),
        ScriptOption(code: 'roman', label: 'Romanized (Latin)'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
      ScriptType.arabic => const [
        ScriptOption(code: 'original', label: 'Original (العربية)'),
        ScriptOption(code: 'roman', label: 'Romanized'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
      ScriptType.greek => const [
        ScriptOption(code: 'original', label: 'Original (Ελληνικά)'),
        ScriptOption(code: 'roman', label: 'Romanized'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी'),
      ],
      ScriptType.thai => const [
        ScriptOption(code: 'original', label: 'Original (ไทย)'),
        ScriptOption(code: 'roman', label: 'Romanized (RTGS)'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी'),
      ],
      ScriptType.hebrew => const [
        ScriptOption(code: 'original', label: 'Original (עברית)'),
        ScriptOption(code: 'roman', label: 'Romanized'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी'),
      ],
      ScriptType.devanagari => const [
        ScriptOption(code: 'original', label: 'मूल (देवनागरी)'),
        ScriptOption(code: 'roman', label: 'Roman (English)'),
      ],
      ScriptType.latin || ScriptType.other => const [
        ScriptOption(code: 'original', label: 'Original (English)'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
      _ => const [
        ScriptOption(code: 'original', label: 'Original Script'),
        ScriptOption(code: 'roman', label: 'Romanized (English)'),
        ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
      ],
    };
  }

  /// Transliterate full lyrics to the target script (cached).
  static LyricsData transliterateLyrics(LyricsData lyrics, String targetScript) {
    if (targetScript == 'original' || targetScript == 'raw') return lyrics;

    if (lyrics.isSynced && lyrics.lines.isNotEmpty) {
      final convertedLines = lyrics.lines.map((line) {
        final cacheKey = '$targetScript:${line.text}';
        final cached = _cache[cacheKey];
        if (cached != null) {
          return LyricLine(timestamp: line.timestamp, text: cached);
        }
        final converted = transliterateText(line.text, targetScript);
        _put(cacheKey, converted);
        return LyricLine(timestamp: line.timestamp, text: converted);
      }).toList();

      return LyricsData(
        plainText: convertedLines.map((l) => l.text).join('\n'),
        lines: convertedLines,
        isSynced: true,
      );
    } else {
      final convertedText = transliterateText(lyrics.plainText, targetScript);
      return LyricsData(
        plainText: convertedText,
        lines: const [],
        isSynced: false,
      );
    }
  }

  /// Transliterate a single line to the target script.
  static String transliterateText(String input, String targetScript) {
    if (input.trim().isEmpty) return input;
    final sourceScript = detectScript(input);

    // Convert source → Roman (intermediate)
    final romanText = _toRoman(input, sourceScript);

    if (targetScript == 'roman' || targetScript == 'english' ||
        targetScript == 'romaji' || targetScript == 'pinyin') {
      return romanText;
    }

    // Convert Roman → Target
    if (targetScript == 'devanagari') {
      if (sourceScript == ScriptType.devanagari) return input;
      return DevanagariTransliterationService.toDevanagari(romanText);
    }

    return romanText;
  }

  static String _toRoman(String text, ScriptType source) => switch (source) {
    ScriptType.devanagari => _devaToRomanEngine.toRomanized(text),
    ScriptType.bengali => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.bengali, SanscriptEngine.devanagari)),
    ScriptType.gujarati => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.gujarati, SanscriptEngine.devanagari)),
    ScriptType.telugu => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.telugu, SanscriptEngine.devanagari)),
    ScriptType.tamil => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.tamil, SanscriptEngine.devanagari)),
    ScriptType.kannada => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.kannada, SanscriptEngine.devanagari)),
    ScriptType.malayalam => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.malayalam, SanscriptEngine.devanagari)),
    ScriptType.gurmukhi => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari)),
    ScriptType.odia => _devaToRomanEngine.toRomanized(
        SanscriptEngine.t(text, SanscriptEngine.odia, SanscriptEngine.devanagari)),
    ScriptType.japanese => _japaneseToRomaji(text),
    ScriptType.korean => _koreanToRoman(text),
    ScriptType.chinese => _chineseToPinyin(text),
    ScriptType.cyrillic => _mapChars(text, _cyrillicMap),
    ScriptType.arabic => _mapChars(text, _arabicMap),
    ScriptType.greek => _mapChars(text, _greekMap),
    ScriptType.thai => _mapChars(text, _thaiMap),
    ScriptType.hebrew => _mapChars(text, _hebrewMap),
    ScriptType.latin || ScriptType.other => text,
  };

  static String _mapChars(String text, Map<String, String> map) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  // ── Japanese ──
  static String _japaneseToRomaji(String text) {
    String p = text
        .replaceAll('こんにちは', 'konnichiwa').replaceAll('こんばんは', 'konbanwa')
        .replaceAll('コンニチハ', 'konnichiwa').replaceAll('コンバンハ', 'konbanwa');
    final sb = StringBuffer();
    int i = 0;
    while (i < p.length) {
      if (i + 1 < p.length) {
        final pair = p.substring(i, i + 2);
        final dig = _jpDigraphs[pair];
        if (dig != null) { sb.write(dig); i += 2; continue; }
      }
      final ch = p[i];
      if ((ch == 'っ' || ch == 'ッ') && i + 1 < p.length) {
        final nr = _jpMono[p[i + 1]] ?? '';
        if (nr.isNotEmpty) sb.write(nr[0]);
        i++; continue;
      }
      sb.write(_jpMono[ch] ?? ch);
      i++;
    }
    return sb.toString();
  }

  static const _jpMono = {
    'あ':'a','い':'i','う':'u','え':'e','お':'o','か':'ka','き':'ki','く':'ku','け':'ke','こ':'ko',
    'さ':'sa','し':'shi','す':'su','せ':'se','そ':'so','た':'ta','ち':'chi','つ':'tsu','て':'te','と':'to',
    'な':'na','に':'ni','ぬ':'nu','ね':'ne','の':'no','は':'ha','ひ':'hi','ふ':'fu','へ':'he','ほ':'ho',
    'ま':'ma','み':'mi','む':'mu','め':'me','も':'mo','や':'ya','ゆ':'yu','よ':'yo',
    'ら':'ra','り':'ri','る':'ru','れ':'re','ろ':'ro','わ':'wa','を':'wo','ん':'n',
    'が':'ga','ぎ':'gi','ぐ':'gu','げ':'ge','ご':'go','ざ':'za','じ':'ji','ず':'zu','ぜ':'ze','ぞ':'zo',
    'だ':'da','ぢ':'ji','づ':'zu','で':'de','ど':'do','ば':'ba','び':'bi','ぶ':'bu','べ':'be','ぼ':'bo',
    'ぱ':'pa','ぴ':'pi','ぷ':'pu','ぺ':'pe','ぽ':'po',
    'ア':'a','イ':'i','ウ':'u','エ':'e','オ':'o','カ':'ka','キ':'ki','ク':'ku','ケ':'ke','コ':'ko',
    'サ':'sa','シ':'shi','ス':'su','セ':'se','ソ':'so','タ':'ta','チ':'chi','ツ':'tsu','テ':'te','ト':'to',
    'ナ':'na','ニ':'ni','ヌ':'nu','ネ':'ne','ノ':'no','ハ':'ha','ヒ':'hi','フ':'fu','ヘ':'he','ホ':'ho',
    'マ':'ma','ミ':'mi','ム':'mu','メ':'me','モ':'mo','ヤ':'ya','ユ':'yu','ヨ':'yo',
    'ラ':'ra','リ':'ri','ル':'ru','レ':'re','ロ':'ro','ワ':'wa','ヲ':'wo','ン':'n',
    'ガ':'ga','ギ':'gi','グ':'gu','ゲ':'ge','ゴ':'go','ザ':'za','ジ':'ji','ズ':'zu','ゼ':'ze','ゾ':'zo',
    'ダ':'da','ヂ':'ji','ヅ':'zu','デ':'de','ド':'do','バ':'ba','ビ':'bi','ブ':'bu','ベ':'be','ボ':'bo',
    'パ':'pa','ピ':'pi','プ':'pu','ペ':'pe','ポ':'po',
  };

  static const _jpDigraphs = {
    'きゃ':'kya','きゅ':'kyu','きょ':'kyo','しゃ':'sha','しゅ':'shu','しょ':'sho',
    'ちゃ':'cha','ちゅ':'chu','ちょ':'cho','にゃ':'nya','にゅ':'nyu','にょ':'nyo',
    'ひゃ':'hya','ひゅ':'hyu','ひょ':'hyo','みゃ':'mya','みゅ':'myu','みょ':'myo',
    'りゃ':'rya','りゅ':'ryu','りょ':'ryo','ぎゃ':'gya','ぎゅ':'gyu','ぎょ':'gyo',
    'じゃ':'ja','じゅ':'ju','じょ':'jo','びゃ':'bya','びゅ':'byu','びょ':'byo',
    'ぴゃ':'pya','ぴゅ':'pyu','ぴょ':'pyo',
    'キャ':'kya','キュ':'kyu','キョ':'kyo','シャ':'sha','シュ':'shu','ショ':'sho',
    'チャ':'cha','チュ':'chu','チョ':'cho','ニャ':'nya','ニュ':'nyu','ニョ':'nyo',
    'ヒャ':'hya','ヒュ':'hyu','ヒョ':'hyo','ミャ':'mya','ミュ':'myu','ミョ':'myo',
    'リャ':'rya','リュ':'ryu','リョ':'ryo','ギャ':'gya','ギュ':'gyu','ギョ':'gyo',
    'ジャ':'ja','ジュ':'ju','ジョ':'jo','ビャ':'bya','ビュ':'byu','ビョ':'byo',
    'ピャ':'pya','ピュ':'pyu','ピョ':'pyo',
  };

  // ── Korean ──
  static const _cho = ['g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h'];
  static const _jung = ['a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo','u','wo','we','wi','yu','eu','ui','i'];
  static const _jong = ['','k','k','ks','n','nj','nh','t','l','lk','lm','lb','ls','lt','lp','lh','m','p','ps','t','t','ng','t','t','k','t','p','h'];

  static String _koreanToRoman(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final c = rune - 0xAC00;
        sb.write(_cho[c ~/ (21*28)]); sb.write(_jung[(c%(21*28))~/28]); sb.write(_jong[c%28]);
      } else { sb.write(String.fromCharCode(rune)); }
    }
    return sb.toString();
  }

  // ── Chinese ──
  static const _py = {
    '我':'wo','你':'ni','他':'ta','她':'ta','的':'de','是':'shi','不':'bu','在':'zai','有':'you',
    '这':'zhe','个':'ge','们':'men','中':'zhong','来':'lai','上':'shang','大':'da','为':'wei',
    '和':'he','国':'guo','地':'di','到':'dao','以':'yi','说':'shuo','时':'shi','要':'yao',
    '就':'jiu','出':'chu','会':'hui','可':'ke','也':'ye','爱':'ai','心':'xin','情':'qing',
    '天':'tian','夜':'ye','梦':'meng','想':'xiang','生':'sheng','世':'shi','界':'jie',
    '美':'mei','好':'hao','雨':'yu','风':'feng','星':'xing','月':'yue','日':'ri',
    '光':'guang','歌':'ge',
  };

  static String _chineseToPinyin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) { sb.write('${_py[ch] ?? ch} '); }
    return sb.toString().trim();
  }

  // ── Lookup tables ──
  static const _cyrillicMap = {
    'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ё':'yo','ж':'zh','з':'z',
    'и':'i','й':'y','к':'k','л':'l','м':'m','н':'n','о':'o','п':'p','р':'r',
    'с':'s','т':'t','у':'u','ф':'f','х':'kh','ц':'ts','ч':'ch','ш':'sh','щ':'shch',
    'ъ':'','ы':'y','ь':'','э':'e','ю':'yu','я':'ya',
    'А':'A','Б':'B','В':'V','Г':'G','Д':'D','Е':'E','Ё':'Yo','Ж':'Zh','З':'Z',
    'И':'I','Й':'Y','К':'K','Л':'L','М':'M','Н':'N','О':'O','П':'P','Р':'R',
    'С':'S','Т':'T','У':'U','Ф':'F','Х':'Kh','Ц':'Ts','Ч':'Ch','Ш':'Sh','Щ':'Shch',
    'Ъ':'','Ы':'Y','Ь':'','Э':'E','Ю':'Yu','Я':'Ya',
  };
  static const _arabicMap = {
    'ا':'a','أ':'a','إ':'i','آ':'aa','ب':'b','ت':'t','ث':'th','ج':'j','ح':'h',
    'خ':'kh','د':'d','ذ':'dh','ر':'r','ز':'z','س':'s','ش':'sh','ص':'s','ض':'d',
    'ط':'t','ظ':'z','ع':"'",'غ':'gh','ف':'f','ق':'q','ك':'k','ل':'l','م':'m',
    'ن':'n','ه':'h','و':'w','ي':'y','ى':'a','ة':'h',
  };
  static const _greekMap = {
    'α':'a','β':'v','γ':'g','δ':'d','ε':'e','ζ':'z','η':'i','θ':'th','ι':'i',
    'κ':'k','λ':'l','μ':'m','ν':'n','ξ':'x','ο':'o','π':'p','ρ':'r','σ':'s',
    'ς':'s','τ':'t','υ':'y','φ':'f','χ':'ch','ψ':'ps','ω':'o',
  };
  static const _thaiMap = {
    'ก':'k','ข':'kh','ค':'kh','ง':'ng','จ':'ch','ฉ':'ch','ช':'ch','ซ':'s',
    'ด':'d','ต':'t','ถ':'th','ท':'th','น':'n','บ':'b','ป':'p','ผ':'ph',
    'ฝ':'f','พ':'ph','ฟ':'f','ม':'m','ย':'y','ร':'r','ล':'l','ว':'w',
    'ส':'s','ห':'h','อ':'','ฮ':'h',
    'ะ':'a','า':'a','ิ':'i','ี':'i','ึ':'ue','ื':'ue','ุ':'u','ู':'u',
    'เ':'e','แ':'ae','โ':'o','ใ':'ai','ไ':'ai',
  };
  static const _hebrewMap = {
    'א':"'",'ב':'b','ג':'g','ד':'d','ה':'h','ו':'v','ז':'z','ח':'ch',
    'ט':'t','י':'y','כ':'k','ך':'k','ל':'l','מ':'m','ם':'m','נ':'n',
    'ן':'n','ס':'s','ע':"'",'פ':'p','ף':'p','צ':'tz','ץ':'tz','ק':'k',
    'ר':'r','ש':'sh','ת':'t',
  };
}
