import 'dart:io';

import '../../data/models/migration_models.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../metadata/artist_metadata_service.dart';
import 'library_importers.dart';
import 'track_matcher.dart';

/// MigrationManager orchestrates the full import → match → import flow.
class MigrationManager {
  /// Process a file import end-to-end from a picker-provided path. The UI
  /// hands over a plain path so presentation code never imports `dart:io`.
  static Future<MigrationReport> processImportPath(
      LibraryImporter importer, String path) {
    return processImport(importer, File(path));
  }

  /// Process a file import end-to-end.
  static Future<MigrationReport> processImport(
      LibraryImporter importer, dynamic file) async {
    final result = await importer.import(file);
    final allTracks = <NormalizedTrack>[...result.tracks];
    final seenKeys = allTracks
        .map((t) => '${t.title.toLowerCase()}::${t.artist.toLowerCase()}')
        .toSet();
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
        case MatchConfidence.exact:
          exact++;
          break;
        case MatchConfidence.high:
          high++;
          break;
        case MatchConfidence.medium:
          medium++;
          break;
        case MatchConfidence.low:
          low++;
          break;
        case MatchConfidence.none:
          none++;
          break;
      }
    }

    final lookup = <String, MatchedTrack>{};
    for (final m in matched) {
      lookup['${m.imported.title.toLowerCase()}::${m.imported.artist.toLowerCase()}'] =
          m;
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
  ///
  /// Uses a single batched repository write per chunk rather than one
  /// full-list snapshot per matched track — importing 10,000 songs must not
  /// issue 10,000 serialized writes. Chunking keeps each persisted snapshot
  /// bounded while remaining crash-recoverable: already-committed chunks stay
  /// on disk, and re-running the commit is idempotent (by song ID).
  static Future<void> commitImport(List<MatchedTrack> matched,
      {bool addToFavorites = false, int chunkSize = 500}) async {
    if (!addToFavorites) return;
    final repo = MusicRepository();
    final songs = matched.map((m) => m.matchedSong).whereType<Song>().toList();
    for (var i = 0; i < songs.length; i += chunkSize) {
      final end = (i + chunkSize < songs.length) ? i + chunkSize : songs.length;
      repo.addSongsToFavorites(songs.sublist(i, end));
      await Future<void>.delayed(Duration.zero);
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

      for (final song in [...repo.favorites, ...repo.downloads]) {
        if (song.artworkUrl == null || song.artworkUrl!.isEmpty) {
          try {
            final artistMeta =
                await ArtistMetadataService.fetchArtistInfo(song.artist);
            if (artistMeta.imageUrl != null &&
                artistMeta.imageUrl!.isNotEmpty) {
              final updated = song.copyWith(artworkUrl: artistMeta.imageUrl);
              if (repo.isFavorite(song.id) ||
                  repo.downloads.any((d) => d.id == song.id)) {
                repo.updateSongMetadata(updated);
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
