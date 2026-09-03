import 'dart:convert';
import 'dart:io';
import '../../../data/models/migration_models.dart';
import '../library_importers.dart';

/// YouTube Music / Google Takeout importer.
class YouTubeMusicExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'YouTube Music';

  @override
  List<String> get supportedExtensions => ['.json'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.contains('youtube') ||
        name.contains('takeout') ||
        name.contains('history') ||
        name.contains('library');
  }

  @override
  String getInstructions() => '''
Export from YouTube Music via Google Takeout:
1. Go to takeout.google.com
2. Select "YouTube and YouTube Music"
3. Choose "Playlists" and/or "History"
4. Export and download the ZIP
5. Select the relevant JSON files
''';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final data = jsonDecode(content);
    final tracks = <NormalizedTrack>[];
    final playlists = <ImportedPlaylist>[];

    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          final title = item['title']?.toString() ?? item['name']?.toString();
          final artist =
              item['artist']?.toString() ?? item['authors']?.toString();
          if (title != null && title.isNotEmpty) {
            tracks.add(NormalizedTrack(
              title: title,
              artist: artist ?? 'Unknown',
              source: 'youtube_music',
              sourceId: item['id']?.toString(),
              originalMetadata: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
    } else if (data is Map && data.containsKey('content')) {
      final contentItems = data['content'] as List? ?? [];
      final name = data['title']?.toString() ?? 'YouTube Playlist';
      final playlistTracks = <NormalizedTrack>[];
      for (final item in contentItems) {
        if (item is Map) {
          final title =
              item['title']?.toString() ?? item['video']?['title']?.toString();
          final artist = item['author']?.toString() ??
              item['video']?['author']?.toString();
          if (title != null) {
            playlistTracks.add(NormalizedTrack(
              title: title,
              artist: artist ?? 'Unknown',
              source: 'youtube_music',
              sourceId:
                  item['id']?.toString() ?? item['video']?['id']?.toString(),
              originalMetadata: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      if (playlistTracks.isNotEmpty) {
        playlists.add(ImportedPlaylist(
          name: name,
          source: 'youtube_music',
          tracks: playlistTracks,
        ));
        tracks.addAll(playlistTracks);
      }
    }
    return MigrationResult(
        tracks: tracks, playlists: playlists, source: 'youtube_music');
  }
}
