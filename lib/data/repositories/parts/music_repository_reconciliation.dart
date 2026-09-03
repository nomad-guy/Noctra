part of '../music_repository.dart';

/// Mixin containing filesystem reconciliation, pruning of missing downloads,
/// cleanup of stale temp files, and recovery of orphaned audio downloads.
mixin MusicRepositoryReconciliationMixin on ChangeNotifier {
  List<Song> get _downloads;
  Set<String> get _downloadIds;
  List<Song> get _favorites;
  Map<String, List<Song>> get _customFolders;

  /// Removes downloaded entries whose backing file no longer exists (deleted
  /// out-of-band, SD-card removal, failed download cleanup) or whose path was
  /// lost. Returns how many entries were pruned. Never deletes files.
  Future<int> pruneMissingDownloadedFiles() async {
    if (_downloads.isEmpty) return 0;
    if (kIsWeb) {
      // No local filesystem on web: downloads are represented without a file
      // path by design (MusicService.downloadTrack returns isDownloaded=true
      // with no path on web). Never prune them here.
      return 0;
    }
    final stale = <String>[];
    for (final d in _downloads) {
      final path = d.localFilePath;
      if (path == null || path.isEmpty) {
        stale.add(d.id);
        continue;
      }
      try {
        if (!File(path).existsSync()) stale.add(d.id);
      } catch (_) {
        stale.add(d.id); // unreadable/invalid path — treat as missing
      }
    }
    if (stale.isEmpty) return 0;
    _downloads.removeWhere((d) => stale.contains(d.id));
    _downloadIds.removeAll(stale);

    // Mirror the removal onto favorite rows that point at now-missing files.
    var favoritesTouched = false;
    for (var i = 0; i < _favorites.length; i++) {
      final fav = _favorites[i];
      if (stale.contains(fav.id) &&
          (fav.isDownloaded || fav.localFilePath != null)) {
        _favorites[i] =
            fav.copyWith(isDownloaded: false, clearLocalFilePath: true);
        favoritesTouched = true;
      }
    }

    // Mirror onto custom folders
    var foldersTouched = false;
    _customFolders.forEach((_, songs) {
      for (var i = 0; i < songs.length; i++) {
        final s = songs[i];
        if (stale.contains(s.id) &&
            (s.isDownloaded || s.localFilePath != null)) {
          songs[i] = s.copyWith(
            isDownloaded: false,
            clearLocalFilePath: true,
          );
          foldersTouched = true;
        }
      }
    });

    NoctraLocalDatabase().saveDownloads(_downloads);
    if (favoritesTouched) {
      NoctraLocalDatabase().saveFavorites(_favorites);
    }
    if (foldersTouched) {
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
    }
    notifyListeners();
    return stale.length;
  }

  /// Removes stale temporary download `.part` files older than 5 minutes.
  Future<int> cleanStaleTemporaryFiles() async {
    if (kIsWeb) return 0;
    try {
      final musicDir = await MusicService.getMusicDirectory();
      if (!musicDir.existsSync()) return 0;
      final entities = musicDir.listSync();
      int cleaned = 0;
      final now = DateTime.now();
      for (final entity in entities) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.') && name.endsWith('.part')) {
          try {
            final stat = entity.statSync();
            if (now.difference(stat.modified).inMinutes >= 5) {
              entity.deleteSync();
              cleaned++;
            }
          } catch (_) {}
        }
      }
      return cleaned;
    } catch (e) {
      NoctraLogger.w('Error cleaning stale temp files', e);
      return 0;
    }
  }

  /// Scans music directory for valid audio files that are missing from download metadata
  /// (e.g. metadata write failed or app crashed before save), restoring them to library.
  Future<int> recoverOrphanedDownloadedFiles() async {
    if (kIsWeb) return 0;
    try {
      final musicDir = await MusicService.getMusicDirectory();
      if (!musicDir.existsSync()) return 0;
      final entities = musicDir.listSync();
      int recovered = 0;
      for (final entity in entities) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.') || name.endsWith('.part')) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (ext != '.mp3' &&
            ext != '.m4a' &&
            ext != '.aac' &&
            ext != '.flac' &&
            ext != '.opus' &&
            ext != '.ogg') {
          continue;
        }
        final path = entity.path;
        final alreadyKnown = _downloads.any((d) => d.localFilePath == path);
        if (alreadyKnown) continue;

        final base = p.basenameWithoutExtension(path);
        String title = base;
        String artist = 'Local Audio';
        if (base.contains('_')) {
          final parts = base.split('_');
          if (parts.length >= 2) {
            artist = parts[0].replaceAll('_', ' ').trim();
            title = parts.sublist(1).join(' ').trim();
          }
        } else if (base.contains(' - ')) {
          final parts = base.split(' - ');
          if (parts.length >= 2) {
            artist = parts[0].trim();
            title = parts.sublist(1).join(' ').trim();
          }
        }
        if (title.isEmpty) title = 'Recovered Track';

        final songId = 'loc_${path.hashCode.abs()}';
        final recoveredSong = Song(
          id: songId,
          title: title,
          artist: artist,
          localFilePath: path,
          isDownloaded: true,
          duration: const Duration(seconds: 180),
        );
        _downloads.add(recoveredSong);
        _downloadIds.add(songId);
        recovered++;
      }
      if (recovered > 0) {
        NoctraLocalDatabase().saveDownloads(_downloads);
      }
      return recovered;
    } catch (e) {
      NoctraLogger.w('Error recovering orphaned downloads', e);
      return 0;
    }
  }
}
