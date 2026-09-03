import 'dart:math';
import '../../data/models/migration_models.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import 'track_normalizer.dart';

export 'migration_manager.dart';
export 'track_normalizer.dart';

/// Matches imported tracks against the app's music catalog.
class TrackMatcher {
  /// Match a list of normalized tracks against the local catalog.
  static List<MatchedTrack> matchAll(List<NormalizedTrack> tracks) {
    final repo = MusicRepository();
    final catalog = [
      ...repo.localLibrary,
      ...repo.downloads,
      ...repo.recentlyPlayed,
      ...repo.favorites,
    ];

    // Pre-index the catalog for O(1) exact and O(k) filtered lookups
    final exactMap = <String, Song>{};
    final artistMap = <String, List<Song>>{};
    final titleMap = <String, List<Song>>{};

    for (final song in catalog) {
      final sTitle = song.title.toLowerCase().trim();
      final sArtist = song.artist.toLowerCase().trim();
      final exactKey = '$sTitle\u0000$sArtist';
      exactMap.putIfAbsent(exactKey, () => song);
      artistMap.putIfAbsent(sArtist, () => <Song>[]).add(song);
      titleMap.putIfAbsent(sTitle, () => <Song>[]).add(song);
    }

    final results = <MatchedTrack>[];
    for (final track in tracks) {
      final normalized = TrackNormalizer.normalize(track);
      final match = _matchSingleIndexed(
        normalized,
        exactMap,
        artistMap,
        titleMap,
        catalog,
      );
      results.add(match);
    }
    return results;
  }

  static MatchedTrack _matchSingleIndexed(
    NormalizedTrack track,
    Map<String, Song> exactMap,
    Map<String, List<Song>> artistMap,
    Map<String, List<Song>> titleMap,
    List<Song> catalog,
  ) {
    final nTitle = track.title.toLowerCase().trim();
    final nArtist = track.artist.toLowerCase().trim();

    // 1. Exact title + artist (O(1) hash lookup)
    final exactKey = '$nTitle\u0000$nArtist';
    final exactSong = exactMap[exactKey];
    if (exactSong != null) {
      return _makeMatch(
          track, exactSong, MatchConfidence.exact, 0.98, 'title_artist_exact');
    }

    // 2. Fuzzy title match with same artist (O(k) where k is songs by this artist)
    final artistSongs = artistMap[nArtist];
    if (artistSongs != null && artistSongs.isNotEmpty) {
      for (final song in artistSongs) {
        final sTitle = song.title.toLowerCase().trim();
        if (_fuzzyMatch(nTitle, sTitle) > 0.85) {
          return _makeMatch(track, song, MatchConfidence.high, 0.90,
              'fuzzy_title_same_artist');
        }
      }
    }

    // 3. Strong title match, any artist (O(1) lookup on title)
    final titleSongs = titleMap[nTitle];
    if (titleSongs != null && titleSongs.isNotEmpty) {
      return _makeMatch(track, titleSongs.first, MatchConfidence.medium, 0.75,
          'title_exact_artist_differs');
    }

    // 4. Fuzzy title + fuzzy artist on candidate pool
    double bestScore = 0;
    Song? bestSong;
    for (final song in catalog) {
      final titleScore = _fuzzyMatch(nTitle, song.title.toLowerCase().trim());
      final artistScore =
          _fuzzyMatch(nArtist, song.artist.toLowerCase().trim());
      final combined = titleScore * 0.6 + artistScore * 0.4;
      if (combined > bestScore) {
        bestScore = combined;
        bestSong = song;
      }
    }

    if (bestScore > 0.75 && bestSong != null) {
      return _makeMatch(track, bestSong, MatchConfidence.medium,
          bestScore * 0.85, 'fuzzy_combined');
    } else if (bestScore > 0.55 && bestSong != null) {
      return _makeMatch(
          track, bestSong, MatchConfidence.low, bestScore * 0.7, 'weak_fuzzy');
    }

    // No match found
    return MatchedTrack(
        imported: track,
        confidence: MatchConfidence.none,
        score: 0,
        matchMethod: 'none');
  }

  static MatchedTrack _makeMatch(NormalizedTrack track, Song song,
      MatchConfidence conf, double score, String method) {
    return MatchedTrack(
        imported: track,
        matchedSong: song,
        confidence: conf,
        score: score,
        matchMethod: method);
  }

  /// Simple Levenshtein-based fuzzy matching.
  static double _fuzzyMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1.0;

    final lenA = a.length;
    final lenB = b.length;
    final maxLen = max(lenA, lenB);
    final distance = _levenshtein(a, b);
    return 1.0 - (distance / maxLen);
  }

  /// Memory-optimized Levenshtein using 2 flat row buffers instead of 2D matrix.
  static int _levenshtein(String a, String b) {
    final lenA = a.length;
    final lenB = b.length;
    if (lenA == 0) return lenB;
    if (lenB == 0) return lenA;

    var v0 = List<int>.generate(lenB + 1, (i) => i);
    var v1 = List<int>.filled(lenB + 1, 0);

    for (int i = 0; i < lenA; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < lenB; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final insertion = v1[j] + 1;
        final deletion = v0[j + 1] + 1;
        final substitution = v0[j] + cost;
        var minVal = insertion < deletion ? insertion : deletion;
        if (substitution < minVal) minVal = substitution;
        v1[j + 1] = minVal;
      }
      final temp = v0;
      v0 = v1;
      v1 = temp;
    }
    return v0[lenB];
  }
}
