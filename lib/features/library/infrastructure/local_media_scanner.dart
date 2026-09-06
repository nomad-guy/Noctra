import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../data/models/song_model.dart';

/// Scans local directories for lossless and standard audio tracks (.flac, .mp3, .wav, .m4a, .ogg).
class LocalMediaScanner {
  static const supportedExtensions = {
    '.flac', '.mp3', '.wav', '.m4a', '.aac', '.ogg', '.opus',
  };

  /// Scans [directoryPath] recursively or shallowly for compatible audio files.
  static Future<List<Song>> scanDirectory(
    String directoryPath, {
    bool recursive = true,
    int maxTracks = 500,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final songs = <Song>[];
    try {
      final entities = dir.listSync(recursive: recursive, followLinks: false);
      for (final entity in entities) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!supportedExtensions.contains(ext)) continue;

        final song = parseAudioFile(entity);
        if (song != null) {
          songs.add(song);
          if (songs.length >= maxTracks) break;
        }
      }
    } catch (e) {
      debugPrint('[LocalMediaScanner] Error scanning $directoryPath: $e');
    }
    return songs;
  }

  /// Parses a file entity into a Song instance with heuristically parsed metadata.
  static Song? parseAudioFile(File file) {
    try {
      final fileName = p.basenameWithoutExtension(file.path);
      final ext = p.extension(file.path).toLowerCase().replaceAll('.', '').toUpperCase();

      String title = fileName;
      String artist = 'Local Artist';
      String album = 'Local Storage';

      // Parse common naming patterns: "Artist - Title" or "TrackNum. Artist - Title"
      if (fileName.contains(' - ')) {
        final parts = fileName.split(' - ');
        if (parts.length >= 2) {
          var possibleArtist = parts[0].trim();
          // Remove leading track numbers like "01. " or "01 "
          possibleArtist = possibleArtist.replaceAll(RegExp(r'^\d+[\.\s_-]*'), '').trim();
          if (possibleArtist.isNotEmpty) artist = possibleArtist;
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      // Infer album name from parent folder name if available
      final parentDir = file.parent;
      final parentName = p.basename(parentDir.path);
      if (parentName.isNotEmpty && parentName != 'Music' && parentName != 'Download') {
        album = parentName;
      }

      final isLossless = ext == 'FLAC' || ext == 'WAV';
      final genre = isLossless ? 'Bit-Perfect Local Lossless' : 'Local Audio ($ext)';

      return Song(
        id: 'local_${file.path.hashCode.abs()}',
        title: title.isNotEmpty ? title : fileName,
        artist: artist,
        album: album,
        streamUrl: file.path,
        duration: const Duration(seconds: 210), // Default placeholder until probe
        genre: genre,
      );
    } catch (_) {
      return null;
    }
  }
}
