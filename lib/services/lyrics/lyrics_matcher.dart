import 'lyrics_service.dart';

class LyricsMatcher {
  static bool hasDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

  static bool hasNonLatinScript(String text) => RegExp(
          r'[\u0600-\u06FF\u0750-\u077F\u0900-\u0D7F\u0E00-\u0E7F\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF\u0400-\u04FF]')
      .hasMatch(text);

  static bool isValidLyrics(String text) {
    if (text.trim().length < 20) return false;
    final printableRatio =
        text.replaceAll(RegExp(r'[\x00-\x08\x0E-\x1F]'), '').length /
            text.length;
    if (printableRatio < 0.85) return false;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final shortLines = lines.where((l) => l.trim().length <= 2).length;
      if (shortLines / lines.length > 0.3) return false;
    }
    return true;
  }

  static String sanitizeTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\|.*'), '')
        .replaceAll(
            RegExp(r'\b(feat|ft|featuring)\.?\s+.*', caseSensitive: false), '')
        .replaceAll(
            RegExp(
                r'\b(official\s+)?(music\s+)?(video|audio|lyrics?|track|hd|hq|4k)\b.*',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+-\s+.*'), '')
        .trim();
  }

  static String _normalizeForMatch(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F]'), '').trim();

  static bool titlesMatch(String a, String b) {
    final na = _normalizeForMatch(a), nb = _normalizeForMatch(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final shorter = na.length <= nb.length ? na : nb;
    final longer = na.length <= nb.length ? nb : na;
    if (shorter.length >= 7 && longer.contains(shorter)) {
      final ratio = shorter.length / longer.length;
      if (ratio > 0.35) return true;
    }
    final minLen = na.length < nb.length ? na.length : nb.length;
    final maxDist = minLen <= 8 ? 1 : minLen ~/ 3;
    if (maxDist < 1) return false;
    return levenshtein(na, nb) <= maxDist;
  }

  static bool artistMatches(String a, String b) {
    final na = _normalizeForMatch(a), nb = _normalizeForMatch(b);
    if (na.isEmpty || nb.isEmpty) return true;
    if (na == nb) return true;
    final shorter = na.length <= nb.length ? na : nb;
    final longer = na.length <= nb.length ? nb : na;
    if (longer.contains(shorter)) return true;
    return levenshtein(na, nb) <= (shorter.length ~/ 4).clamp(1, 3);
  }

  static int levenshtein(String a, String b) {
    final la = a.length, lb = b.length;
    var prev = List<int>.generate(lb + 1, (j) => j);
    for (int i = 1; i <= la; i++) {
      final curr = List<int>.filled(lb + 1, 0);
      curr[0] = i;
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = curr;
    }
    return prev[lb];
  }

  static String extractPrimaryArtist(String artist) {
    final split = artist.split(RegExp(r'[,&/]'));
    return split.isNotEmpty ? split[0].trim() : artist;
  }

  static List<LyricLine> parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final rawLine in lrc.split('\n')) {
      final match = regExp.firstMatch(rawLine);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = int.parse(msStr.length == 2 ? '${msStr}0' : msStr);
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
