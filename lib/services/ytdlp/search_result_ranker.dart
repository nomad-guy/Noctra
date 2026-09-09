import '../../data/models/song_model.dart';
import 'search_text_normalizer.dart';

/// Deterministic search-result merge and ranking.
///
/// Providers each produce a bucket of results; buckets are concatenated
/// in a fixed priority order (JioSaavn → YouTube Music → iTunes →
/// LRCLIB) so network arrival order can never change the outcome, then
/// every survivor is scored for relevance against the raw query and
/// sorted most-relevant first. Exact-title matches (including
/// "(Original Score)"-style suffixes) outrank fuzzy Bollywood lookalikes;
/// remix/slowed/live variants are demoted unless the query asks for one.
class SearchResultRanker {
  static const List<String> modifierTags = [
    'remix', 'slowed', 'reverb', 'sped', 'cover', 'karaoke',
    'instrumental', 'live', 'acoustic', 'dj', 'mashup', 'loop',
    'reprise', 'trap', 'drill', 'remake', 'tribute', 'rendition',
    'originally performed', 'originally by', 'in the style of',
    'made famous by', 'piano version', 'piano cover', 'guitar cover',
    'vocal cover', 'harp', 'orchestral', 'lofi', 'lo-fi', 'bass boosted',
    'nightcore', 'parody', '1 hour', '10 hour', 'extended edit',
  ];

