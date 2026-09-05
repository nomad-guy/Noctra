import 'dart:io';
import '../../../data/models/migration_models.dart';
import '../library_importers.dart';

/// Generic CSV importer.
class GenericCSVImporter extends LibraryImporter {
  @override
  String get sourceName => 'CSV File';

  @override
  List<String> get supportedExtensions => ['.csv'];

  @override
  bool canImport(String filePath, {String? fileContent}) =>
      filePath.toLowerCase().endsWith('.csv');

  @override
  String getInstructions() =>
      'Select a CSV file with columns like: Title, Artist, Album';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return MigrationResult(tracks: [], source: 'csv');

    final header = lines.first
        .split(',')
        .map((h) => h.trim().toLowerCase().replaceAll('"', ''))
        .toList();
    final titleIdx = header.indexWhere((h) =>
        h.contains('title') || h.contains('name') || h.contains('track'));
    final artistIdx = header
        .indexWhere((h) => h.contains('artist') || h.contains('performer'));
    final albumIdx = header.indexWhere((h) => h.contains('album'));

    final tracks = <NormalizedTrack>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (titleIdx >= 0 && cols.length > titleIdx) {
        tracks.add(NormalizedTrack(
          title: cols[titleIdx].trim(),
          artist: artistIdx >= 0 && cols.length > artistIdx
              ? cols[artistIdx].trim()
              : 'Unknown',
          album: albumIdx >= 0 && cols.length > albumIdx
              ? cols[albumIdx].trim()
              : null,
          source: 'csv',
          originalMetadata: {'raw': lines[i]},
        ));
      }
    }
    return MigrationResult(tracks: tracks, source: 'csv');
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }
}

/// M3U/M3U8 playlist importer.
class M3UImporter extends LibraryImporter {
  @override
  String get sourceName => 'M3U Playlist';

  @override
  List<String> get supportedExtensions => ['.m3u', '.m3u8'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.endsWith('.m3u') || name.endsWith('.m3u8');
  }

  @override
  String getInstructions() => 'Select an M3U or M3U8 playlist file.';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n').map((l) => l.trim()).toList();
    final tracks = <NormalizedTrack>[];
    String? playlistName;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#PLAYLIST:')) {
        playlistName = line.substring('#PLAYLIST:'.length).trim();
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        final info = line.substring('#EXTINF:'.length);
        final commaIdx = info.indexOf(',');
        if (commaIdx >= 0) {
          final artistTitle = info.substring(commaIdx + 1).trim();
          final parts = artistTitle.split(RegExp(r'\s*[-–—]\s*'));
          if (parts.length >= 2) {
            tracks.add(NormalizedTrack(
              title: parts.sublist(1).join(' - ').trim(),
              artist: parts.first.trim(),
              source: 'm3u',
              originalMetadata: {'extinf': line},
            ));
          } else {
            tracks.add(NormalizedTrack(
              title: artistTitle,
              artist: 'Unknown',
              source: 'm3u',
              originalMetadata: {'extinf': line},
            ));
          }
        }
        continue;
      }
      if (line.isNotEmpty && !line.startsWith('#')) {
        final name = line.split('/').last.split('\\').last;
        final cleanName =
            name.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ');
        if (cleanName.isNotEmpty) {
          tracks.add(NormalizedTrack(
            title: cleanName,
            artist: 'Unknown',
            source: 'm3u',
            originalMetadata: {'path': line},
          ));
        }
      }
    }

    final playlists = tracks.isNotEmpty
        ? [
            ImportedPlaylist(
              name: playlistName ?? file.path.split('/').last,
              source: 'm3u',
              tracks: tracks,
            )
          ]
        : <ImportedPlaylist>[];
    return MigrationResult(tracks: tracks, playlists: playlists, source: 'm3u');
  }
}
