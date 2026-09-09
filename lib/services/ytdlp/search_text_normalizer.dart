/// Text utilities shared by search ranking.
///
/// Provider metadata and user queries disagree in three predictable ways:
/// accented spellings (Beyoncé / Beyonce), decomposed Unicode forms that
/// split words when naive filters drop combining marks, and apostrophes
/// (Don't / Dont). Queries also contain single-letter typos. These
/// utilities normalize both sides of every comparison and provide a
/// strictly bounded fuzzy token match so none of that hides real results.
class SearchTextNormalizer {
  SearchTextNormalizer._();

  /// Lowercase, de-accented, token-safe normalization.
  ///
  /// Keeps Unicode letters/digits so Roman-Urdu, Devanagari and Arabic
  /// queries work; folds precomposed Latin diacritics to their base letter
  /// (Beyoncé → beyonce); strips combining marks instead of letting them
  /// split a word in two (NFD "café" → cafe, never "caf e"); and removes
  /// apostrophes as word-internal characters (Don't → dont).
  static String norm(String input) {
    final lowered = input.toLowerCase();
    final sb = StringBuffer();
    for (final rune in lowered.runes) {
      // Combining diacritical marks: drop silently so decomposed forms
      // normalize identically to their precomposed spellings.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      final ch = String.fromCharCode(rune);
      final folded = _latinDiacritics[ch];
      if (folded != null) {
        sb.write(folded);
        continue;
      }
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
        sb.write(ch);
      } else if (ch == "'" || ch == '\u2019') {
        // Apostrophes are word-internal: remove rather than split.
        continue;
      } else {
        sb.write(' ');
      }
    }
    final joined = sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return joined == ' ' ? '' : joined;
  }

  /// Normalized, non-empty tokens of [input].
  static List<String> tokens(String input) =>
      norm(input).split(' ').where((w) => w.isNotEmpty).toList();

  /// True when [a] and [b] differ by at most one edit (insert, delete or
  /// replace). Tokens shorter than four characters never fuzzy-match —
  /// a one-edit difference there is more likely a different word than a
  /// typo (cat/cap, run/rug).
  static bool withinOneEdit(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;
    if ((a.length - b.length).abs() > 1) return false;

    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a.codeUnitAt(i) == b.codeUnitAt(j)) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length == b.length) {
        i++;
        j++;
      } else if (a.length > b.length) {
        i++;
      } else {
        j++;
      }
    }
    // Any trailing remainder is one more insert/delete.
    if (i < a.length || j < b.length) edits++;
    return edits <= 1;
  }

  /// Precomposed Latin letters that do not survive naive ASCII filtering.
  /// Devanagari, Arabic, CJK and other scripts are untouched on purpose.
  static const Map<String, String> _latinDiacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y', 'ñ': 'n', 'ç': 'c',
    'œ': 'oe', 'æ': 'ae', 'ø': 'o', 'đ': 'd', 'ł': 'l',
    'ß': 'ss', 'š': 's', 'ž': 'z', 'ć': 'c', 'č': 'c', 'ř': 'r',
    'ě': 'e',
  };
}
