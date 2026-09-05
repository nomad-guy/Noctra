import '../../data/models/song_model.dart';

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
    'reprise', 'trap', 'drill',
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
    final qt =
        _norm(query).split(' ').where((w) => w.isNotEmpty).toList();
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
    if (q.isEmpty || t.isEmpty) return 0;
    final qt = q.split(' ').where((w) => w.isNotEmpty).toList();
    final tt = t.split(' ').where((w) => w.isNotEmpty).toList();
    if (qt.isEmpty) return 0;

    // Strong signals for exact and prefix matches.
    if (t == q) return 1.0;
    if (t.startsWith(q)) return 0.96;
    if (t.contains(q)) return 0.92;

    // Word-level overlap on the title.
    final titleMatched = qt.where((w) => tt.contains(w)).length;
    var ratio = qt.isEmpty ? 0.0 : titleMatched / qt.length;

    // Artist tokens also help when the query names the artist.
    final a = _norm(artist);
    final at = a.split(' ').where((w) => w.isNotEmpty).toList();
    if (at.isNotEmpty) {
      final artistMatched = qt.where((w) => at.contains(w)).length;
      ratio += (artistMatched / qt.length) * 0.35;
    }

    var s = ratio.clamp(0.0, 1.0);
    if (s == 0) return 0;

    // Demote edition variants the user did not ask for.
    final wantsModifier =
        modifierTags.any((m) => q.contains(m));
    if (!wantsModifier) {
      for (final m in modifierTags) {
        if (t.contains(m)) {
          s *= 0.55;
          break;
        }
      }
    }
    // Mild boost for "(Original Score)"/OST-context extras that carry an
    // exact base title match.
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
    final qt = _tokens(artistName);
    if (qt.isEmpty) return songs;
    final primary = <Song>[];
    final secondary = <Song>[];
    final seen = <String>{};
    for (final s in songs) {
      if (s.title.isEmpty) continue;
      final key = '${_norm(s.title)}\u0000${_norm(s.artist)}';
      if (!seen.add(key)) continue;
      final at = _tokens(s.artist);
      final artistHits = qt.where(at.contains).length;
      final artistIsQueried = artistHits > 0 && artistHits == qt.length;
      final mentionsInTitle = _tokens(s.title)
          .where((w) => qt.contains(w))
          .isNotEmpty;
      if (artistIsQueried) {
        primary.add(s);
      } else if (mentionsInTitle || artistHits > 0) {
        secondary.add(s);
      }
      // Rows with no relation to the queried artist are dropped.
    }
    if (primary.isEmpty && secondary.isEmpty) {
      // Nothing related surfaced; never empty a profile because of it.
      return songs;
    }
    return [..._scoredOrder(primary, artistName),
        ..._scoredOrder(secondary, artistName)];
  }

  static List<Song> _scoredOrder(List<Song> songs, String query) {
    var seq = 0;
    final scored = songs
        .map((s) =>
            (song: s, score: score(query, s.title, s.artist), seq: seq++))
        .toList();
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.seq.compareTo(b.seq); // stable within a score band
    });
    return scored.map((e) => e.song).toList();
  }

  static List<String> _tokens(String input) => _norm(input)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();

  /// Lowercase, de-accented, token-safe normalization. Keeps Unicode
  /// letters/digits so Roman-Urdu, Devanagari and Arabic queries work.
  static String _norm(String input) {
    final decomposed = input.toLowerCase();
    final sb = StringBuffer();
    for (final rune in decomposed.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
        sb.write(ch);
      } else {
        sb.write(' ');
      }
    }
    final joined = sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return joined == ' ' ? '' : joined;
  }
}
