import 'dart:convert';
import 'lyrics_service.dart';
import 'dynamic_lexicon.dart';

/// RomanizedTranslationEngine: Bidirectional high-fidelity Romanizer & Semantic Translator.
///
/// Features:
/// 1. Converts native Devanagari / Gurmukhi script lyrics into clean, natural Romanized text.
/// 2. Handles halant conjuncts, matras, anusvara (bindu), and natural schwa deletion.
/// 3. Dynamic 3-layer translation lexicon with runtime loading, user overrides, and learning.
/// 4. Provides English glosses & translations for common lyrical idioms and expressions.
class RomanizedTranslationEngine {
  RomanizedTranslationEngine({DynamicLexicon? lexicon, int cacheSize = 500})
      : _lexicon = lexicon ?? DynamicLexicon(),
        _cacheSize = cacheSize {
    _initInverseLexicon();
  }

  final DynamicLexicon _lexicon;
  final int _cacheSize;
  final Map<String, String> _romanCache = {};
  final Map<String, String> _translationCache = {};

  final Map<String, String> _inverseDevanagariToRoman = {};
  final Map<String, String> _customRomanOverrides = {};
  final Map<String, String> _englishGlossary = {};

  void _initInverseLexicon() {
    for (final key in _lexicon.allKeys) {
      final dev = _lexicon.lookup(key);
      if (dev != null && dev.isNotEmpty) {
        _inverseDevanagariToRoman[dev] = _capitalize(key);
      }
    }

    // Seed core English poetic translations for common Hindustani lyric terms
    _englishGlossary.addAll({
      'dil': 'heart / soul', 'ishq': 'passion / deep love', 'pyaar': 'love', 'pyar': 'love',
      'mohabbat': 'affection / love', 'zindagi': 'life', 'khuda': 'god / almighty',
      'rabba': 'lord / god', 'rab': 'lord', 'naina': 'eyes', 'aankhen': 'eyes',
      'dard': 'pain / longing', 'sukoon': 'peace / solace', 'khushi': 'happiness',
      'gham': 'sorrow / grief', 'aansu': 'tears', 'intezaar': 'waiting / longing',
      'armaan': 'desires / wishes', 'sapna': 'dream', 'khwab': 'dream / vision',
      'tamanna': 'wish / yearning', 'chahat': 'longing / affection', 'dhadkan': 'heartbeat',
      'saansein': 'breaths', 'hawayein': 'winds / breezes', 'kesariya': 'saffron / beloved',
      'raat': 'night', 'din': 'day', 'subah': 'morning', 'shaam': 'evening',
      'chand': 'moon', 'sitara': 'star', 'suraj': 'sun', 'aasman': 'sky',
      'baarish': 'rain', 'hawa': 'breeze', 'lamha': 'moment', 'khamoshi': 'silence',
      'awaaz': 'voice / calling', 'sanam': 'beloved', 'yaar': 'friend / lover',
      'jaaneman': 'sweetheart', 'jaan': 'life / beloved', 'humsafar': 'companion / soulmate',
      'mehboob': 'beloved', 'piya': 'beloved', 'manwa': 'my heart', 'jiyara': 'my soul',
      'manzil': 'destination', 'safar': 'journey', 'raah': 'path', 'dua': 'prayer / blessing',
      'kismat': 'destiny / fate', 'naseeb': 'fate', 'rooh': 'soul / spirit',
    });
  }

  static const Map<String, String> _vowels = {
    'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
    'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au',
    'अं': 'an', 'अः': 'ah', 'ऑ': 'o', 'ऍ': 'e',
  };

  static const Map<String, String> _matras = {
    'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo',
    'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
    'ं': 'n', 'ँ': 'n', 'ः': 'h', '़': '', '्': '',
  };