  /// Bucket priority: JioSaavn, YouTube Music, iTunes, LRCLIB.
  static List<Song> mergeAndRank(
      List<List<Song>> providerBuckets, String query) {
    final seenIds = <String>{};
    final seenKeys = <String>{};
    final merged = <Song>[];

    for (final bucket in providerBuckets) {
      for (final s in bucket) {
        if (s.title.isEmpty) continue;
        final hasStrongId = s.id.isNotEmpty &&
            !s.id.startsWith('lrc_') &&
            !s.id.startsWith('itunes_');
        if (hasStrongId && !seenIds.add(s.id)) continue;
        final key = '${_norm(s.title)}\u0000${_norm(s.artist)}';
        if (!seenKeys.add(key)) continue;
        merged.add(s);
      }
    }

    final scored = merged
        .asMap()
        .entries
        .map((e) => (
              song: e.value,
              score: score(query, e.value.title, e.value.artist),
              seq: e.key,
            ))
        .toList();
    // Drop zero-overlap noise (providers occasionally surface unrelated
    // rows), except for impractically short queries where exact-token
    // matching is meaningless.
    final qt = SearchTextNormalizer.tokens(query);
    final lenient = qt.length == 1 && query.trim().length <= 2;
    scored.retainWhere((e) => lenient || e.score > 0);
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.seq.compareTo(b.seq); // stable within a score band
    });
    return scored.map((e) => e.song).toList();
  }

  /// Relevance of [title]/[artist] against the typed [query] in [0, 1].
  static double score(String query, String title, String artist) {
    final q = _norm(query);
    final t = _norm(title);
    final a = _norm(artist);
    if (q.isEmpty || t.isEmpty) return 0;

    final qt = q.split(' ').where((w) => w.isNotEmpty).toList();
    final tt = t.split(' ').where((w) => w.isNotEmpty).toList();
    final at = a.split(' ').where((w) => w.isNotEmpty).toList();
    if (qt.isEmpty) return 0;

    final wantsModifier = modifierTags.any((m) => q.contains(m));

    // 1. Natural language query intent: "<Title> by <Artist>"
    if (query.toLowerCase().contains(' by ')) {
      final parts = query.split(RegExp(r'\s+by\s+', caseSensitive: false));
      if (parts.length >= 2) {
        final explicitTitle = _norm(parts[0]);
        final explicitArtist = _norm(parts.sublist(1).join(' '));

        if (explicitTitle.isNotEmpty && explicitArtist.isNotEmpty) {
          final titleExact = t == explicitTitle;
          final titlePrefix = t.startsWith(explicitTitle) || explicitTitle.startsWith(t);
          final titleContains = t.contains(explicitTitle) || explicitTitle.contains(t);

          final artistExact = a == explicitArtist;
          final artistContains = a.contains(explicitArtist) || explicitArtist.contains(a);

          if ((titleExact || titlePrefix || titleContains) && (artistExact || artistContains)) {
            var s = titleExact ? 1.0 : (titlePrefix ? 0.98 : 0.94);
            if (artistExact) s += 0.05;
            if (!wantsModifier) {
              for (final m in modifierTags) {
                if (t.contains(m)) {
                  s *= 0.35;
                  break;
                }
              }
            }
            return s.clamp(0.0, 1.0);
          } else if ((titleExact || titlePrefix) && !artistContains) {
            // Title matches, but artist is someone else (remake/cover by another person)
            var s = 0.40;
            if (!wantsModifier) {
              for (final m in modifierTags) {
                if (t.contains(m)) s *= 0.50;
              }
            }
            return s;
          }
        }
      }
    }

    // 2. Dash separated query intent: "<Artist> - <Title>" or "<Title> - <Artist>"
    if (query.contains(' - ')) {
      final parts = query.split(' - ');
      if (parts.length == 2) {
        final p1 = _norm(parts[0]);
        final p2 = _norm(parts[1]);

        final caseA = (t == p1 || t.contains(p1)) && (a == p2 || a.contains(p2));
        final caseB = (a == p1 || a.contains(p1)) && (t == p2 || t.contains(p2));

        if (caseA || caseB) {
          var s = 1.0;
          if (!wantsModifier) {
            for (final m in modifierTags) {
              if (t.contains(m)) {
                s *= 0.35;
                break;
              }
            }
          }
          return s;
        }
      }
    }

    // 3. Exact full string match
    if (t == q) return 1.0;
    if (t.startsWith(q)) return 0.96;
    if (t.contains(q)) return 0.92;

    // 4. Word-level overlap across title AND artist (one-edit typo
    // tolerance so "Beyonce"/"Beyoncé" and single-letter typos still hit).
    bool hits(List<String> haystack, String w) =>
        haystack.any((t) => _tokenEq(t, w));
    final titleMatched = qt.where((w) => hits(tt, w)).length;
    final artistMatched = qt.where((w) => hits(at, w)).length;
    final totalMatched = titleMatched + artistMatched;

    var ratio = qt.isEmpty ? 0.0 : totalMatched / qt.length;

    // Boost if query matched both the title AND the artist
    if (titleMatched > 0 && artistMatched > 0) {
      ratio *= 1.25;
    }

    var s = ratio.clamp(0.0, 1.0);
    if (s == 0) return 0;

    // Demote edition variants (remakes, covers, live, slowed) the user did not ask for
    if (!wantsModifier) {
      for (final m in modifierTags) {
        if (t.contains(m)) {
          s *= 0.35;
          break;
        }
      }
    }

    // Mild boost for "(Original Score)"/OST-context extras that carry an exact base title match
    if (s >= 0.7 && (t.contains('original score') || t.contains('ost'))) {
      s *= 1.06;
    }
    return s.clamp(0.0, 1.0);
  }

  /// Orders rows for an ARTIST-PROFILE view (not a general song search).
  ///
  /// Song search ranks purely on text relevance, so for an artist query a
  /// "(feat. Artist)" row or a lyrics re-upload whose TITLE echoes the name
  /// can outrank the artist's own recordings (their artist field is the only
  /// place the name appears). Artist profiles instead lead with rows whose
  /// ARTIST identity covers the full queried name — the artist's own
  /// releases — then rows that merely mention the artist (features, lyric
  /// videos), and drop rows with no artist/title relation to the name at
  /// all. Duplicates collapse deterministically (first occurrence wins).
  static List<Song> orderForArtistProfile(
      List<Song> songs, String artistName) {
    final qt = SearchTextNormalizer.tokens(artistName);
    if (qt.isEmpty) return songs;
    final primary = <Song>[];
    final secondary = <Song>[];
    final compilationNoise = <Song>[];
    final seen = <String>{};

    for (final s in songs) {
      if (s.title.isEmpty) continue;
      final key = '${_norm(s.title)}\u0000${_norm(s.artist)}';
      if (!seen.add(key)) continue;

      final at = SearchTextNormalizer.tokens(s.artist);
      final artistHits = qt.where((w) => at.any((t) => _tokenEq(t, w))).length;
      final artistIsQueried = artistHits > 0 && artistHits == qt.length;
      final mentionsInTitle = SearchTextNormalizer.tokens(s.title)
          .any((w) => qt.any((q) => _tokenEq(w, q)));

      // Detect compilation uploads, loop videos, or tracks where title == artist name
      final tNorm = _norm(s.title);
      final isNoise = tNorm == _norm(artistName) ||
          tNorm.contains('full album') ||
          tNorm.contains('greatest hits') ||
          tNorm.contains('best songs of') ||
          tNorm.contains('jukebox') ||
          tNorm.contains('1 hour') ||
          tNorm.contains('non stop');

      if (isNoise) {
        compilationNoise.add(s);
      } else if (artistIsQueried) {
        primary.add(s);
      } else if (mentionsInTitle || artistHits > 0) {
        secondary.add(s);
      }
    }

    if (primary.isEmpty && secondary.isEmpty) {
      return songs;
    }

    // Rank primary tracks keeping natural provider popularity, demoting remix/slowed
    final cleanPrimary = _demoteModifiers(primary);
    final cleanSecondary = _demoteModifiers(secondary);

    return [...cleanPrimary, ...cleanSecondary, ...compilationNoise];
  }

  static List<Song> _demoteModifiers(List<Song> songs) {
    final regular = <Song>[];
    final modifiers = <Song>[];
    for (final s in songs) {
      final t = _norm(s.title);
      final hasMod = modifierTags.any((m) => t.contains(m));
      if (hasMod) {
        modifiers.add(s);
      } else {
        regular.add(s);
      }
    }
    return [...regular, ...modifiers];
  }

  /// Exact or one-edit token equality (typo tolerance for artist names).

  /// Lowercase, de-accented, token-safe normalization. Kept as a thin
  /// wrapper so existing callers/tests can stay on the ranker itself.
  static String _norm(String input) => SearchTextNormalizer.norm(input);

  static bool _tokenEq(String candidate, String queryToken) =>
      candidate == queryToken ||
      SearchTextNormalizer.withinOneEdit(candidate, queryToken);
}
