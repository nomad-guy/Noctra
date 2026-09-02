import 'devanagari_transliteration_service.dart';
import 'sanscript_engine.dart';
import 'lyrics_service.dart';
import 'romanized_translation_engine.dart';

enum LyricScript {
  latin,
  japanese,
  korean,
  chinese,
  cyrillic,
  arabic,
  greek,
  thai,
  hebrew,
  devanagari,
  gurmukhi,
  bengali,
  tamil,
  telugu,
  gujarati,
  kannada,
  malayalam,
  odia,
}

class ScriptOption {
  final String code;
  final String label;
  const ScriptOption({required this.code, required this.label});
}

class UniversalLyricsTransliterationEngine {
  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 3000;
  static int _lexiconVersion = 0;
  static final RomanizedTranslationEngine _romanizer = RomanizedTranslationEngine();

  /// Called when custom pronunciations are learned — invalidates stale cache entries.
  static void invalidateCache() {
    _lexiconVersion++;
    _cache.clear();
  }

  /// Detects the primary script of a given piece of lyric text.
  static LyricScript detectScript(String text) {
    int devanagariCount = 0;
    int gurmukhiCount = 0;
    int bengaliCount = 0;
    int tamilCount = 0;
    int teluguCount = 0;
    int gujaratiCount = 0;
    int kannadaCount = 0;
    int malayalamCount = 0;
    int odiaCount = 0;
    int japaneseCount = 0;
    int koreanCount = 0;
    int chineseCount = 0;
    int cyrillicCount = 0;
    int arabicCount = 0;
    int greekCount = 0;
    int thaiCount = 0;
    int hebrewCount = 0;

    for (final rune in text.runes) {
      if (rune >= 0x0900 && rune <= 0x097F) {
        devanagariCount++;
      } else if (rune >= 0x0A00 && rune <= 0x0A7F) {
        gurmukhiCount++;
      } else if (rune >= 0x0980 && rune <= 0x09FF) {
        bengaliCount++;
      } else if (rune >= 0x0B80 && rune <= 0x0BFF) {
        tamilCount++;
      } else if (rune >= 0x0C00 && rune <= 0x0C7F) {
        teluguCount++;
      } else if (rune >= 0x0A80 && rune <= 0x0AFF) {
        gujaratiCount++;
      } else if (rune >= 0x0C80 && rune <= 0x0CFF) {
        kannadaCount++;
      } else if (rune >= 0x0D00 && rune <= 0x0D7F) {
        malayalamCount++;
      } else if (rune >= 0x0B00 && rune <= 0x0B7F) {
        odiaCount++;
      } else if ((rune >= 0x3040 && rune <= 0x309F) || (rune >= 0x30A0 && rune <= 0x30FF)) {
        japaneseCount++;
      } else if ((rune >= 0xAC00 && rune <= 0xD7AF) || (rune >= 0x1100 && rune <= 0x11FF) || (rune >= 0x3130 && rune <= 0x318F)) {
        koreanCount++;
      } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        chineseCount++;
      } else if (rune >= 0x0400 && rune <= 0x04FF) {
        cyrillicCount++;
      } else if ((rune >= 0x0600 && rune <= 0x06FF) || (rune >= 0x0750 && rune <= 0x077F) || (rune >= 0xFB50 && rune <= 0xFDFF)) {
        arabicCount++;
      } else if (rune >= 0x0370 && rune <= 0x03FF) {
        greekCount++;
      } else if (rune >= 0x0E00 && rune <= 0x0E7F) {
        thaiCount++;
      } else if (rune >= 0x0590 && rune <= 0x05FF) {
        hebrewCount++;
      }
    }

    if (japaneseCount > 0) return LyricScript.japanese;
    if (koreanCount > 0) return LyricScript.korean;
    // Han-only text (no kana) is ambiguous between Chinese and Japanese.
    // Only classify as Chinese when there's a strong signal (many Han chars,
    // no kana, and no other script present). Otherwise preserve original.
    if (chineseCount > 10 && japaneseCount == 0) return LyricScript.chinese;
    // A single short lyric line can be a valid script sample. Requiring four
    // characters made controls disappear for lines such as "दिल" or "مَن".
    if (devanagariCount > 0) return LyricScript.devanagari;
    if (gurmukhiCount > 0) return LyricScript.gurmukhi;
    if (tamilCount > 0) return LyricScript.tamil;
    if (teluguCount > 0) return LyricScript.telugu;
    if (bengaliCount > 0) return LyricScript.bengali;
    if (gujaratiCount > 0) return LyricScript.gujarati;
    if (kannadaCount > 0) return LyricScript.kannada;
    if (malayalamCount > 0) return LyricScript.malayalam;
    if (odiaCount > 0) return LyricScript.odia;
    if (cyrillicCount > 0) return LyricScript.cyrillic;
    if (arabicCount > 0) return LyricScript.arabic;
    if (greekCount > 0) return LyricScript.greek;
    if (thaiCount > 0) return LyricScript.thai;
    if (hebrewCount > 0) return LyricScript.hebrew;

