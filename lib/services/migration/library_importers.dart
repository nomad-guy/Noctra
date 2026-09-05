import 'dart:io';
import '../../data/models/migration_models.dart';
import 'importers/apple_music_importer.dart';
import 'importers/jiosaavn_importer.dart';
import 'importers/playlist_file_importers.dart';
import 'importers/spotify_importer.dart';
import 'importers/youtube_music_importer.dart';

export 'importers/apple_music_importer.dart';
export 'importers/jiosaavn_importer.dart';
export 'importers/playlist_file_importers.dart';
export 'importers/spotify_importer.dart';
export 'importers/youtube_music_importer.dart';

/// Base interface for all library importers.
abstract class LibraryImporter {
  /// Human-readable name of the source (e.g. 'Spotify', 'Apple Music').
  String get sourceName;

  /// File extensions this importer supports (e.g. ['.json', '.csv']).
  List<String> get supportedExtensions;

  /// Whether this importer can handle the given file.
  bool canImport(String filePath, {String? fileContent});

  /// Parse the file and return normalized tracks + playlists.
  Future<MigrationResult> import(File file);

  /// Instructions for the user on how to export data from this source.
  String getInstructions();
}

/// Result of an import operation.
class MigrationResult {
  final List<NormalizedTrack> tracks;
  final List<ImportedPlaylist> playlists;
  final List<ImportedListeningEvent> history;
  final String source;

  MigrationResult({
    required this.tracks,
    this.playlists = const [],
    this.history = const [],
    required this.source,
  });
}

/// Get all available importers.
List<LibraryImporter> getAllImporters() => [
      SpotifyExportImporter(),
      AppleMusicExportImporter(),
      YouTubeMusicExportImporter(),
      JioSaavnExportImporter(),
      GenericCSVImporter(),
      M3UImporter(),
    ];

/// Auto-detect the best importer for a file.
LibraryImporter? detectImporter(String filePath, {String? content}) {
  for (final importer in getAllImporters()) {
    if (importer.canImport(filePath, fileContent: content)) return importer;
  }
  return null;
}
