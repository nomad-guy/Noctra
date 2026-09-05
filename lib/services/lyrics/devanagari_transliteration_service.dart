import 'dynamic_lexicon.dart';
import 'lyrics_service.dart';

part 'parts/devanagari_phonetic_tables.dart';

/// DevanagariTransliterationEngine: converts Romanized Hindustani lyrics to
/// Devanagari script using a dynamic lexicon + rule-based phonetic parser.
class DevanagariTransliterationEngine {
  DevanagariTransliterationEngine({DynamicLexicon? lexicon, int cacheSize = 500})
      : lexicon = lexicon ?? DynamicLexicon(),
        _cacheSize = cacheSize;

  final DynamicLexicon lexicon;
  final int _cacheSize;
  final Map<String, String> _cache = {};

  static bool _isDevanagari(String word) {
    for (int i = 0; i < word.length; i++) {
      final cp = word.codeUnitAt(i);
      if (cp >= 0x0900 && cp <= 0x097F) return true;
    }
    return false;
  }

  String toDevanagari(String text) {
    if (text.trim().isEmpty) return text;
    final buffer = StringBuffer();
    final tokens = text.split(RegExp(r'(\s+)'));
    bool first = true;
    for (final token in tokens) {
      if (!first) buffer.write(' ');
      first = false;
      if (token.isEmpty) continue;
      final leading =
          RegExp(r'^[\s\p{P}]+', unicode: true).stringMatch(token) ?? '';
      final trailing =
          RegExp(r'[\s\p{P}]+$', unicode: true).stringMatch(token) ?? '';
      final core =
          token.substring(leading.length, token.length - trailing.length);
      buffer.write(leading);
      if (core.isNotEmpty) {
        buffer.write(_isDevanagari(core) ? core : _convertWordCached(core));
      }
      buffer.write(trailing);
    }
    return buffer.toString();
  }

