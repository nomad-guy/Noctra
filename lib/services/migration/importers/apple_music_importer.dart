import 'dart:convert';
import 'dart:io';
import '../../../data/models/migration_models.dart';
import '../library_importers.dart';

/// Apple Music / iTunes export importer (XML or JSON).
class AppleMusicExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'Apple Music';

  @override
  List<String> get supportedExtensions => ['.json', '.xml', '.csv'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.contains('apple') ||
        name.contains('itunes') ||
        name.contains('library') ||
        name.contains('playlist');
  }

  @override
  String getInstructions() => '''
Export from Apple Music:
1. Use a tool like "Apple Music Playlist Export" or "TuneMyMusic"
2. Export as JSON or CSV
3. Select the exported file
''';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final tracks = <NormalizedTrack>[];
    final playlists = <ImportedPlaylist>[];

    try {
      final data = jsonDecode(content);
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final name =
                item['name']?.toString() ?? item['trackName']?.toString();
            final artist = item['artistName']?.toString() ??
                item['artist']?.toString() ??
                '';
            if (name != null && name.isNotEmpty && artist.isNotEmpty) {
              tracks.add(NormalizedTrack(
                title: name,
                artist: artist,
                album: item['collectionName']?.toString() ??
                    item['album']?.toString(),
                duration: item['duration'] != null
                    ? Duration(milliseconds: (item['duration'] as num).toInt())
                    : null,
                source: 'apple_music',
                sourceId: item['id']?.toString(),
                originalMetadata: Map<String, dynamic>.from(item),
              ));
            }
          }
        }
      }
    } catch (_) {
      final lines = content.split('\n');
      if (lines.isNotEmpty) {
        final header = lines.first
            .split(',')
            .map((h) => h.trim().toLowerCase())
            .toList();
        final nameIdx = header
            .indexWhere((h) => h.contains('name') || h.contains('title'));
        final artistIdx = header.indexWhere((h) => h.contains('artist'));
        if (nameIdx >= 0 && artistIdx >= 0) {
          for (int i = 1; i < lines.length; i++) {
            final cols = lines[i].split(',');
            if (cols.length > nameIdx && cols.length > artistIdx) {
              tracks.add(NormalizedTrack(
                title: cols[nameIdx].trim(),
                artist: cols[artistIdx].trim(),
                source: 'apple_music',
                originalMetadata: const {},
              ));
            }
          }
        }
      }
    }
    return MigrationResult(
        tracks: tracks, playlists: playlists, source: 'apple_music');
  }
}
