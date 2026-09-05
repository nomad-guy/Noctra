import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/neural_recommender_engine.dart';
import '../../data/sources/noctra_sqlite_database.dart';
import '../metadata/deezer_audio_features_service.dart';
import 'knowledge_graph.dart';
import 'session_context_tracker.dart';

class ImplicitSignalTracker {
  static final ImplicitSignalTracker _instance = ImplicitSignalTracker._internal();
  factory ImplicitSignalTracker() => _instance;
  ImplicitSignalTracker._internal();

  static const double tauDays = 14.0;

  /// Synchronous counter of [trackPlaybackEnd] invocations, so widget/unit
  /// tests can assert the end-of-song signal fires exactly once per track.
  @visibleForTesting
  static int debugPlaybackEndSignals = 0;

  @visibleForTesting
  static void debugResetSignalCounters() {
    debugPlaybackEndSignals = 0;
  }

  void trackPlaybackEnd({
    required Song song,
    required int listenedSeconds,
    required Duration totalDuration,
  }) {
    debugPlaybackEndSignals++;
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
    unawaited(_applySignal(song: song, eventType: eventType, signal: signal, completion: completion));
  }

  void trackFavorite(Song song) => unawaited(_applySignal(song: song, eventType: 'favorite', signal: 3.0, completion: 1.0));
  void trackPlaylistAdd(Song song) => unawaited(_applySignal(song: song, eventType: 'playlist_add', signal: 2.5, completion: 1.0));
  void trackDownload(Song song) => unawaited(_applySignal(song: song, eventType: 'download', signal: 2.0, completion: 1.0));
  void trackReplay(Song song) => unawaited(_applySignal(song: song, eventType: 'replay', signal: 1.2, completion: 1.0));

  // New: user searched and selected a result — strong positive signal
  void trackSearchSelect(Song song) => unawaited(_applySignal(song: song, eventType: 'search_select', signal: 1.2, completion: 1.0));

  Future<void> _applySignal({
    required Song song,
    required String eventType,
    required double signal,
    required double completion,
  }) async {
    try {
      // Update session tracker first (in-memory, fast)
      SessionContextTracker().recordSong(song, eventType);

      // Fetch audio features for rich metadata
      AudioFeatures audioFeats;
      try {
        audioFeats = await DeezerAudioFeaturesService.fetchFeatures(
            song.title, song.artist);
      } catch (_) {
        audioFeats = AudioFeatures.defaults;
      }

      // Record in SQLite persistent telemetry with full per-song metadata
      NoctraSqliteDatabase().recordListeningEvent(
        song: song,
        eventType: eventType,
        signalScore: signal,
        completionRate: completion,
        audioFeaturesJson: jsonEncode({
          'energy': audioFeats.energy,
          'danceability': audioFeats.danceability,
          'valence': audioFeats.valence,
          'tempo': audioFeats.tempo,
          'acousticness': audioFeats.acousticness,
          'source': audioFeats.source,
        }),
      );

      // Online gradient descent update on long-term User Taste Vector
      MusicRepository().updateTasteVector(song, eventType);

      // Train the neural MLP on this interaction. The audio features were
      // already fetched (and cached) above — reusing them avoids a second
      // network attempt per event.
      try {
        final userVec = MusicRepository().userTasteVector;
        final session = SessionContextTracker();
        final blended = session.sessionSongCount > 3
            ? session.blendedVector(userVec)
            : userVec;
        final ctx = NeuralRecommenderEngine.buildContext(
          sessionSongCount: session.sessionSongCount,
          momentumFeatures: session.momentumFeatures,
          affinityFeatures: session.topArtistAffinityFeatures(),
        );
        NeuralRecommenderEngine.trainFromSignal(
          userVector: blended, song: song, eventType: eventType,
          contextFeatures: ctx,
          audioFeatures: audioFeats.toFeatureVector(),
        );
      } catch (_) {}

      // Update knowledge graph edges
      try {
        final kg = MusicKnowledgeGraph.instance;
        final weight = signal.abs().clamp(0.1, 3.0);
        kg.recordSongPlay(song.artist, song.genre, weight: weight);
        // Also reinforce recent artist-genre connections
        final session = SessionContextTracker();
        for (final entry in session.artistAffinity.entries) {
          if (entry.value > 0.6) {
            kg.recordSongPlay(entry.key, song.genre, weight: entry.value * 0.3);
          }
        }
      } catch (_) {}

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
