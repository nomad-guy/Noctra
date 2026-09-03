import 'dart:convert';
import 'dart:io';
import '../../../data/models/migration_models.dart';
import '../library_importers.dart';

/// JioSaavn playlist/importer.
class JioSaavnExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'JioSaavn';

  @override
  List<String> get supportedExtensions => ['.json', '.csv', '.txt'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final lower = filePath.toLowerCase();
    return lower.contains('jiosaavn') || lower.contains('saavn');
  }

  @override
  String getInstructions() => '''
Import from JioSaavn:
- Export playlist data if available
- Or paste a playlist URL
- Or provide a text list of tracks (Artist - Title format)
''';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final tracks = <NormalizedTrack>[];

    try {
      final data = jsonDecode(content);
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final title =
                item['song']?.toString() ?? item['title']?.toString();
            final artist = item['singers']?.toString() ??
                item['artist']?.toString() ??
                '';
            if (title != null) {
              tracks.add(NormalizedTrack(
                title: title,
                artist: artist,
                source: 'jiosaavn',
                sourceId: item['id']?.toString(),
                originalMetadata: Map<String, dynamic>.from(item),
              ));
            }
          }
        }
      }
    } catch (_) {
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(RegExp(r'\s*[-–—]\s*'));
        if (parts.length >= 2) {
          tracks.add(NormalizedTrack(
            title: parts.sublist(1).join(' - ').trim(),
            artist: parts.first.trim(),
            source: 'jiosaavn',
            originalMetadata: {'raw': trimmed},
          ));
        } else {
          tracks.add(NormalizedTrack(
            title: trimmed,
            artist: 'Unknown',
            source: 'jiosaavn',
            originalMetadata: {'raw': trimmed},
          ));
        }
      }
    }
    return MigrationResult(tracks: tracks, source: 'jiosaavn');
  }
}
