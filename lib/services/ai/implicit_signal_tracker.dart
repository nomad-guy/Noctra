import 'dart:math';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/sources/noctra_sqlite_database.dart';
import 'session_context_tracker.dart';

class ImplicitSignalTracker {
  static final ImplicitSignalTracker _instance = ImplicitSignalTracker._internal();
  factory ImplicitSignalTracker() => _instance;
  ImplicitSignalTracker._internal();

  static const double tauDays = 14.0;

  void trackPlaybackEnd({
    required Song song,
    required int listenedSeconds,
    required Duration totalDuration,
  }) {
    final effectiveDur = totalDuration.inSeconds > 0
        ? totalDuration.inSeconds
        : (song.duration.inSeconds > 0 ? song.duration.inSeconds : 0);

    final bool hasValidDuration = effectiveDur > 0;
    final completion = hasValidDuration ? (listenedSeconds / effectiveDur).clamp(0.0, 1.0) : 0.5;

    double signal;
    String eventType;
    if (listenedSeconds < 10) {
      signal = -1.0; eventType = 'fast_skip';
    } else if (listenedSeconds < 30) {
      signal = -0.5; eventType = 'short_skip';
    } else if (!hasValidDuration) {
      signal = listenedSeconds >= 60 ? 0.5 : 0.2;
      eventType = 'partial_listen';
    } else if (completion < 0.5) {
      signal = 0.1; eventType = 'partial_listen';
    } else if (completion < 0.9) {
      signal = 0.4 + (completion * 0.4); eventType = 'deep_listen';
    } else {
      signal = 1.0; eventType = 'complete_listen';
    }
    _applySignal(song: song, eventType: eventType, signal: signal, completion: completion);
  }

  void trackFavorite(Song song) => _applySignal(song: song, eventType: 'favorite', signal: 3.0, completion: 1.0);
  void trackPlaylistAdd(Song song) => _applySignal(song: song, eventType: 'playlist_add', signal: 2.5, completion: 1.0);
  void trackDownload(Song song) => _applySignal(song: song, eventType: 'download', signal: 2.0, completion: 1.0);
  void trackReplay(Song song) => _applySignal(song: song, eventType: 'replay', signal: 1.2, completion: 1.0);

  // New: user searched and selected a result — strong positive signal
  void trackSearchSelect(Song song) => _applySignal(song: song, eventType: 'search_select', signal: 1.2, completion: 1.0);

  void _applySignal({
    required Song song,
    required String eventType,
    required double signal,
    required double completion,
  }) {
    try {
      // Update session tracker first (in-memory, fast)
      SessionContextTracker().recordSong(song, eventType);

      // Record in SQLite persistent telemetry
      NoctraSqliteDatabase().recordListeningEvent(
        song: song,
        eventType: eventType,
        signalScore: signal,
        completionRate: completion,
      );

      // Online gradient descent update on long-term User Taste Vector
      MusicRepository().updateTasteVector(song, eventType);
      NoctraLogger.d('ImplicitSignalTracker: $eventType ($signal) -> ${song.title}');
    } catch (e) {
      NoctraLogger.w('ImplicitSignalTracker error', e);
    }
  }

  static double calculateRecencyDecay(int eventTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffDays = (now - eventTimestamp) / (1000 * 60 * 60 * 24);
    return exp(-diffDays / tauDays).clamp(0.05, 1.0);
  }
}
