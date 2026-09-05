import 'dart:convert';
import 'dynamic_lexicon.dart';
import 'lyrics_service.dart';
import 'universal_lyrics_transliteration_engine.dart';

part 'parts/romanized_phonetic_tables.dart';

/// RomanizedTranslationEngine: Bidirectional high-fidelity Romanizer & Semantic Translator.
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
        if (!_inverseDevanagariToRoman.containsKey(dev) ||
            (!key.contains(RegExp(r'[A-Z]')) &&
                key.length <= _inverseDevanagariToRoman[dev]!.length)) {
          _inverseDevanagariToRoman[dev] = _capitalize(key);
        }
      }
    }
    _englishGlossary.addAll(RomanizedPhoneticTables.defaultEnglishGlossary);
  }

  /// Convert Devanagari text into natural Romanized English script.
  String toRomanized(String text) => toRoman(text);
  String toRoman(String text) {
    if (text.trim().isEmpty) return text;
    return text.splitMapJoin(
      RegExp(r'\s+'),
      onMatch: (match) => match.group(0)!,
      onNonMatch: (token) {
        if (token.isEmpty) return token;
        final leading =
            RegExp(r'^[\s\p{P}]+', unicode: true).stringMatch(token) ?? '';
        final trailing =
            RegExp(r'[\s\p{P}]+$', unicode: true).stringMatch(token) ?? '';
        if (leading.length + trailing.length >= token.length) return token;
        final core =
            token.substring(leading.length, token.length - trailing.length);

        return '$leading${_convertWordToRomanCached(core)}$trailing';
      },
    );
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
    if (_customRomanOverrides.containsKey(word)) {
      return _customRomanOverrides[word]!;
    }
    if (_inverseDevanagariToRoman.containsKey(word)) {
      return _inverseDevanagariToRoman[word]!;
    }
    return _parseDevanagariToRoman(word);
  }

  String _parseDevanagariToRoman(String word) {
    final buf = StringBuffer();
    final runes = word.runes.toList();
    final len = runes.length;

    for (int i = 0; i < len; i++) {
      final ch = String.fromCharCode(runes[i]);
      var nextCh = i + 1 < len ? String.fromCharCode(runes[i + 1]) : null;

      if (RomanizedPhoneticTables.vowels.containsKey(ch)) {
        buf.write(RomanizedPhoneticTables.vowels[ch]);
        continue;
      }

      if (RomanizedPhoneticTables.consonants.containsKey(ch)) {
        var romanConsonant = RomanizedPhoneticTables.consonants[ch]!;
        if (nextCh == '़' &&
            RomanizedPhoneticTables.nuktaConsonants.containsKey(ch)) {
          romanConsonant = RomanizedPhoneticTables.nuktaConsonants[ch]!;
          i++;
          nextCh = i + 1 < len ? String.fromCharCode(runes[i + 1]) : null;
        }
        buf.write(romanConsonant);

        if (nextCh == '्') {
          i++;
        } else if (nextCh != null &&
            RomanizedPhoneticTables.nasalMarks.contains(nextCh)) {
          buf.write('a');
          buf.write(RomanizedPhoneticTables.matras[nextCh]);
          i++;
        } else if (nextCh != null &&
            RomanizedPhoneticTables.matras.containsKey(nextCh)) {
          buf.write(RomanizedPhoneticTables.matras[nextCh]);
          i++;
        } else if (i < len - 1) {
          buf.write('a');
        }
        continue;
      }

      if (RomanizedPhoneticTables.matras.containsKey(ch)) {
        buf.write(RomanizedPhoneticTables.matras[ch]);
        continue;
      }

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
    UniversalLyricsTransliterationEngine.invalidateCache();
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
    return LyricsData(
        isSynced: data.isSynced, lines: newLines, plainText: newPlain);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + (s.length > 1 ? s.substring(1) : '');
  }
}

/// Static Facade for drop-in access to the Romanized Translation Engine.
class RomanizedTranslationService {
  RomanizedTranslationService._();

  static final RomanizedTranslationEngine engine =
      RomanizedTranslationEngine();

  static String toRoman(String devanagariText) =>
      engine.toRoman(devanagariText);

  static LyricsData romanizeLyrics(LyricsData data) =>
      engine.romanizeLyrics(data);

  static String translateWord(String romanWord) =>
      engine.translateWord(romanWord);
}
