import 'lyrics_service.dart';
import 'dynamic_lexicon.dart';

/// DevanagariTransliterationEngine: converts Romanized Hindustani lyrics to
/// Devanagari script using a dynamic lexicon + rule-based phonetic parser.
///
/// What changed vs. the original static version:
///   - Lexicon is now a [DynamicLexicon]: loadable at runtime, and the
///     engine can *learn* words (see [learnWord]) instead of only shipping
///     with a fixed word list.
///   - Fallback parser is smarter for words the lexicon has never seen:
///       * fuzzy lookup catches near-miss spellings ("pyaaar" -> "pyaar")
///       * an optional ITRANS-style capital-letter convention
///         (T/D/N/Sh) lets callers disambiguate retroflex consonants,
///         which plain lowercase Roman text can never resolve on its own
///       * word-final single "a" is treated as the long आ/ा sound, which
///         matches how Hindi/Urdu song lyrics are conventionally romanized
///         (schwa is normally dropped and not written at all — a written
///         final "a" almost always means "gaya", "hua", "dekha" etc., not
///         a short schwa)
///   - Results are memoized (small LRU) so repeated words/lines — very
///     common in song lyrics with repeating chorus — are cheap to redo,
///     which matters once this is driving live/keystroke-level UI.
class DevanagariTransliterationEngine {
  DevanagariTransliterationEngine({DynamicLexicon? lexicon, int cacheSize = 500})
      : lexicon = lexicon ?? DynamicLexicon(),
        _cacheSize = cacheSize;

  final DynamicLexicon lexicon;
  final int _cacheSize;
  final Map<String, String> _cache = {}; // simple LRU (insertion-order map)

  static final List<List<String>> _digraphs = [
    ['ksh', 'क्ष'], ['tr', 'त्र'], ['gyn', 'ज्ञ'], ['shr', 'श्र'],
    ['chh', 'छ'], ['kh', 'ख'], ['gh', 'घ'], ['ch', 'च'], ['jh', 'झ'],
    ['th', 'थ'], ['dh', 'ध'], ['ph', 'फ'], ['bh', 'भ'], ['sh', 'श'],
    ['ny', 'ञ'],
  ];

  static final List<List<String>> _simpleConsonants = [
    ['k', 'क'], ['g', 'ग'], ['j', 'ज'], ['t', 'त'], ['d', 'द'],
    ['n', 'न'], ['p', 'प'], ['f', 'फ़'], ['b', 'ब'], ['m', 'म'],
    ['y', 'य'], ['r', 'र'], ['l', 'ल'], ['v', 'व'], ['w', 'व'],
    ['s', 'स'], ['h', 'ह'], ['z', 'ज़'], ['q', 'क़'],
  ];

  // ITRANS-style capitals for sounds plain lowercase Roman can't
  // represent at all. Checked BEFORE lowercasing. Purely additive — any
  // caller not using capitals behaves exactly as before.
  static final List<List<String>> _retroflexCapitals = [
    ['Ksh', 'क्ष'], ['Tr', 'ट्र'],
    ['Th', 'ठ'], ['Dh', 'ढ'], ['Sh', 'ष'],
    ['T', 'ट'], ['D', 'ड'], ['N', 'ण'], ['R', 'ड़'],
  ];

  static final List<List<String>> _vowelMatras = [
    ['aan', 'ां'], ['oon', 'ूं'], ['een', 'ीं'], ['ain', 'ैं'], ['aun', 'ौं'],
    ['aa', 'ा'], ['ii', 'ी'], ['ee', 'ी'], ['oo', 'ू'], ['uu', 'ू'],
    ['ai', 'ै'], ['au', 'ौ'], ['ei', 'ै'],
    ['a', ''], ['i', 'ि'], ['u', 'ु'], ['e', 'े'], ['o', 'ो'],
  ];

