import 'dart:math';
import '../../data/models/migration_models.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../metadata/artist_metadata_service.dart';
import 'library_importers.dart';

/// Normalizes imported track metadata for consistent matching.
class TrackNormalizer {
  /// Normalize a track for matching — does NOT destroy original metadata.
  static NormalizedTrack normalize(NormalizedTrack track) {
    return track.copyWith(
      title: _normalizeTitle(track.title),
      artist: _normalizeArtist(track.artist),
      album: track.album != null ? _normalizeTitle(track.album!) : null,
    );
  }

  static String _normalizeTitle(String title) {
    var s = title.trim();
    // Remove common suffixes that vary across services
    s = s.replaceAll(RegExp(r'\s*\(feat\.?\s*[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*ft\.?\s+.*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[-–—]\s*(Remaster(ed)?|Deluxe|Radio Edit|Clean|Explicit|Remix|Live|Acoustic|Version|Edit).*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[Remaster(ed)?\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\(Remaster(ed)?\)', caseSensitive: false), '');
    // Unicode normalization
    s = _normalizeUnicode(s);
    // Lowercase + collapse whitespace
    s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove punctuation except apostrophes and hyphens
    s = s.replaceAll(RegExp(r"[^\w\s'-]"), '');
    return s;
  }

  static String _normalizeArtist(String artist) {
    var s = artist.trim();
    s = s.replaceAll(RegExp(r'\s*(feat\.?|ft\.?)\s+.*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[,&/]\s+.*'), '');
    s = _normalizeUnicode(s);
    s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r"[^\w\s'-]"), '');
    return s;
  }

  static String _normalizeUnicode(String s) {
    // NFC normalization + remove diacritics
    // Simple approach: common substitutions
    s = s.replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e').replaceAll('ë', 'e');
    s = s.replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('â', 'a').replaceAll('ä', 'a');
    s = s.replaceAll('í', 'i').replaceAll('ì', 'i').replaceAll('î', 'i').replaceAll('ï', 'i');
    s = s.replaceAll('ó', 'o').replaceAll('ò', 'o').replaceAll('ô', 'o').replaceAll('ö', 'o');
    s = s.replaceAll('ú', 'u').replaceAll('ù', 'u').replaceAll('û', 'u').replaceAll('ü', 'u');
    s = s.replaceAll('ñ', 'n').replaceAll('ç', 'c').replaceAll('ß', 'ss');
    return s;
  }
}

/// Matches imported tracks against the app's music catalog.
class TrackMatcher {
  /// Match a list of normalized tracks against the local catalog.
  static List<MatchedTrack> matchAll(List<NormalizedTrack> tracks) {
    final repo = MusicRepository();
    final catalog = [...repo.localLibrary, ...repo.downloads, ...repo.recentlyPlayed];
    final results = <MatchedTrack>[];

    for (final track in tracks) {
      final normalized = TrackNormalizer.normalize(track);
      final match = _matchSingle(normalized, catalog);
      results.add(match);
    }
    return results;
  }

  static MatchedTrack _matchSingle(NormalizedTrack track, List<Song> catalog) {
    // 1. ISRC exact match
    if (track.isrc != null && track.isrc!.isNotEmpty) {
      // ISRC match — songs don't store ISRC in current model, reserved for future
    }

    // 2. Exact title + artist (normalized)
    final nTitle = track.title.toLowerCase().trim();
    final nArtist = track.artist.toLowerCase().trim();
    for (final song in catalog) {
      final sTitle = song.title.toLowerCase().trim();
      final sArtist = song.artist.toLowerCase().trim();
      if (nTitle == sTitle && nArtist == sArtist) {
        return _makeMatch(track, song, MatchConfidence.exact, 0.98, 'title_artist_exact');
      }
    }

    // 3. Fuzzy title match with same artist
    for (final song in catalog) {
      final sTitle = song.title.toLowerCase().trim();
      final sArtist = song.artist.toLowerCase().trim();
      if (sArtist == nArtist && _fuzzyMatch(nTitle, sTitle) > 0.85) {
        return _makeMatch(track, song, MatchConfidence.high, 0.90, 'fuzzy_title_same_artist');
      }
    }

    // 4. Strong title match, any artist
    for (final song in catalog) {
      final sTitle = song.title.toLowerCase().trim();
      if (nTitle == sTitle) {
        return _makeMatch(track, song, MatchConfidence.medium, 0.75, 'title_exact_artist_differs');
      }
    }

    // 5. Fuzzy title + fuzzy artist
    double bestScore = 0;
    Song? bestSong;
    for (final song in catalog) {
      final titleScore = _fuzzyMatch(nTitle, song.title.toLowerCase().trim());
      final artistScore = _fuzzyMatch(nArtist, song.artist.toLowerCase().trim());
      final combined = titleScore * 0.6 + artistScore * 0.4;
      if (combined > bestScore) {
        bestScore = combined;
        bestSong = song;
      }
    }

    if (bestScore > 0.75 && bestSong != null) {
      return _makeMatch(track, bestSong, MatchConfidence.medium, bestScore * 0.85, 'fuzzy_combined');
    } else if (bestScore > 0.55 && bestSong != null) {
      return _makeMatch(track, bestSong, MatchConfidence.low, bestScore * 0.7, 'weak_fuzzy');
    }

    // No match found
    return MatchedTrack(imported: track, confidence: MatchConfidence.none, score: 0, matchMethod: 'none');
  }

