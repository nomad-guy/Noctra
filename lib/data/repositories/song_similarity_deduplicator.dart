import 'dart:math';
import '../models/song_model.dart';

/// Neural & AI Radio candidate deduplicator.
///
/// Prevents repetitive recommendations by identifying intra-pool collisions,
/// streaming platform variants (e.g., "(Audio)", "- From Film", "Lofi Flip"),
/// and cross-source duplicates between local library, downloads, search, and radio.
class SongSimilarityDeduplicator {
  final List<Song> _accepted = [];
  final Set<String> _seenIds = {};
  final Set<String> _seedIds = {};
  final List<Song> _seeds = [];

  SongSimilarityDeduplicator({Song? seedSong, Iterable<Song>? seedSongs}) {
    if (seedSong != null) registerSeed(seedSong);
    if (seedSongs != null) registerSeeds(seedSongs);
  }

  void registerSeed(Song seed) {
    if (seed.id.isNotEmpty) _seedIds.add(seed.id);
    _seeds.add(seed);
  }

  void registerSeeds(Iterable<Song> seeds) {
    for (final s in seeds) {
      registerSeed(s);
    }
  }

  bool isDuplicate(Song candidate) {
    if (candidate.id.isNotEmpty) {
      if (_seedIds.contains(candidate.id) || _seenIds.contains(candidate.id)) {
        return true;
      }
    }
    for (final seed in _seeds) {
      if (areDuplicates(candidate, seed)) return true;
    }
    for (final accepted in _accepted) {
      if (areDuplicates(candidate, accepted)) return true;
    }
    return false;
  }

  bool addIfUnique(Song candidate) {
    if (candidate.id.isEmpty && candidate.title.trim().isEmpty) return false;
    if (isDuplicate(candidate)) return false;
    if (candidate.id.isNotEmpty) _seenIds.add(candidate.id);
    _accepted.add(candidate);
    return true;
  }

  List<Song> filterUnique(Iterable<Song> candidates) {
    final list = <Song>[];
    for (final c in candidates) {
      if (addIfUnique(c)) list.add(c);
    }
    return list;
  }

  static String normalizeTitle(String rawTitle) {
    if (rawTitle.isEmpty) return '';
    var t = rawTitle.toLowerCase();

    // 1. Remove bracketed / parenthesized metadata
    t = t.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');

    // 2. Remove dash/pipe suffixes if preceded by title
    final dashIdx = t.indexOf(RegExp(r'\s+[-–—|:]\s+'));
    if (dashIdx > 2) {
      final prefix = t.substring(0, dashIdx).trim();
      if (prefix.split(' ').where((w) => w.isNotEmpty).isNotEmpty) {
        t = prefix;
      }
    }

    // 3. Remove common YouTube/streaming noise tokens
    t = t.replaceAll(
      RegExp(
        r'\b(official|music\s+video|video|audio|lyric|lyrics|remix|lofi|slowed|reverb|hd|4k|feat|ft|full\s+song|ost|soundtrack|clean|explicit|reprise|cover|unplugged)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 4. Strip punctuation and non-alphanumeric characters
    t = t.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Set<String> extractArtistTokens(String rawArtist) {
    if (rawArtist.isEmpty) return const {};
    final lower = rawArtist.toLowerCase();
    final parts = lower.split(RegExp(r'[,&/+]|\bfeat\.?\b|\bft\.?\b|\bwith\b'));
    final result = <String>{};
    for (final p in parts) {
      final clean = p
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isNotEmpty) {
        result.add(clean);
        // Also add individual distinctive name parts for multi-word names
        for (final word in clean.split(' ')) {
          if (word.length >= 4) result.add(word);
        }
      }
    }
    return result;
  }

  static bool artistsOverlap(String artistA, String artistB) {
    if (artistA.trim().isEmpty || artistB.trim().isEmpty) return false;
    final setA = extractArtistTokens(artistA);
    final setB = extractArtistTokens(artistB);
    if (setA.isEmpty || setB.isEmpty) return false;
    if (setA.intersection(setB).isNotEmpty) return true;
    final lowA = artistA.toLowerCase().trim();
    final lowB = artistB.toLowerCase().trim();
    return lowA.contains(lowB) || lowB.contains(lowA);
  }

  static bool areDuplicates(Song a, Song b) {
    if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;

    final normA = normalizeTitle(a.title);
    final normB = normalizeTitle(b.title);
    if (normA.isEmpty || normB.isEmpty) return false;

    final digitsA = RegExp(r'\d+').allMatches(normA).map((m) => m.group(0)).toList();
    final digitsB = RegExp(r'\d+').allMatches(normB).map((m) => m.group(0)).toList();
    if (digitsA.isNotEmpty || digitsB.isNotEmpty) {
      if (digitsA.length != digitsB.length) return false;
      for (int i = 0; i < digitsA.length; i++) {
        if (digitsA[i] != digitsB[i]) return false;
      }
    }

    final hasArtistOverlap = artistsOverlap(a.artist, b.artist);

    // Exact normalized title match
    if (normA == normB) {
      // If titles are identical, check if artists overlap or title is long/distinct
      if (hasArtistOverlap) return true;
      if (a.artist.trim().isEmpty || b.artist.trim().isEmpty) return true;
      // High-distinctiveness title (e.g. 3+ words or >= 12 chars)
      if (normA.length >= 12 || normA.split(' ').length >= 3) return true;
    }

    // Token set overlap & subset detection
    final wordsA = normA.split(' ').where((w) => w.isNotEmpty).toSet();
    final wordsB = normB.split(' ').where((w) => w.isNotEmpty).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return false;

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    final jaccard = union > 0 ? intersection / union : 0.0;

    // Word subset (e.g. "Kesariya" vs "Kesariya Film Version")
    final isSubset = (wordsA.containsAll(wordsB) || wordsB.containsAll(wordsA)) &&
        intersection >= min(wordsA.length, wordsB.length);

    if (hasArtistOverlap) {
      if (jaccard >= 0.55 || (isSubset && intersection >= 1 && normA.length >= 4 && normB.length >= 4)) {
        return true;
      }
      // Edit distance on normalized strings
      if (normA.length >= 5 && normB.length >= 5) {
        final dist = _levenshtein(normA, normB);
        final maxLen = max(normA.length, normB.length);
        if (dist <= 2 || (1.0 - (dist / maxLen)) >= 0.82) return true;
      }
    } else {
      // Different artists: only declare duplicate if Jaccard is very high and title is lengthy
      if (jaccard >= 0.85 && normA.length >= 15 && wordsA.length >= 3) return true;
    }

    return false;
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