  static final List<List<String>> _initialVowels = [
    ['aan', 'आं'], ['oon', 'ऊं'], ['een', 'ईं'], ['ain', 'ऐं'], ['aun', 'औं'],
    ['aa', 'आ'], ['ii', 'ई'], ['ee', 'ई'], ['oo', 'ऊ'], ['uu', 'ऊ'],
    ['ai', 'ऐ'], ['au', 'औ'],
    ['a', 'अ'], ['i', 'इ'], ['u', 'उ'], ['e', 'ए'], ['o', 'ओ'],
  ];

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
      final leading = RegExp(r'^[\s\p{P}]+', unicode: true).stringMatch(token) ?? '';
      final trailing = RegExp(r'[\s\p{P}]+$', unicode: true).stringMatch(token) ?? '';
      final core = token.substring(leading.length, token.length - trailing.length);
      buffer.write(leading);
      if (core.isNotEmpty) buffer.write(_isDevanagari(core) ? core : _convertWordCached(core));
      buffer.write(trailing);
    }
    return buffer.toString();
  }

  String _convertWordCached(String word) {
    final cached = _cache[word];
    if (cached != null) return cached;

    final result = _convertWord(word);

    if (_cache.length >= _cacheSize) {
      _cache.remove(_cache.keys.first); // evict oldest
    }
    _cache[word] = result;
    return result;
  }

  String _convertWord(String word) {
    // 1. Exact lexicon hit (case-insensitive).
    final exact = lexicon.lookup(word);
    if (exact != null) return exact;

    // 2. Fuzzy lexicon hit — catches near-miss spellings that are common in
    //    fan-typed/UGC lyrics ("pyaaar", "zindgi", "kabhii"). Only tried on
    //    words long enough that a 1-edit match is meaningfully close, and
    //    capped so it stays cheap even against a large lexicon.
    if (word.length >= 4) {
      final fuzzy = _fuzzyLookup(word.toLowerCase());
      if (fuzzy != null) return fuzzy;
    }

    // 3. Rule-based phonetic parse for words the lexicon has never seen.
    return _parseRomanToDevanagari(word);
  }

  String? _fuzzyLookup(String word) {
    String? best;
    int bestDist = 2; // allow up to 2-edit distance
    for (final key in lexicon.allKeys) {
      if ((key.length - word.length).abs() > bestDist) continue;
      // Require length similarity: at least 60% overlap to avoid
      // false matches like 'sang' → 'song' (different words entirely).
      final lenRatio = word.length < key.length
          ? word.length / key.length
          : key.length / word.length;
      if (lenRatio < 0.6) continue;
      final dist = _levenshtein(word, key, bestDist);
      if (dist < bestDist) {
        bestDist = dist;
        best = key;
        if (bestDist == 0) break;
      }
    }
    return best == null ? null : lexicon.lookup(best);
  }

  /// Bounded Levenshtein distance — returns early once it's clear the
  /// distance exceeds [maxDist], so this stays cheap across a big lexicon.
  static int _levenshtein(String a, String b, int maxDist) {
    if ((a.length - b.length).abs() > maxDist) return maxDist + 1;
    final la = a.length, lb = b.length;
    var prev = List<int>.generate(lb + 1, (j) => j);
    for (int i = 1; i <= la; i++) {
      final curr = List<int>.filled(lb + 1, 0);
      curr[0] = i;
      int rowMin = curr[0];
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
        if (curr[j] < rowMin) rowMin = curr[j];
      }
      if (rowMin > maxDist) return maxDist + 1;
      prev = curr;
    }
    return prev[lb];
  }

  String _parseRomanToDevanagari(String rawWord) {
    // Detect ITRANS-style retroflex capitals BEFORE lowercasing everything.
    final hasRetroflexHint = _retroflexCapitals.any((r) => rawWord.contains(r[0]));
    final s = hasRetroflexHint ? rawWord : rawWord.toLowerCase();

    final buf = StringBuffer();
    int idx = 0;
    bool consonantPending = false;
    bool lastWasNasal = false;

    while (idx < s.length) {
      // ─── Vowel handling (only when no consonant is pending) ───
      if (!consonantPending) {
        bool matchedVowel = false;
        for (final v in _initialVowels) {
          if (_startsWithCI(s, v[0], idx, caseSensitive: hasRetroflexHint)) {
            // Word-final standalone 'a' after existing content → long आ
            // (Hindi lyrics convention: a written final 'a' means 'gaya',
            // 'hua', 'dekha' etc., not a short schwa)
            final isStandaloneFinalA = idx + 1 >= s.length &&
                v[0] == 'a' && buf.isNotEmpty;
            buf.write(isStandaloneFinalA ? 'आ' : v[1]);
            idx += v[0].length;
            matchedVowel = true;
            break;
          }
        }
        if (matchedVowel) continue;
      }

      // ─── Consonant matching ───
      bool foundConsonant = false;

      // ITRANS retroflex capitals (checked first, case-sensitive)
      if (hasRetroflexHint) {
        for (final rc in _retroflexCapitals) {
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

      // Digraphs (ksh, tr, ch, sh, etc.)
      if (!foundConsonant) {
        final lowerFromHere = s.substring(idx).toLowerCase();
        for (final dg in _digraphs) {
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

      // Simple consonants (k, g, n, m, etc.)
      if (!foundConsonant) {
        final lowerFromHere = s.substring(idx).toLowerCase();
        for (final sc in _simpleConsonants) {
          if (lowerFromHere.startsWith(sc[0])) {
            final isNasal = sc[0] == 'n' || sc[0] == 'm';

            // Nasalization: nasal before consonant → anusvara (ं)
            // Replace the already-written nasal consonant in the buffer.
            if (consonantPending && lastWasNasal && isNasal) {
              // The pending consonant IS the nasal — skip it and write anusvara
              // instead. The previous consonant before the nasal already had its
              // halant written, so remove the pending nasal's Devanagari char.
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

      // ─── Post-consonant: try to consume a vowel matra ───
      if (foundConsonant) {
        final lowerFromHere = s.substring(idx).toLowerCase();

        // Word-final 'a' → long आ/ा (Hindi lyrics convention)
        if (idx + 1 >= s.length &&
            lowerFromHere.startsWith('a') && !lowerFromHere.startsWith('aa')) {
          buf.write('ा');
          idx += 1;
          consonantPending = false;
          lastWasNasal = false;
          continue;
        }

        bool foundMatra = false;
        for (final m in _vowelMatras) {
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

      // ─── Vowel after a pending consonant (matra for previous consonant) ───
      if (consonantPending) {
        final lowerFromHere = s.substring(idx).toLowerCase();

        // Word-final standalone 'a' → long ा
        if (idx + 1 >= s.length &&
            lowerFromHere.startsWith('a') && !lowerFromHere.startsWith('aa')) {
          buf.write('ा');
          idx += 1;
          consonantPending = false;
          lastWasNasal = false;
          continue;
        }

        // Try vowel matras for the pending consonant
        bool foundMatra = false;
        for (final m in _vowelMatras) {
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

        // Not a vowel — close pending consonant with halant
        buf.write('्');
        consonantPending = false;
        lastWasNasal = false;
      }

      // ─── Fallback: write character as-is ───
      buf.write(s[idx]);
      idx++;
    }

    String result = buf.toString();
    if (result.endsWith('्')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static bool _startsWithCI(String s, String pattern, int idx, {required bool caseSensitive}) {
    if (caseSensitive) return s.startsWith(pattern, idx);
    if (idx + pattern.length > s.length) return false;
    return s.substring(idx, idx + pattern.length).toLowerCase() == pattern;
  }

  /// Teach the engine a word directly (e.g. user edited a suggestion in the
  /// UI). Clears any cached (wrong) conversion for it so the fix applies
  /// immediately, including to text already on screen if you re-run it.
  void learnWord(String romanWord, String devanagari) {
    lexicon.learnWord(romanWord, devanagari);
    _cache.remove(romanWord);
    _cache.remove(romanWord.toLowerCase());
  }

  void clearCache() => _cache.clear();

  LyricsData transliterateLyrics(LyricsData data, String targetScript) {
    if (targetScript == 'devanagari') {
      final newLines = data.lines
          .map((l) => LyricLine(timestamp: l.timestamp, text: toDevanagari(l.text)))
          .toList();
      final newPlain = data.lines.isNotEmpty
          ? newLines.map((l) => l.text).join('\n')
          : toDevanagari(data.plainText);
      return LyricsData(isSynced: data.isSynced, lines: newLines, plainText: newPlain);
    }
    return data;
  }
}

/// Drop-in-compatible static facade for existing call sites
/// (`DevanagariTransliterationService.toDevanagari(...)`,
/// `.transliterateLyrics(...)`). Delegates to a shared engine instance so
/// existing code needs zero changes, while `engine` exposes the new dynamic
/// features (loading a lexicon at runtime, learning words, live use) to
/// anywhere that wants them.
class DevanagariTransliterationService {
  DevanagariTransliterationService._();

  static final DevanagariTransliterationEngine engine = DevanagariTransliterationEngine();

  static String toDevanagari(String text) => engine.toDevanagari(text);

  static LyricsData transliterateLyrics(LyricsData data, String targetScript) =>
      engine.transliterateLyrics(data, targetScript);
}