    return LyricScript.latin;
  }

  /// Returns contextual UI script options tailored to the detected script of the lyrics.
  static List<ScriptOption> getAvailableScriptOptions(LyricsData data) {
    final sample = data.lines.isNotEmpty ? data.lines.map((l) => l.text).take(10).join(' ') : data.plainText;
    final script = detectScript(sample);

    switch (script) {
      case LyricScript.japanese:
        return const [
          ScriptOption(code: 'original', label: 'Original (日本語)'),
          ScriptOption(code: 'roman', label: 'Romaji (Latin)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.korean:
        return const [
          ScriptOption(code: 'original', label: 'Original (한국어)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.chinese:
        return const [
          ScriptOption(code: 'original', label: 'Original (中文)'),
          ScriptOption(code: 'roman', label: 'Pinyin'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.cyrillic:
        return const [
          ScriptOption(code: 'original', label: 'Original (Русский)'),
          ScriptOption(code: 'roman', label: 'Romanized (Latin)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.arabic:
        return const [
          ScriptOption(code: 'original', label: 'Original (العربية)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.greek:
        return const [
          ScriptOption(code: 'original', label: 'Original (Ελληνικά)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ];
      case LyricScript.thai:
        return const [
          ScriptOption(code: 'original', label: 'Original (ไทย)'),
          ScriptOption(code: 'roman', label: 'Romanized (RTGS)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ];
      case LyricScript.hebrew:
        return const [
          ScriptOption(code: 'original', label: 'Original (עברית)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ];
      case LyricScript.devanagari:
        return const [
          ScriptOption(code: 'original', label: 'मूल (देवनागरी)'),
          ScriptOption(code: 'roman', label: 'Roman (English)'),
        ];
      case LyricScript.gurmukhi:
        return const [
          ScriptOption(code: 'original', label: 'ਮੂਲ (ਪੰਜਾਬੀ)'),
          ScriptOption(code: 'roman', label: 'Roman (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.tamil:
      case LyricScript.telugu:
      case LyricScript.bengali:
      case LyricScript.gujarati:
      case LyricScript.kannada:
      case LyricScript.malayalam:
      case LyricScript.odia:
        return const [
          ScriptOption(code: 'original', label: 'Original Script'),
          ScriptOption(code: 'roman', label: 'Romanized (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.latin:
        return const [
          ScriptOption(code: 'original', label: 'Original (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
    }
  }

  /// Master entry point for transliterating full synced or plain lyrics.
  static LyricsData transliterateLyrics(LyricsData lyrics, String targetScript) {
    if (targetScript == 'original' || targetScript == 'raw') return lyrics;

    final cacheKeyPrefix = 'v$_lexiconVersion:$targetScript:';
    if (lyrics.isSynced) {
      final convertedLines = lyrics.lines.map((line) {
        final cacheKey = '$cacheKeyPrefix${line.text}';
        if (_cache.containsKey(cacheKey)) {
          return LyricLine(timestamp: line.timestamp, text: _cache[cacheKey]!);
        }
        final converted = transliterateText(line.text, targetScript);
        if (_cache.length >= _maxCacheSize) _cache.remove(_cache.keys.first);
        _cache[cacheKey] = converted;
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

  /// Converts single line or text to the target script through Universal Roman intermediate representation.
  static String transliterateText(String input, String targetScript) {
    if (input.trim().isEmpty) return input;
    final clean = input.trim();
    final sourceScript = detectScript(clean);

    // 1. Convert source to Universal Latin (Roman) representation
    String romanText;
    switch (sourceScript) {
      case LyricScript.japanese:
        romanText = _japaneseToRomaji(clean);
        break;
      case LyricScript.korean:
        romanText = _koreanHangulToRoman(clean);
        break;
      case LyricScript.chinese:
        romanText = _chineseToPinyin(clean);
        break;
      case LyricScript.cyrillic:
        romanText = _cyrillicToLatin(clean);
        break;
      case LyricScript.arabic:
        romanText = _arabicToLatin(clean);
        break;
      case LyricScript.greek:
        romanText = _greekToLatin(clean);
        break;
      case LyricScript.thai:
        romanText = _thaiToLatin(clean);
        break;
      case LyricScript.hebrew:
        romanText = _hebrewToLatin(clean);
        break;
      case LyricScript.devanagari:
        romanText = _romanizer.toRomanized(clean);
        break;
      case LyricScript.gurmukhi:
        romanText = _gurmukhiToRoman(clean);
        break;
      case LyricScript.bengali:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.bengali, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.gujarati:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.gujarati, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.telugu:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.telugu, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.tamil:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.tamil, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.kannada:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.kannada, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.malayalam:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.malayalam, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.odia:
        final deva = SanscriptEngine.t(clean, SanscriptEngine.odia, SanscriptEngine.devanagari);
        romanText = _romanizer.toRomanized(deva);
        break;
      case LyricScript.latin:
        romanText = clean;
        break;
    }

    if (targetScript == 'roman' || targetScript == 'english' || targetScript == 'romaji' || targetScript == 'pinyin') {
      return romanText;
    }

    // 2. Convert from Universal Roman to Target Script
    if (targetScript == 'devanagari') {
      if (sourceScript == LyricScript.devanagari) return clean;
      if (sourceScript == LyricScript.bengali) {
        return SanscriptEngine.t(clean, SanscriptEngine.bengali, SanscriptEngine.devanagari);
      }
      if (sourceScript == LyricScript.gurmukhi) {
        return SanscriptEngine.t(clean, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari);
      }
      return DevanagariTransliterationService.toDevanagari(romanText);
    }

    return romanText;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🇯🇵 Japanese Hiragana / Katakana / Romaji Converter
  // ──────────────────────────────────────────────────────────────────────────
  static String _japaneseToRomaji(String text) {
    String processed = text
        .replaceAll('こんにちは', 'konnichiwa')
        .replaceAll('こんばんは', 'konbanwa')
        .replaceAll('コンニチハ', 'konnichiwa')
        .replaceAll('コンバンハ', 'konbanwa');

    final sb = StringBuffer();
    int i = 0;
    while (i < processed.length) {
      // Check 2-character digraphs (e.g. きゃ kya, しゃ sha, ちゃ cha)
      if (i + 1 < processed.length) {
        final pair = processed.substring(i, i + 2);
        if (_japaneseDigraphs.containsKey(pair)) {
          sb.write(_japaneseDigraphs[pair]);
          i += 2;
          continue;
        }
      }
      // Sokuon (っ / ッ) gemination
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
      // Single kana
      if (_japaneseMonographs.containsKey(ch)) {
        sb.write(_japaneseMonographs[ch]);
      } else {
        sb.write(ch);
      }
      i++;
    }
    return sb.toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🇰🇷 Korean Hangul Decomposition to Revised Romanization
  // ──────────────────────────────────────────────────────────────────────────
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

  static String _koreanHangulToRoman(String text) {
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

  // ──────────────────────────────────────────────────────────────────────────
  // 🇨🇳 Chinese Hanzi to Pinyin (Common Lyric Characters)
  // ──────────────────────────────────────────────────────────────────────────
  static String _chineseToPinyin(String text) {
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

  // ──────────────────────────────────────────────────────────────────────────
  // 🇷🇺 Cyrillic to Latin (BGN/PCGN Standard)
  // ──────────────────────────────────────────────────────────────────────────
  static String _cyrillicToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_cyrillicMap[ch] ?? ch);
    }
    return sb.toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🇸🇦 Arabic / Persian to Latin (ALA-LC Standard)
  // ──────────────────────────────────────────────────────────────────────────
  static String _arabicToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_arabicMap[ch] ?? ch);
    }
    return sb.toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🇬🇷 Greek to Latin
  // ──────────────────────────────────────────────────────────────────────────
  static String _greekToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_greekMap[ch] ?? ch);
    }
    return sb.toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🇹🇭 Thai to Latin (RTGS)
  // ──────────────────────────────────────────────────────────────────────────
  static String _thaiToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_thaiMap[ch] ?? ch);
    }
    return sb.toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🇮🇱 Hebrew to Latin
  // ──────────────────────────────────────────────────────────────────────────
  static String _hebrewToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_hebrewMap[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Punjabi-aware Romanization. The override layer handles frequent lyric
  /// spellings while the Devanagari bridge supplies a consistent offline
  /// fallback for words outside the vocabulary.
  static String _gurmukhiToRoman(String text) {
    return text.splitMapJoin(RegExp(r'\s+'), onMatch: (m) => m.group(0)!, onNonMatch: (token) {
      final leading = RegExp(r'^\p{P}+', unicode: true).stringMatch(token) ?? '';
      final trailing = RegExp(r'\p{P}+$', unicode: true).stringMatch(token) ?? '';
      if (leading.length + trailing.length >= token.length) return token;
      final core = token.substring(leading.length, token.length - trailing.length);
      if (core.isEmpty) return token;
      final override = _gurmukhiRomanOverrides[core];
      final deva = SanscriptEngine.t(core, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari);
      return '$leading${override ?? _romanizer.toRomanized(deva).toLowerCase()}$trailing';
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Comprehensive Tables
  // ──────────────────────────────────────────────────────────────────────────
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

  static const Map<String, String> _cyrillicMap = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo',
    'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
    'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
    'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
    'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
  };

  static const Map<String, String> _arabicMap = {
    'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'aa', 'ب': 'b', 'ت': 't', 'ث': 'th',
    'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z',
    'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': "'",
    'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
    'ه': 'h', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ة': 'h', 'ء': "'", 'ئ': "'",
    'ؤ': "'", 'پ': 'p', 'چ': 'ch', 'ژ': 'zh', 'گ': 'g', 'ک': 'k', 'ی': 'y',
  };

  static const Map<String, String> _greekMap = {
    'α': 'a', 'β': 'v', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'ζ': 'z', 'η': 'i',
    'θ': 'th', 'ι': 'i', 'κ': 'k', 'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x',
    'ο': 'o', 'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y',
    'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o',
    'Α': 'A', 'Β': 'V', 'Γ': 'G', 'Δ': 'D', 'Ε': 'E', 'Ζ': 'Z', 'Η': 'I',
    'Θ': 'Th', 'Ι': 'I', 'Κ': 'K', 'Λ': 'L', 'Μ': 'M', 'Ν': 'N', 'Ξ': 'X',
    'Ο': 'O', 'Π': 'P', 'Ρ': 'R', 'Σ': 'S', 'Τ': 'T', 'Υ': 'Y', 'Φ': 'F',
    'Χ': 'Ch', 'Ψ': 'Ps', 'Ω': 'O',
  };

  static const Map<String, String> _thaiMap = {
    'ก': 'k', 'ข': 'kh', 'ค': 'kh', 'ง': 'ng', 'จ': 'ch', 'ฉ': 'ch',
    'ช': 'ch', 'ซ': 's', 'ด': 'd', 'ต': 't', 'ถ': 'th', 'ท': 'th',
    'น': 'n', 'บ': 'b', 'ป': 'p', 'ผ': 'ph', 'ฝ': 'f', 'พ': 'ph',
    'ฟ': 'f', 'ม': 'm', 'ย': 'y', 'ร': 'r', 'ล': 'l', 'ว': 'w',
    'ส': 's', 'ห': 'h', 'อ': '', 'ฮ': 'h',
    'ะ': 'a', 'า': 'a', 'ิ': 'i', 'ี': 'i', 'ึ': 'ue', 'ื': 'ue',
    'ุ': 'u', 'ู': 'u', 'เ': 'e', 'แ': 'ae', 'โ': 'o', 'ใ': 'ai', 'ไ': 'ai',
  };

  static const Map<String, String> _hebrewMap = {
    'א': "'", 'ב': 'b', 'ג': 'g', 'ד': 'd', 'ה': 'h', 'ו': 'v', 'ז': 'z',
    'ח': 'ch', 'ט': 't', 'י': 'y', 'כ': 'k', 'ך': 'k', 'ל': 'l', 'מ': 'm',
    'ם': 'm', 'נ': 'n', 'ן': 'n', 'ס': 's', 'ע': "'", 'פ': 'p', 'ף': 'p',
    'צ': 'tz', 'ץ': 'tz', 'ק': 'k', 'ר': 'r', 'ש': 'sh', 'ת': 't',
  };

  static const Map<String, String> _gurmukhiRomanOverrides = {
    'ਸਾਰੇ': 'saare', 'ਰੰਗ': 'rang', 'ਵੇਖ': 'vekh', 'ਲਏ': 'lae',
    'ਹੁਣ': 'hun', 'ਕੋਈ': 'koi', 'ਨਹੀਂ': 'nahi', 'ਤੇਰੇ': 'tere',
    'ਦਿਲ': 'dil', 'ਮੇਰਾ': 'mera', 'ਤੇਰਾ': 'tera', 'ਜਾਣਾ': 'jaana',
    'ਜਾਣੀ': 'jaani', 'ਕਰਦੇ': 'karde', 'ਕਹਿੰਦੇ': 'kehnde', 'ਆਖੀਂ': 'aakheen',
    'ਸਜਣਾ': 'sajna', 'ਸਜਨਾ': 'sajna', 'ਪਿਆਰ': 'pyaar', 'ਇਸ਼ਕ': 'ishq',
    'ਵਿੱਚ': 'vich', 'ਨਾਲ': 'naal', 'ਹੈ': 'hai', 'ਸੀ': 'si',
  };
}
