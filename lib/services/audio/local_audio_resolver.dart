import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/models/song_model.dart';
import '../ytdlp/music_service.dart';

/// Resolves a playable local file path for a song, downloading it first
/// when needed. Used by the audio upscaler (and reusable by any other
/// feature that requires a real local file rather than a stream URL).
class LocalAudioResolver {
  LocalAudioResolver._();

  /// Returns an existing local file path for [song], or null if the song
  /// is streaming-only and download failed.
  static Future<String?> ensureLocalFile(
    Song song, {
    void Function(String message)? onStatus,
  }) async {
    // Prefer an existing local path.
    for (final c in [song.localFilePath, song.streamUrl]) {
      if (c == null || c.startsWith('http')) continue;
      if (File(c).existsSync()) return c;
    }
    // Download through the normal pipeline so the file lands in the
    // user's chosen music folder.
    onStatus?.call('Downloading track for local processing...');
    final downloaded = await MusicService.downloadTrack(song);
    final path = downloaded?.localFilePath;
    if (path == null) return null;
    if (!File(path).existsSync()) return null;
    return path;
  }

  /// True if the song is already available as a local file.
  static bool isLocal(Song song) {
    for (final c in [song.localFilePath, song.streamUrl]) {
      if (c == null || c.startsWith('http')) continue;
      if (File(c).existsSync()) return true;
    }
    return false;
  }

  @visibleForTesting
  static bool looksLikePath(String? s) =>
      s != null && !s.startsWith('http');
}
