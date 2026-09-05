import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/platform/noctra_capabilities.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../data/models/stream_metadata_model.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../data/repositories/music_repository.dart';
import '../resolvers/stream_resolver.dart';
import '../ytdlp/music_service.dart';
import '../ai/implicit_signal_tracker.dart';
import 'audio_player_models.dart';

export 'audio_player_models.dart';

part 'parts/audio_player_service_base.dart';
part 'parts/player_queue_manager.dart';
part 'parts/player_stream_resolver.dart';
part 'parts/player_crossfade_ramp.dart';
part 'parts/player_crossfade_engine.dart';
part 'parts/player_effects_and_settings.dart';
part 'parts/player_session_loader.dart';
part 'parts/player_autoplay_manager.dart';
part 'parts/player_playback_controller.dart';
part 'parts/player_lifecycle_and_session.dart';
part 'parts/player_session_restore.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AudioPlayerService — Singleton playback engine for Noctra.
///
/// Decomposed into cohesive sub-components via mixins and parts:
///   • [AudioPlayerServiceBase]      — State variables, locks, and cross-mixin contracts
///   • [PlayerQueueMixin]           — Queue manipulation, reorder, and shuffle
///   • [PlayerStreamResolverMixin]  — URL resolution, audio source, and preloading
///   • [PlayerCrossfadeRampMixin]   — Logarithmic volume ramp algorithm
///   • [PlayerCrossfadeMixin]       — Crossfade engine, auto-crossfade, and player swap
///   • [PlayerEffectsMixin]         — Equalizer, Studio Master, sleep timer, settings
///   • [PlayerSessionLoaderMixin]   — Session init, pre-buffered player handoff, URL stream loading
///   • [PlayerAutoplayMixin]        — Radio discovery, autoplay buffer, song completion
///   • [PlayerPlaybackMixin]        — Public play/pause/skip APIs and skip sequencing
///   • [PlayerLifecycleMixin]       — AudioSession, listeners, and teardown
///   • [PlayerSessionRestoreMixin]   — Last-session restore from persistence
/// ═══════════════════════════════════════════════════════════════════════════
class AudioPlayerService extends AudioPlayerServiceBase
    with
        PlayerQueueMixin,
        PlayerEffectsMixin,
        PlayerStreamResolverMixin,
        PlayerCrossfadeRampMixin,
        PlayerCrossfadeMixin,
        PlayerSessionLoaderMixin,
        PlayerAutoplayMixin,
        PlayerPlaybackMixin,
        PlayerLifecycleMixin,
        PlayerSessionRestoreMixin {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  static AudioPlayerService get instance => _instance;

  AudioPlayerService._internal() {
    _initAudioSession();
    _attachListeners();
    MusicRepository().onSongDownloadedCallback = onSongDownloaded;
  }

  /// Pure helper: current-first playback order for shuffle. The current
  /// entry is identified by queue *position* (never by Song object
  /// identity or ID), so duplicate entries survive intact.
  @visibleForTesting
  static List<Song> buildShuffledPlaybackOrder(
      List<Song> queue, int currentIndex,
      [Random? random]) {
    if (queue.isEmpty) return <Song>[];
    final currentIdx = currentIndex.clamp(0, queue.length - 1);
    final currentSong = queue[currentIdx];
    final others = <Song>[];
    for (int i = 0; i < queue.length; i++) {
      if (i != currentIdx) others.add(queue[i]);
    }
    others.shuffle(random);
    return <Song>[currentSong, ...others];
  }

  /// Pure helper: reconcile the canonical (pre-shuffle) snapshot with the
  /// live queue contents when shuffle is disabled. The snapshot is only
  /// as-of the moment shuffle was enabled — songs may have been
  /// added/removed/played since, and IDs may repeat — so a plain
  /// snapshot restore would resurrect removed songs and drop added
  /// ones. Instead reconcile by multiset:
  ///  1. walk canonical order, keeping exactly as many copies of each
  ///     ID as the live queue still contains (removals stay removed,
  ///     canonical relative order and multiplicity preserved), then
  ///  2. append surplus live entries (songs added while shuffling) in
  ///     live order, so nothing the user added ever vanishes.
  @visibleForTesting
  static List<Song> restoreCanonicalOrder(
      List<Song> canonical, List<Song> live) {
    final need = <String, int>{};
    for (final s in live) {
      need[s.id] = (need[s.id] ?? 0) + 1;
    }
    final rebuilt = <Song>[];
    for (final s in canonical) {
      final remaining = need[s.id] ?? 0;
      if (remaining > 0) {
        rebuilt.add(s);
        need[s.id] = remaining - 1;
      }
    }
    for (final s in live) {
      final remaining = need[s.id] ?? 0;
      if (remaining > 0) {
        rebuilt.add(s);
        need[s.id] = remaining - 1;
      }
    }
    return rebuilt;
  }
}
