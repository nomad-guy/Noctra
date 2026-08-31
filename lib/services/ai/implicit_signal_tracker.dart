import 'dart:math';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/sources/noctra_sqlite_database.dart';

class ImplicitSignalTracker {
  static final ImplicitSignalTracker _instance = ImplicitSignalTracker._internal();
  factory ImplicitSignalTracker() => _instance;
  ImplicitSignalTracker._internal();

  static const double tauDays = 14.0; // Half-life decay constant

  void trackPlaybackEnd({
    required Song song,
    required int listenedSeconds,
    required Duration totalDuration,
  }) {
    final durSec = totalDuration.inSeconds > 0 ? totalDuration.inSeconds : 210;
    final completion = (listenedSeconds / durSec).clamp(0.0, 1.0);

    double signal;
    String eventType;

    if (listenedSeconds < 10) {
      signal = -1.0;
      eventType = 'fast_skip';
    } else if (listenedSeconds < 30) {
      signal = -0.5;
      eventType = 'short_skip';
    } else if (completion < 0.5) {
      signal = 0.1;
      eventType = 'partial_listen';
    } else if (completion < 0.9) {
      signal = 0.4 + (completion * 0.4);
      eventType = 'deep_listen';
    } else {
      signal = 1.0;
      eventType = 'full_listen';
    }

    _applySignal(song: song, eventType: eventType, signal: signal, completion: completion);
  }

  void trackFavorite(Song song) {
    _applySignal(song: song, eventType: 'favorite', signal: 3.0, completion: 1.0);
  }

  void trackPlaylistAdd(Song song) {
    _applySignal(song: song, eventType: 'playlist_add', signal: 2.5, completion: 1.0);
  }

  void trackDownload(Song song) {
    _applySignal(song: song, eventType: 'download', signal: 2.0, completion: 1.0);
  }

  void trackReplay(Song song) {
    _applySignal(song: song, eventType: 'replay', signal: 1.5, completion: 1.0);
  }

  void _applySignal({
    required Song song,
    required String eventType,
    required double signal,
    required double completion,
  }) {
    try {
      // Record in SQLite persistent telemetry
      NoctraSqliteDatabase().recordListeningEvent(
        song: song,
        eventType: eventType,
        signalScore: signal,
        completionRate: completion,
      );

      // Online gradient descent update on User Taste Vector
      MusicRepository().updateTasteVector(song, eventType);
      NoctraLogger.d('ImplicitSignalTracker applied $eventType ($signal) to ${song.title}');
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