  String _convertWordCached(String word) {
    final cached = _cache[word];
    if (cached != null) return cached;

    final result = _convertWord(word);

    if (_cache.length >= _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[word] = result;
    return result;
  }

  String _convertWord(String word) {
    final exact = lexicon.lookup(word);
    if (exact != null) return exact;

    if (word.length >= 4) {
      final fuzzy = _fuzzyLookup(word.toLowerCase());
      if (fuzzy != null) return fuzzy;
    }

    return _parseRomanToDevanagari(word);
  }

  String? _fuzzyLookup(String word) {
    String? best;
    int bestDist = 2;
    for (final key in lexicon.allKeys) {
      if ((key.length - word.length).abs() > bestDist) continue;
      final lenRatio = word.length < key.length
          ? word.length / key.length
          : key.length / word.length;
      if (lenRatio < 0.6) continue;
      final dist = DevanagariPhoneticTables.levenshtein(word, key, bestDist);
      if (dist < bestDist) {
        bestDist = dist;
        best = key;
        if (bestDist == 0) break;
      }
    }
    return best == null ? null : lexicon.lookup(best);
  }

  String _parseRomanToDevanagari(String rawWord) {
    final hasRetroflexHint = DevanagariPhoneticTables.retroflexCapitals
        .any((r) => rawWord.contains(r[0]));
    final s = hasRetroflexHint ? rawWord : rawWord.toLowerCase();

    final buf = StringBuffer();
    int idx = 0;
    bool consonantPending = false;
    bool lastWasNasal = false;

    while (idx < s.length) {
      if (!consonantPending) {
        bool matchedVowel = false;
        for (final v in DevanagariPhoneticTables.initialVowels) {
          if (_startsWithCI(s, v[0], idx, caseSensitive: hasRetroflexHint)) {
            final isStandaloneFinalA =
                idx + 1 >= s.length && v[0] == 'a' && buf.isNotEmpty;
            buf.write(isStandaloneFinalA ? 'आ' : v[1]);
            idx += v[0].length;
            matchedVowel = true;
            break;
          }
        }
        if (matchedVowel) continue;
      }

      bool foundConsonant = false;

      if (hasRetroflexHint) {
        for (final rc in DevanagariPhoneticTables.retroflexCapitals) {
          if (s.startsWith(rc[0], idx)) {
            if (consonantPending) buf.write('्');
            buf.write(rc[1]);
            idx += rc[0].length;
            consonantPending = true;
            lastWasNasal = false;
            foundConsonant = true;
            break;
          }
        }
      }

      if (!foundConsonant) {
        final lowerFromHere = s.substring(idx).toLowerCase();
        for (final dg in DevanagariPhoneticTables.digraphs) {
          if (lowerFromHere.startsWith(dg[0])) {
            if (consonantPending) buf.write('्');
            buf.write(dg[1]);
            idx += dg[0].length;
            consonantPending = true;
            lastWasNasal = false;
            foundConsonant = true;
            break;
          }
        }
      }

      if (!foundConsonant) {
        final lowerFromHere = s.substring(idx).toLowerCase();
        for (final sc in DevanagariPhoneticTables.simpleConsonants) {
          if (lowerFromHere.startsWith(sc[0])) {
            final isNasal = sc[0] == 'n' || sc[0] == 'm';

            if (consonantPending && lastWasNasal && isNasal) {
              final prev = buf.toString();
              buf.clear();
              buf.write(prev.substring(0, prev.length - 1));
              buf.write('ं');
              idx += sc[0].length;
              consonantPending = true;
              lastWasNasal = false;
              foundConsonant = true;
              break;
            }

            if (consonantPending) buf.write('्');
            buf.write(sc[1]);
            idx += sc[0].length;
            consonantPending = true;
            lastWasNasal = isNasal;
            foundConsonant = true;
            break;
          }
        }
      }

      if (foundConsonant) {
        final lowerFromHere = s.substring(idx).toLowerCase();

        if (idx + 1 >= s.length &&
            lowerFromHere.startsWith('a') &&
            !lowerFromHere.startsWith('aa')) {
          buf.write('ा');
          idx += 1;
          consonantPending = false;
          lastWasNasal = false;
          continue;
        }

        bool foundMatra = false;
        for (final m in DevanagariPhoneticTables.vowelMatras) {
          if (lowerFromHere.startsWith(m[0])) {
            buf.write(m[1]);
            idx += m[0].length;
            foundMatra = true;
            lastWasNasal = false;
            break;
          }
        }
        if (foundMatra) consonantPending = false;
        continue;
      }

      if (consonantPending) {
        final lowerFromHere = s.substring(idx).toLowerCase();

        if (idx + 1 >= s.length &&
            lowerFromHere.startsWith('a') &&
            !lowerFromHere.startsWith('aa')) {
          buf.write('ा');
          idx += 1;
          consonantPending = false;
          lastWasNasal = false;
          continue;
        }

        bool foundMatra = false;
        for (final m in DevanagariPhoneticTables.vowelMatras) {
          if (lowerFromHere.startsWith(m[0])) {
            buf.write(m[1]);
            idx += m[0].length;
            foundMatra = true;
            consonantPending = false;
            lastWasNasal = false;
            break;
          }
        }
        if (foundMatra) continue;

        buf.write('्');
        consonantPending = false;
        lastWasNasal = false;
      }

      buf.write(s[idx]);
      idx++;
    }

    String result = buf.toString();
    if (result.endsWith('्')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static bool _startsWithCI(String s, String pattern, int idx,
      {required bool caseSensitive}) {
    if (caseSensitive) return s.startsWith(pattern, idx);
    if (idx + pattern.length > s.length) return false;
    return s.substring(idx, idx + pattern.length).toLowerCase() == pattern;
  }

  void learnWord(String romanWord, String devanagari) {
    lexicon.learnWord(romanWord, devanagari);
    _cache.remove(romanWord);
    _cache.remove(romanWord.toLowerCase());
  }

  void clearCache() => _cache.clear();

  LyricsData transliterateLyrics(LyricsData data, String targetScript) {
    if (targetScript == 'devanagari') {
      final newLines = data.lines
          .map((l) =>
              LyricLine(timestamp: l.timestamp, text: toDevanagari(l.text)))
          .toList();
      final newPlain = data.lines.isNotEmpty
          ? newLines.map((l) => l.text).join('\n')
          : toDevanagari(data.plainText);
      return LyricsData(
          isSynced: data.isSynced, lines: newLines, plainText: newPlain);
    }
    return data;
  }
}

/// Drop-in-compatible static facade for existing call sites.
class DevanagariTransliterationService {
  DevanagariTransliterationService._();

  static final DevanagariTransliterationEngine engine =
      DevanagariTransliterationEngine();

  static String toDevanagari(String text) => engine.toDevanagari(text);

  static LyricsData transliterateLyrics(
          LyricsData data, String targetScript) =>
      engine.transliterateLyrics(data, targetScript);
}
