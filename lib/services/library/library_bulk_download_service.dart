import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../ytdlp/music_service.dart';

/// Sequentially downloads every song handed to it
/// ("Download full library" button in Settings > Downloads).
///
/// Design constraints:
///  - Sequential (one at a time): parallel downloads would hammer providers
///    and thrash resolver caches; ordering keeps failure recovery simple.
///  - Cancellable: the sheet exposes a Stop button; [cancel] marks the run
///    finished and the current track completes before the loop exits.
///  - Progress is a simple ChangeNotifier so the UI can bind cheaply.
class LibraryBulkDownloadService extends ChangeNotifier {
  LibraryBulkDownloadService._();
  static final LibraryBulkDownloadService instance =
      LibraryBulkDownloadService._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  int _total = 0;
  int get total => _total;

  int _completed = 0;
  int get completed => _completed;

  int _failed = 0;
  int get failed => _failed;

  String? _currentTitle;
  String? get currentTitle => _currentTitle;

  bool _cancelRequested = false;

  /// Starts a bulk download of [songs] (callers pass only tracks that are
  /// not yet downloaded). Returns immediately; progress is exposed via this
  /// notifier. Returns false when a run is already in progress.
  bool start(List<Song> songs) {
    if (_isRunning) return false;
    if (songs.isEmpty) {
      NoctraLogger.i('Bulk download: nothing left to download');
      return false;
    }
    _isRunning = true;
    _cancelRequested = false;
    _total = songs.length;
    _completed = 0;
    _failed = 0;
    _currentTitle = null;
    notifyListeners();

    NoctraLogger.i('Bulk library download started: ${songs.length} tracks');

    unawaited(_run(songs));
    return true;
  }

  Future<void> _run(List<Song> songs) async {
    for (final song in songs) {
      if (_cancelRequested) break;
      try {
        _currentTitle = song.title;
        notifyListeners();
        final result = await MusicService.downloadTrack(song);
        if (result != null) {
          _completed++;
        } else {
          _failed++;
          NoctraLogger.w('Bulk download failed: ${song.title} (${song.id})');
        }
      } catch (e) {
        _failed++;
        NoctraLogger.w('Bulk download threw for ${song.title}', e);
      }
      notifyListeners();
    }

    _currentTitle = null;
    _isRunning = false;
    NoctraLogger.i(
        'Bulk library download finished: $_completed ok, $_failed failed'
        '${_cancelRequested ? ' (cancelled)' : ''}');
    notifyListeners();
  }

  /// Requests cancellation; the in-flight track finishes, then the loop ends.
  void cancel() => _cancelRequested = true;
}