  static MatchedTrack _makeMatch(NormalizedTrack track, Song song, MatchConfidence conf, double score, String method) {
    return MatchedTrack(imported: track, matchedSong: song, confidence: conf, score: score, matchMethod: method);
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

  static int _levenshtein(String a, String b) {
    final lenA = a.length;
    final lenB = b.length;
    final dp = List.generate(lenA + 1, (i) => List<int>.filled(lenB + 1, 0));

    for (int i = 0; i <= lenA; i++) { dp[i][0] = i; }
    for (int j = 0; j <= lenB; j++) { dp[0][j] = j; }

    for (int i = 1; i <= lenA; i++) {
      for (int j = 1; j <= lenB; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[lenA][lenB];
  }
}

/// MigrationManager orchestrates the full import → match → import flow.
class MigrationManager {
  /// Process a file import end-to-end.
  static Future<MigrationReport> processImport(LibraryImporter importer, dynamic file) async {
    final result = await importer.import(file);
    // Combine standalone tracks and playlist tracks with dedup
    final allTracks = <NormalizedTrack>[...result.tracks];
    final seenKeys = allTracks.map((t) => '${t.title.toLowerCase()}::${t.artist.toLowerCase()}').toSet();
    for (final pl in result.playlists) {
      for (final t in pl.tracks) {
        final key = '${t.title.toLowerCase()}::${t.artist.toLowerCase()}';
        if (seenKeys.add(key)) {
          allTracks.add(t);
        }
      }
    }

    final matched = TrackMatcher.matchAll(allTracks);

    int exact = 0, high = 0, medium = 0, low = 0, none = 0;
    for (final m in matched) {
      switch (m.confidence) {
        case MatchConfidence.exact: exact++; break;
        case MatchConfidence.high: high++; break;
        case MatchConfidence.medium: medium++; break;
        case MatchConfidence.low: low++; break;
        case MatchConfidence.none: none++; break;
      }
    }

    final lookup = <String, MatchedTrack>{};
    for (final m in matched) {
      lookup['${m.imported.title.toLowerCase()}::${m.imported.artist.toLowerCase()}'] = m;
    }

    int fullyMatchedPlaylists = 0;
    for (final pl in result.playlists) {
      final isFull = pl.tracks.every((t) {
        final key = '${t.title.toLowerCase()}::${t.artist.toLowerCase()}';
        final m = lookup[key] ?? TrackMatcher.matchAll([t]).first;
        return m.isMatched;
      });
      if (isFull) fullyMatchedPlaylists++;
    }

    return MigrationReport(
      source: importer.sourceName,
      totalTracks: matched.length,
      exactMatches: exact,
      highMatches: high,
      mediumMatches: medium,
      lowMatches: low,
      unmatched: none,
      playlistsImported: result.playlists.length,
      playlistsFullyMatched: fullyMatchedPlaylists,
      playlists: result.playlists,
      matchedTracks: matched,
    );
  }

  /// Commit matched tracks to the local library.
  static void commitImport(List<MatchedTrack> matched, {bool addToFavorites = false}) {
    final repo = MusicRepository();
    for (final m in matched) {
      if (m.matchedSong != null) {
        if (addToFavorites && !repo.isFavorite(m.matchedSong!.id)) {
          repo.toggleFavorite(m.matchedSong!);
        }
      }
    }
  }
}

/// LibraryRefreshService handles incremental library refresh.
class LibraryRefreshService {
  static bool _isRefreshing = false;
  static bool get isRefreshing => _isRefreshing;

  /// Refresh the library — re-resolve metadata for existing tracks
  /// without wiping user data or AI taste profile.
  static Future<RefreshResult> refresh() async {
    if (_isRefreshing) return RefreshResult(alreadyRefreshing: true);
    _isRefreshing = true;

    try {
      final repo = MusicRepository();
      int updatedMetadata = 0;
      int updatedArtwork = 0;

      // Re-fetch metadata for tracks with empty artwork or generic albums
      for (final song in [...repo.favorites, ...repo.downloads]) {
        if (song.artworkUrl == null || song.artworkUrl!.isEmpty) {
          try {
            final artistMeta = await ArtistMetadataService.fetchArtistInfo(song.artist);
            if (artistMeta.imageUrl != null && artistMeta.imageUrl!.isNotEmpty) {
              final updated = song.copyWith(artworkUrl: artistMeta.imageUrl);
              if (repo.isFavorite(song.id)) {
                repo.toggleFavorite(song);
                repo.toggleFavorite(updated);
                updatedArtwork++;
                updatedMetadata++;
              }
            }
          } catch (_) {}
        }
      }

      return RefreshResult(
        updatedMetadata: updatedMetadata,
        updatedArtwork: updatedArtwork,
        timestamp: DateTime.now(),
      );
    } finally {
      _isRefreshing = false;
    }
  }
}

class RefreshResult {
  final int updatedMetadata;
  final int updatedArtwork;
  final DateTime timestamp;
  final bool alreadyRefreshing;

  RefreshResult({
    this.updatedMetadata = 0,
    this.updatedArtwork = 0,
    DateTime? timestamp,
    this.alreadyRefreshing = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
