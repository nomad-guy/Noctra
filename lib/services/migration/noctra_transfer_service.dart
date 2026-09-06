import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../core/platform/noctra_platform.dart';
import '../../data/models/song_model.dart';

/// Structured result from importing a Noctra manifest or external export.
class TransferImportResult {
  final String title;
  final String type; // 'playlist' or 'library'
  final List<Song> tracks;
  final Map<String, List<Song>>? folders;

  const TransferImportResult({
    required this.title,
    required this.type,
    required this.tracks,
    this.folders,
  });
}

/// Service for transferring playlists and libraries out of and into Noctra.
///
/// Supports high-fidelity JSON manifests (`.noctra.json`) and universal CSV.
class NoctraTransferService {
  static const String manifestFormat = 'noctra_manifest';
  static const int manifestVersion = 1;

  /// Serializes a playlist to Noctra Manifest JSON format.
  static String exportPlaylistToJson(String playlistName, List<Song> songs) {
    final payload = {
      'format': manifestFormat,
      'version': manifestVersion,
      'type': 'playlist',
      'title': playlistName,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'trackCount': songs.length,
      'tracks': songs.map((s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'durationMs': s.duration.inMilliseconds,
        if (s.artworkUrl != null) 'artworkUrl': s.artworkUrl,
        if (s.genre != null) 'genre': s.genre,
        if (s.mood != null) 'mood': s.mood,
      }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Serializes an entire library (custom folders + favorites) to JSON.
  static String exportLibraryToJson(
    Map<String, List<Song>> folders,
    List<Song> favorites,
  ) {
    final payload = {
      'format': manifestFormat,
      'version': manifestVersion,
      'type': 'library',
      'title': 'Noctra Library',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'favoritesCount': favorites.length,
      'favorites': favorites.map((s) => s.toMap()).toList(),
      'folders': folders.map((name, songs) => MapEntry(
            name,
            songs.map((s) => s.toMap()).toList(),
          )),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Serializes a playlist to universal CSV format.
  static String exportPlaylistToCsv(String playlistName, List<Song> songs) {
    final buffer = StringBuffer();
    buffer.writeln('Title,Artist,Album,Duration(s),SourceId,ArtworkUrl');
    for (final s in songs) {
      final title = _escapeCsv(s.title);
      final artist = _escapeCsv(s.artist);
      final album = _escapeCsv(s.album);
      final durationSec = s.duration.inSeconds;
      final id = _escapeCsv(s.id);
      final art = _escapeCsv(s.artworkUrl ?? '');
      buffer.writeln('$title,$artist,$album,$durationSec,$id,$art');
    }
    return buffer.toString();
  }

  /// Saves manifest content to the platform downloads directory.
  static Future<String> saveManifestToFile(
    String baseFileName,
    String content, {
    String extension = 'json',
  }) async {
    final dir = await NoctraPlatformContext.instance.storage.downloadsDirectory;
    final sanitized = baseFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final fullPath = p.join(dir.path, '$sanitized$ext');
    final file = File(fullPath);
    await file.writeAsString(content, flush: true);
    return fullPath;
  }

  /// Copies manifest content to the system clipboard.
  static Future<void> copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }

  /// Attempts to parse raw string content as either a Noctra JSON manifest or CSV.
  static TransferImportResult? parseManifest(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed);
        if (map is Map<String, dynamic> && map['format'] == manifestFormat) {
          final type = map['type']?.toString() ?? 'playlist';
          final title = map['title']?.toString() ?? 'Imported Playlist';

          if (type == 'library') {
            final foldersRaw = map['folders'] as Map<String, dynamic>? ?? {};
            final parsedFolders = <String, List<Song>>{};
            foldersRaw.forEach((k, v) {
              if (v is List) {
                parsedFolders[k] = v
                    .whereType<Map<String, dynamic>>()
                    .map(Song.fromMap)
                    .toList();
              }
            });
            return TransferImportResult(
              title: title,
              type: 'library',
              tracks: const [],
              folders: parsedFolders,
            );
          }

          final tracksRaw = map['tracks'] as List? ?? [];
          final songs = tracksRaw
              .whereType<Map<String, dynamic>>()
              .map(Song.fromMap)
              .toList();
          return TransferImportResult(
            title: title,
            type: 'playlist',
            tracks: songs,
          );
        }
      } catch (_) {}
    }

    // Attempt CSV parse
    final lines = trimmed.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length >= 2) {
      final header = lines.first.toLowerCase();
      if (header.contains('title') && header.contains('artist')) {
        final songs = <Song>[];
        for (int i = 1; i < lines.length; i++) {
          final cols = _parseCsvLine(lines[i]);
          if (cols.isNotEmpty && cols[0].trim().isNotEmpty) {
            final title = cols[0].trim();
            final artist = cols.length > 1 ? cols[1].trim() : 'Unknown';
            final album = cols.length > 2 && cols[2].trim().isNotEmpty
                ? cols[2].trim()
                : 'Single';
            final durSec = cols.length > 3 ? int.tryParse(cols[3].trim()) ?? 0 : 0;
            final id = cols.length > 4 && cols[4].trim().isNotEmpty
                ? cols[4].trim()
                : 'import_${title.hashCode}_${artist.hashCode}_$i';
            final art = cols.length > 5 && cols[5].trim().isNotEmpty
                ? cols[5].trim()
                : null;

            songs.add(Song(
              id: id,
              title: title,
              artist: artist,
              album: album,
              duration: Duration(seconds: durSec),
              artworkUrl: art,
            ));
          }
        }
        if (songs.isNotEmpty) {
          return TransferImportResult(
            title: 'Imported CSV Playlist',
            type: 'playlist',
            tracks: songs,
          );
        }
      }
    }

    return null;
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static List<String> _parseCsvLine(String line) {
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