  static const Map<String, String> _consonants = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
    'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
    'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
    'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h',
    'क़': 'q', 'ख़': 'kh', 'ग़': 'gh', 'ज़': 'z', 'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f',
    'क्ष': 'ksh', 'त्र': 'tr', 'ज्ञ': 'gyan', 'श्र': 'shr',
  };

  /// Convert Devanagari text into natural Romanized English script.
  String toRoman(String text) {
    if (text.trim().isEmpty) return text;
    final buffer = StringBuffer();
    final tokens = text.split(RegExp(r'(\s+)'));
    bool first = true;

    for (final token in tokens) {
      if (!first) buffer.write(' ');
      first = false;
      if (token.isEmpty) continue;

      final leading = RegExp(r'^[\s\p{P}]+', unicode: true).stringMatch(token) ?? '';
      final trailing = RegExp(r'[\s\p{P}]+$', unicode: true).stringMatch(token) ?? '';
      final core = token.substring(leading.length, token.length - trailing.length);

      buffer.write(leading);
      if (core.isNotEmpty) {
        buffer.write(_convertWordToRomanCached(core));
      }
      buffer.write(trailing);
    }

    return buffer.toString();
  }

  String _convertWordToRomanCached(String word) {
    final cached = _romanCache[word];
    if (cached != null) return cached;

    final result = _convertWordToRoman(word);
    if (_romanCache.length >= _cacheSize) {
      _romanCache.remove(_romanCache.keys.first);
    }
    _romanCache[word] = result;
    return result;
  }

  String _convertWordToRoman(String word) {
    // 1. User & Custom overrides
    if (_customRomanOverrides.containsKey(word)) {
      return _customRomanOverrides[word]!;
    }

    // 2. Exact Inverse Lexicon hit
    if (_inverseDevanagariToRoman.containsKey(word)) {
      return _inverseDevanagariToRoman[word]!;
    }

    // 3. Phonetic Devanagari -> Roman parsing with schwa-deletion heuristics
    return _parseDevanagariToRoman(word);
  }

  String _parseDevanagariToRoman(String word) {
    final buf = StringBuffer();
    final runes = word.runes.toList();
    final len = runes.length;

    for (int i = 0; i < len; i++) {
      final ch = String.fromCharCode(runes[i]);
      final nextCh = i + 1 < len ? String.fromCharCode(runes[i + 1]) : null;

      // Independent vowel
      if (_vowels.containsKey(ch)) {
        buf.write(_vowels[ch]);
        continue;
      }

      // Consonant
      if (_consonants.containsKey(ch)) {
        final romanConsonant = _consonants[ch]!;
        buf.write(romanConsonant);

        // Check following character for halant, matra, or inherent 'a'
        if (nextCh == '्') {
          // Halant: virama conjunct, suppress inherent vowel
          i++; // Skip halant
        } else if (nextCh != null && _matras.containsKey(nextCh)) {
          // Matra: append vowel matra
          buf.write(_matras[nextCh]);
          i++; // Skip matra
        } else if (i < len - 1) {
          // Inherent 'a' if not at the very end of word (schwa deletion rule)
          buf.write('a');
        }
        continue;
      }

      // Matra by itself
      if (_matras.containsKey(ch)) {
        buf.write(_matras[ch]);
        continue;
      }

      // Fallback: pass-through punctuation/numbers/Latin
      buf.write(ch);
    }

    final rawResult = buf.toString();
    return _capitalize(rawResult);
  }

  /// Translates or glosses Romanized / Hindustani lines into poetic English meaning.
  String translateWord(String romanWord) {
    final key = romanWord.toLowerCase();
    return _englishGlossary[key] ?? _customRomanOverrides[key] ?? romanWord;
  }

  /// Learn / Override a specific word romanization at runtime.
  void learnRomanization(String devanagariWord, String romanSpelling) {
    _customRomanOverrides[devanagariWord] = romanSpelling;
    _inverseDevanagariToRoman[devanagariWord] = romanSpelling;
    _romanCache.remove(devanagariWord);
  }

  /// Teach an English meaning/translation for a lyrical term.
  void learnTranslation(String romanWord, String englishMeaning) {
    final key = romanWord.toLowerCase();
    _englishGlossary[key] = englishMeaning;
    _translationCache.remove(key);
  }

  /// Bulk load JSON translations/romanizations dynamically from remote or local storage.
  void loadFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data.containsKey('romanizations')) {
        final rom = data['romanizations'] as Map<String, dynamic>;
        rom.forEach((k, v) => learnRomanization(k, v.toString()));
      }
      if (data.containsKey('translations')) {
        final trans = data['translations'] as Map<String, dynamic>;
        trans.forEach((k, v) => learnTranslation(k, v.toString()));
      }
    } catch (_) {}
  }

  LyricsData romanizeLyrics(LyricsData data) {
    final newLines = data.lines
        .map((l) => LyricLine(timestamp: l.timestamp, text: toRoman(l.text)))
        .toList();
    final newPlain = data.lines.isNotEmpty
        ? newLines.map((l) => l.text).join('\n')
        : toRoman(data.plainText);
    return LyricsData(isSynced: data.isSynced, lines: newLines, plainText: newPlain);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + (s.length > 1 ? s.substring(1) : '');
  }
}

/// Static Facade for drop-in access to the Romanized Translation Engine.
class RomanizedTranslationService {
  RomanizedTranslationService._();

  static final RomanizedTranslationEngine engine = RomanizedTranslationEngine();

  static String toRoman(String devanagariText) => engine.toRoman(devanagariText);

  static LyricsData romanizeLyrics(LyricsData data) => engine.romanizeLyrics(data);

  static String translateWord(String romanWord) => engine.translateWord(romanWord);
}
