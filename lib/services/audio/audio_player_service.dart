import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../data/models/stream_metadata_model.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../data/repositories/music_repository.dart';
import '../resolvers/stream_resolver.dart';
import '../ytdlp/music_service.dart';
import '../ai/implicit_signal_tracker.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  static AudioPlayerService get instance => _instance;

  /// Primary player — mutable so crossfade can swap the active player.
  AudioPlayer _player = AudioPlayer(maxSkipsOnError: 6);
  AudioPlayer get player => _player;

  /// Secondary player used during crossfade transitions.
  AudioPlayer? _crossfadePlayer;

  /// Pre-resolved URL for the next track.
  String? _preloadedNextUrl;
  Song? _preloadedNextSong;
  bool _preloading = false;
  final List<Song> _queue = [];
  List<Song> get queue => List.unmodifiable(_queue);
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  Song? _currentSong;
  Song? get currentSong => _currentSong;

  final _currentSongController = StreamController<Song?>.broadcast();
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  final _queueController = StreamController<List<Song>>.broadcast();
  Stream<List<Song>> get queueStream => _queueController.stream;
  final _resolutionController =
      StreamController<StreamResolutionMetadata>.broadcast();
  Stream<StreamResolutionMetadata> get resolutionStream =>
      _resolutionController.stream;
  final _playbackSettingsController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get playbackSettingsStream =>
      _playbackSettingsController.stream;

  bool _isShuffleEnabled = false,
      _isAutoplayEnabled = true,
      _isFadeEnabled = false,
      _isFading = false,
      _skipInFlight = false;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isAutoplayEnabled => _isAutoplayEnabled;
  bool get isFadeEnabled => _isFadeEnabled;
  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;
  int _autoplayDelaySeconds = 0;
  int get autoplayDelaySeconds => _autoplayDelaySeconds;
  int _crossfadeSeconds = 3;
  int get crossfadeSeconds => _crossfadeSeconds;
  int? _sleepTimerRemainingMinutes;
  int? get sleepTimerRemainingMinutes => _sleepTimerRemainingMinutes;
  Timer? _sleepTimer;
  DateTime? _songStartTime;
  Duration? _lastSavedPosition;
  String? _lastSavedSongId;
  StreamResolutionMetadata? _lastResolution;
  StreamResolutionMetadata? get lastResolution => _lastResolution;
  int _lastSavedSec = 0, _playSessionEpoch = 0;
  bool _restoredPositionUsed = false;
  int _positionSaveEpoch = 0;
  String _studioMasterMode = 'lossless320';
  static const int _maxAutomaticRecoveryAttempts = 2;
  final Map<int, int> _recoveryAttemptsByEpoch = {};

  /// Transition epoch — incremented on every track change / crossfade start.
  /// Fade loops check this to abort stale volume ramps.
  int _transitionEpoch = 0;

  /// Whether a crossfade transition is currently in progress.
  bool _crossfading = false;

  AudioPlayerService._internal() {
    _initAudioSession();
    _attachListeners(_player);
  }

  /// Attach all playback listeners to the given player.
  void _attachListeners(AudioPlayer p) {
    p.playerStateStream.listen((s) {
      // Only handle completion for the current primary player
      if (identical(p, _player) && s.processingState == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
    p.errorStream.listen((e) {
      if (!identical(p, _player)) return; // Ignore errors from old crossfade player
      NoctraLogger.e('AudioPlayer error: ${e.toString()}', e);
      final active = _currentSong;
      if (active != null) {
        final epoch = _playSessionEpoch;
        final attempts = _recoveryAttemptsByEpoch[epoch] ?? 0;
        if (attempts >= _maxAutomaticRecoveryAttempts) {
          NoctraLogger.w(
              'AudioPlayer recovery limit reached for "${active.title}"', e);
          return;
        }
        _recoveryAttemptsByEpoch[epoch] = attempts + 1;
        final pos = _player.position;
        CompositeStreamResolver.invalidateCache(active.id);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_playSessionEpoch == epoch && _currentSong?.id == active.id) {
            playSong(active, initialPosition: pos);
          }
        });
      }
    });
    p.positionStream.listen((pos) {
      if (!identical(p, _player)) return; // Ignore position from old player
      if (_playSessionEpoch != _positionSaveEpoch) return;
      final activeSong = _currentSong;
      if (activeSong != null &&
          _loopMode != LoopMode.one &&
          pos.inSeconds >= 5 &&
          pos.inSeconds != _lastSavedSec &&
          pos.inSeconds % 5 == 0) {
        _lastSavedSec = pos.inSeconds;
        if (_restoredPositionUsed && pos.inSeconds < 15) return;
        _restoredPositionUsed = false;
        NoctraLocalDatabase()
            .savePlaybackPosition(activeSong, pos.inMilliseconds);
      }
      // Check for auto-crossfade trigger
      _checkAutoCrossfade(pos);
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  void setAutoplayDelay(int sec) {
    _autoplayDelaySeconds = sec;
    _emitSettings();
  }

  void setCrossfadeSeconds(int sec) {
    _crossfadeSeconds = sec;
    _emitSettings();
  }

  void toggleFade(bool enable) {
    _isFadeEnabled = enable;
    _emitSettings();
  }

  void cancelSleepTimer() => setSleepTimer(0);

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (_isFading) {
      _isFading = false;
      _player.setVolume(1.0);
    }
    if (minutes <= 0) {
      _sleepTimerRemainingMinutes = null;
      _emitSettings();
      return;
    }
    _sleepTimerRemainingMinutes = minutes;
    _emitSettings();
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) async {
      if (_sleepTimerRemainingMinutes != null &&
          _sleepTimerRemainingMinutes! > 1) {
        _sleepTimerRemainingMinutes = _sleepTimerRemainingMinutes! - 1;
        _emitSettings();
      } else {
        t.cancel();
        _sleepTimerRemainingMinutes = null;
        _emitSettings();
        _isFading = true;
        for (int i = 10; i >= 0; i--) {
          if (!_isFading) break;
          await _player.setVolume(i / 10.0);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isFading) {
          await _player.pause();
          _isFading = false;
        }
        await _player.setVolume(1.0);
      }
    });
  }

  // ── Fade / Crossfade helpers ──

  /// Fade volume from 0 to 1 with transition epoch guard.
  Future<void> _fadeIn({Duration? duration}) async {
    if (!_isFadeEnabled) return;
    final dur = duration ?? const Duration(milliseconds: 400);
    const steps = 20;
    final stepDelay = Duration(
        milliseconds: (dur.inMilliseconds / steps).round().clamp(10, 200));
    final epoch = _transitionEpoch;
    for (var i = 1; i <= steps; i++) {
      if (_transitionEpoch != epoch) return; // Abort if track changed
      await _player.setVolume(i / steps);
      await Future.delayed(stepDelay);
    }
  }

  /// Crossfade from current primary player to [nextPlayer] over [_crossfadeSeconds].
  /// Returns the next player (now audible).
  Future<AudioPlayer> _crossfadeTo(
      AudioPlayer nextPlayer, Song nextSong) async {
    final duration = Duration(seconds: _crossfadeSeconds);
    const steps = 30;
    final stepDelay = Duration(
        milliseconds: (duration.inMilliseconds / steps).round().clamp(10, 200));
    final epoch = _transitionEpoch;

    await nextPlayer.setVolume(0.0);
    await nextPlayer.play();

    for (var i = 1; i <= steps; i++) {
      if (_transitionEpoch != epoch) {
        // Transition cancelled — stop crossfade
        await nextPlayer.setVolume(1.0);
        return nextPlayer;
      }
      final progress = i / steps;
      await Future.wait([
        _player.setVolume(1.0 - progress),
        nextPlayer.setVolume(progress),
      ]);
      await Future.delayed(stepDelay);
    }

    // Stop old player
    try {
      await _player.stop();
    } catch (_) {}

    return nextPlayer;
  }

  /// Check if we should auto-crossfade based on playback position.
  /// Triggers when position >= duration - crossfadeDuration.
  void _checkAutoCrossfade(Duration pos) {
    if (_crossfading) return;
    if (!_isFadeEnabled || _crossfadeSeconds <= 0) return;
    if (_loopMode == LoopMode.one) return; // Don't crossfade on loop-one

    final duration = _player.duration;
    if (duration == null) return;

    final crossfadeDur = Duration(seconds: _crossfadeSeconds);
    final triggerPoint = duration - crossfadeDur;

    if (pos < triggerPoint) return;

    // Trigger auto-crossfade
    _crossfading = true;
    _autoCrossfadeNext().whenComplete(() => _crossfading = false);
  }

  /// Auto-crossfade to next track when approaching end of current track.
  Future<void> _autoCrossfadeNext() async {
    final epoch = _playSessionEpoch;
    if (epoch != _playSessionEpoch) return;

    // Determine next song
    Song? nextSong;
    if (_currentIndex < _queue.length - 1) {
      nextSong = _queue[_currentIndex + 1];
    } else if (_isAutoplayEnabled && _currentSong != null) {
      // Need to fetch more tracks
      final similar = await MusicService.fetchSimilarRadioQueue(_currentSong!);
      if (similar.isNotEmpty && epoch == _playSessionEpoch) {
        for (final s in similar) {
          if (!_queue.any((q) => q.id == s.id)) _queue.add(s);
        }
        _queueController.add(_queue);
        nextSong = _queue[_currentIndex + 1];
      }
    }

    if (nextSong == null) return;

    try {
      final url = await _resolveUrl(nextSong);
      if (url.isEmpty || epoch != _playSessionEpoch) return;

      _crossfadePlayer ??= AudioPlayer(maxSkipsOnError: 6);
      final nextPlayer = _crossfadePlayer!;

      final mediaItem = _createMediaItem(nextSong);
      final src = url.startsWith('http')
          ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
          : AudioSource.file(url, tag: mediaItem);

      await nextPlayer.setAudioSource(src);
      await nextPlayer.setVolume(0.0);

      final fadedPlayer = await _crossfadeTo(nextPlayer, nextSong);

      // Real swap: reassign _player, reattach listeners
      _performSwap(fadedPlayer);

      _currentIndex++;
      _currentSong = nextSong;
      _songStartTime = DateTime.now();
      _currentSongController.add(nextSong);
      MusicRepository().recordSongPlayed(nextSong);

      // Start preloading next-next track
      _startPreloadNext();
    } catch (e) {
      NoctraLogger.w('Auto-crossfade failed, falling back to normal completion', e);
    }
  }

  /// Perform the real player swap: reassign _player, detach/reattach listeners.
  void _performSwap(AudioPlayer newPlayer) {
    final old = _player;
    _player = newPlayer;

    // The old player's listeners now check `identical(p, _player)` and will
    // silently ignore events. The new player already has listeners from
    // _crossfadePlayer creation or we attach them now.
    // We don't need to re-attach because _attachListeners was called when
    // _crossfadePlayer was first created (if it went through playSong path),
    // but to be safe, attach to new player.
    _attachListeners(newPlayer);

    // Recycle old player as future crossfade player
    _crossfadePlayer = old;
  }

  /// Invalidate preload cache — call when queue or current track changes.
  void _invalidatePreload() {
    _preloadedNextUrl = null;
    _preloadedNextSong = null;
    _preloading = false;
  }

  // ── Preloading ──

  /// Begin preloading the next track in the queue immediately.
  void _startPreloadNext() {
    if (_preloading) return;
    final nextIndex = _currentIndex + 1;

    if (nextIndex >= _queue.length) {
      // At end of queue — fetch similar if autoplay enabled
      if (_isAutoplayEnabled && _currentSong != null) {
        _preloading = true;
        final epoch = _playSessionEpoch;
        MusicService.fetchSimilarRadioQueue(_currentSong!).then((similar) {
          if (epoch != _playSessionEpoch) {
            _preloading = false;
            return;
          }
          if (similar.isNotEmpty) {
            for (final s in similar) {
              if (!_queue.any((q) => q.id == s.id)) _queue.add(s);
            }
            _queueController.add(_queue);
            _preloadTrack(similar.first, epoch)
                .whenComplete(() => _preloading = false);
          } else {
            _preloading = false;
          }
        }).catchError((_) {
          _preloading = false;
          return null;
        });
      }
      return;
    }

    _preloadTrack(_queue[nextIndex], _playSessionEpoch);
  }

  /// Pre-resolve and cache the stream URL for a track.
  /// Validates epoch before storing to prevent stale results.
  Future<void> _preloadTrack(Song song, int epoch) async {
    try {
      final url = await CompositeStreamResolver.resolve(song);
      // Discard if epoch changed (track was skipped/changed during resolution)
      if (epoch != _playSessionEpoch) return;
      if (url != null && url.isNotEmpty) {
        _preloadedNextUrl = url;
        _preloadedNextSong = song;
        NoctraLogger.d('Preloaded next track: ${song.title}');
      }
    } catch (e) {
      NoctraLogger.w('Preload failed for: ${song.title}', e);
    }
  }

  // ── URL Resolution ──

  /// Resolve stream URL for a song, using preloaded URL if available.
  Future<String> _resolveUrl(Song song) async {
    // Use preloaded URL if available for this song
    if (_preloadedNextSong?.id == song.id && _preloadedNextUrl != null) {
      final url = _preloadedNextUrl!;
      _preloadedNextUrl = null;
      _preloadedNextSong = null;
      NoctraLogger.d('Using preloaded URL for: ${song.title}');
      return 'Preloaded:$url';
    }

    // Standard resolution
    if (song.localFilePath != null &&
        song.localFilePath!.isNotEmpty &&
        !kIsWeb) {
      try {
        final f = File(song.localFilePath!);
        if (f.existsSync() && f.lengthSync() > 1024) {
          return 'LocalFile:${song.localFilePath!}';
        }
      } catch (_) {}
    }
    if (song.streamUrl != null &&
        song.streamUrl!.contains('saavncdn.com')) {
      return 'JioSaavn320k:${song.streamUrl!}';
    }
    if (song.id.startsWith('jam_')) {
      return 'JamendoDirect:${song.streamUrl ?? ''}';
    }
    final url = await CompositeStreamResolver.resolve(song) ?? '';
    return 'CompositeResolver:$url';
  }

  /// Extract the actual URL from a resolver-tagged result.
  String _extractUrl(String resolved) {
    final colonIdx = resolved.indexOf(':');
    if (colonIdx > 0 && colonIdx < 20) {
      return resolved.substring(colonIdx + 1);
    }
    return resolved;
  }

  /// Get the resolver name from a resolver-tagged result.
  String _extractResolver(String resolved) {
    final colonIdx = resolved.indexOf(':');
    if (colonIdx > 0 && colonIdx < 20) {
      return resolved.substring(0, colonIdx);
    }
    return 'CompositeResolver';
  }

  Future<void> restoreLastPlaybackSession({bool autoPlay = false}) async {
    try {
      final saved = await NoctraLocalDatabase().loadPlaybackPosition();
      if (saved == null || saved['song'] == null) return;
      final restoredSong = saved['song'] as Song?;
      if (restoredSong == null) return;
      _currentSong = restoredSong;
      _lastSavedSongId = _currentSong!.id;
      _lastSavedPosition =
          Duration(milliseconds: (saved['positionMs'] as int?) ?? 0);
      _queue.clear();
      _queue.add(_currentSong!);
      _currentIndex = 0;
      _currentSongController.add(_currentSong);
      _queueController.add(_queue);
      final resolved = await _resolveUrl(_currentSong!);
      final url = _extractUrl(resolved);
      if (url.isNotEmpty) {
        final src = url.startsWith('http')
            ? AudioSource.uri(Uri.parse(url),
                tag: _createMediaItem(_currentSong!))
            : AudioSource.file(url, tag: _createMediaItem(_currentSong!));
        await _player.setAudioSource(src, initialPosition: _lastSavedPosition);
        if (autoPlay) {
          await _player.setVolume(1.0);
          await _player.play();
        }
      }
    } catch (e) {
      NoctraLogger.w('restoreLastPlaybackSession failed', e);
    }
  }

  MediaItem _createMediaItem(Song s) => MediaItem(
      id: s.id,
      album: s.album,
      title: s.title,
      artist: s.artist,
      artUri: (s.artworkUrl != null && s.artworkUrl!.startsWith('http'))
          ? Uri.parse(s.artworkUrl!)
          : null,
      duration: s.duration,
      playable: true);

  Future<void> playSong(Song song,
      {List<Song>? newQueue, Duration? initialPosition}) async {
    final epoch = ++_playSessionEpoch;
    _recoveryAttemptsByEpoch.removeWhere((key, _) => key < epoch - 1);
    _transitionEpoch++;
    _crossfading = false;

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue.clear();
      _queue.addAll(newQueue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
      _invalidatePreload(); // Queue changed — invalidate
    } else if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }
    _currentSong = song;
    _songStartTime = DateTime.now();
    _currentSongController.add(song);
    _queueController.add(_queue);
    MusicRepository().recordSongPlayed(song);
    try {
      await _player.stop();
    } catch (_) {}
    _positionSaveEpoch = _playSessionEpoch;
    _lastSavedSec = -1;
    if (epoch != _playSessionEpoch) return;

    final sw = Stopwatch()..start();
    String resolverName = 'Local', url = '';
    try {
      final resolved = await _resolveUrl(song);
      resolverName = _extractResolver(resolved);
      url = _extractUrl(resolved);
      sw.stop();
      if (epoch != _playSessionEpoch) return;
      _lastResolution = StreamResolutionMetadata(
          songId: song.id,
          songTitle: song.title,
          resolvedUrl: url,
          resolverUsed: resolverName,
          resolutionMs: sw.elapsedMilliseconds,
          timestamp: DateTime.now());
      if (_lastResolution != null) _resolutionController.add(_lastResolution!);
      if (epoch != _playSessionEpoch) return;

      if (url.isNotEmpty) {
        Duration startPos = initialPosition ??
            ((_lastSavedPosition != null && _lastSavedSongId == song.id)
                ? _lastSavedPosition!
                : Duration.zero);
        _restoredPositionUsed = startPos.inMilliseconds > 0;
        _lastSavedPosition = null;
        _lastSavedSongId = null;
        final currentMediaItem = _createMediaItem(song);
        bool loaded = false;
        try {
          final src = url.startsWith('http')
              ? AudioSource.uri(Uri.parse(url), tag: currentMediaItem)
              : AudioSource.file(url, tag: currentMediaItem);
          await _player.setAudioSource(src, initialPosition: startPos);
          loaded = true;
        } catch (e) {
          NoctraLogger.w(
              'playSong: setAudioSource failed for "${song.title}"', e);
          CompositeStreamResolver.invalidateCache(song.id);
          if (epoch == _playSessionEpoch) {
            try {
              final fallbackResolved =
                  await CompositeStreamResolver.resolve(song, startTier: 1);
              final fallbackUrl = fallbackResolved ?? '';
              if (fallbackUrl.isNotEmpty && fallbackUrl != url) {
                final fallbackSrc = fallbackUrl.startsWith('http')
                    ? AudioSource.uri(Uri.parse(fallbackUrl),
                        tag: currentMediaItem)
                    : AudioSource.file(fallbackUrl, tag: currentMediaItem);
                await _player.setAudioSource(fallbackSrc,
                    initialPosition: startPos);
                loaded = true;
              }
            } catch (_) {}
          }
        }
        if (loaded && epoch == _playSessionEpoch) {
          // Fade in if enabled, otherwise start at full volume
          if (_isFadeEnabled) {
            await _player.setVolume(0.0);
            await _player.play();
            await _fadeIn();
          } else {
            await _player.setVolume(1.0);
            await _player.play();
          }
          await applyStudioMasterMode(_studioMasterMode);
          // Start preloading next track immediately
          _startPreloadNext();
        }
      } else {
        NoctraLogger.w(
            'playSong: no resolved URL for "${song.title}" by ${song.artist}',
            null);
      }
    } catch (e) {
      NoctraLogger.w('playSong failed for "${song.title}"', e);
    }
  }

  Future<void> resumeOrPlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle &&
          _currentSong != null) {
        await playSong(_currentSong!);
      } else {
        await _player.play();
      }
    }
  }

  Future<void> togglePlayPause() => resumeOrPlay();

  Future<void> skipNext() async {
    if (_skipInFlight) return;
    _skipInFlight = true;
    try {
      if (_songStartTime != null && _currentSong != null) {
        final playedSec = DateTime.now().difference(_songStartTime!).inSeconds;
        ImplicitSignalTracker().trackPlaybackEnd(
            song: _currentSong!,
            listenedSeconds: playedSec,
            totalDuration: _currentSong!.duration);
        NoctraLocalDatabase().recordManifest(_currentSong!,
            action: playedSec < 15 ? 'skip' : 'play',
            listenedSeconds: playedSec);
      }
      if (_queue.isNotEmpty) {
        if (_currentIndex >= _queue.length - 1 &&
            _isAutoplayEnabled &&
            _currentSong != null) {
          final similar =
              await MusicService.fetchSimilarRadioQueue(_currentSong!);
          if (similar.isNotEmpty) {
            for (final s in similar) {
              if (!_queue.any((q) => q.id == s.id)) _queue.add(s);
            }
            _queueController.add(_queue);
          }
        }
        _currentIndex = (_currentIndex + 1) % _queue.length;
        final nextSong = _queue[_currentIndex];

        // Crossfade if enabled
        if (_isFadeEnabled && _crossfadeSeconds > 0) {
          await _crossfadeToNext(nextSong);
        } else {
          await playSong(nextSong);
        }
      }
    } finally {
      _skipInFlight = false;
    }
  }

  /// Crossfade to the next song using a second player.
  Future<void> _crossfadeToNext(Song nextSong) async {
    final epoch = _playSessionEpoch;
    _transitionEpoch++;
    _crossfading = true;
    try {
      final url = await _resolveUrl(nextSong);
      if (url.isEmpty || epoch != _playSessionEpoch) {
        _crossfading = false;
        return;
      }

      _crossfadePlayer ??= AudioPlayer(maxSkipsOnError: 6);
      final nextPlayer = _crossfadePlayer!;

      final mediaItem = _createMediaItem(nextSong);
      final src = url.startsWith('http')
          ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
          : AudioSource.file(url, tag: mediaItem);

      await nextPlayer.setAudioSource(src);
      await nextPlayer.setVolume(0.0);

      final fadedPlayer = await _crossfadeTo(nextPlayer, nextSong);

      // Real swap: reassign _player, attach listeners
      _performSwap(fadedPlayer);

      _currentSong = nextSong;
      _songStartTime = DateTime.now();
      _currentSongController.add(nextSong);
      MusicRepository().recordSongPlayed(nextSong);

      _startPreloadNext();
    } catch (e) {
      NoctraLogger.w('Crossfade failed, falling back to direct play', e);
      if (epoch == _playSessionEpoch) {
        await playSong(nextSong);
      }
    } finally {
      _crossfading = false;
    }
  }

  Future<void> skipPrevious() async {
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0 && _queue.isNotEmpty) {
      _currentIndex--;
      await playSong(_queue[_currentIndex]);
    }
  }

  Future<void> seek(Duration pos) async {
    try {
      await _player.seek(pos);
    } catch (_) {}
  }

  Future<void> setVolume(double vol) => _player
      .setVolume((vol.isNaN || vol.isInfinite) ? 1.0 : vol.clamp(0.0, 1.0));

  Future<void> stopAndDismiss() async {
    _transitionEpoch++;
    _crossfading = false;
    try {
      await _player.stop();
    } catch (_) {}
    _crossfadePlayer?.dispose();
    _crossfadePlayer = null;
    _invalidatePreload();
    _currentSong = null;
    _currentSongController.add(null);
  }

  Future<void> toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    await _player.setShuffleModeEnabled(_isShuffleEnabled);
    _emitSettings();
  }

  void toggleAutoplay() {
    _isAutoplayEnabled = !_isAutoplayEnabled;
    _emitSettings();
  }

  Future<void> toggleLoopMode() async {
    _loopMode = _loopMode == LoopMode.off
        ? LoopMode.all
        : (_loopMode == LoopMode.all ? LoopMode.one : LoopMode.off);
    await _player.setLoopMode(_loopMode);
    _emitSettings();
  }

  static const _effectsChannel =
      MethodChannel('com.nomadguy.noctra/audio_effects');

  Future<bool> attachNativeEffectsSession() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final sid = _player.androidAudioSessionId;
      if (sid == null || sid <= 0) return false;
      return (await _effectsChannel
              .invokeMethod<bool>('attachSession', {'sessionId': sid})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyStudioMasterMode(String mode) async {
    try {
      if (!await attachNativeEffectsSession()) return false;
      final applied = (await _effectsChannel
              .invokeMethod<bool>('applyStudioMode', {'mode': mode})) ??
          false;
      if (applied) _studioMasterMode = mode;
      return applied;
    } catch (e) {
      NoctraLogger.w('applyStudioMasterMode failed (mode=$mode)', e);
      return false;
    }
  }

  void applyEqualizer(
      {List<double>? bands, double? bassBoost, double? virtualizer}) {
    try {
      attachNativeEffectsSession();
      _effectsChannel.invokeMethod('applyEqualizer', {
        'bands': bands ?? [0.0, 0.0, 0.0, 0.0, 0.0],
        'bassBoost': bassBoost ?? 0.0,
        'virtualizer': virtualizer ?? 0.0,
      });
    } catch (e) {
      NoctraLogger.w('applyEqualizer failed', e);
    }
  }

  void _emitSettings() {
    _playbackSettingsController.add({
      'shuffle': _isShuffleEnabled,
      'loopMode': _loopMode,
      'autoplay': _isAutoplayEnabled,
      'delay': _autoplayDelaySeconds,
      'crossfade': _crossfadeSeconds,
      'sleepTimer': _sleepTimerRemainingMinutes,
      'fade': _isFadeEnabled
    });
  }

  // ── Queue Management ──

  void addToQueue(Song song) {
    _queue.add(song);
    _queueController.add(_queue);
    _invalidatePreload(); // Queue changed
    NoctraLogger.d('addToQueue: ${song.title} (queue size: ${_queue.length})');
  }

  void playNext(Song song) {
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
    _queueController.add(_queue);
    _invalidatePreload(); // Queue changed
    NoctraLogger.d('playNext: ${song.title} at index $insertAt');
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    final wasPlaying = index == _currentIndex;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (wasPlaying && _queue.isNotEmpty) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    }
    _queueController.add(_queue);
    _invalidatePreload(); // Queue changed
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    final song = _queue.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, _queue.length);
    _queue.insert(targetIndex, song);
    if (oldIndex == _currentIndex) {
      _currentIndex = targetIndex;
    } else if (oldIndex < _currentIndex && targetIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && targetIndex <= _currentIndex) {
      _currentIndex++;
    }
    _queueController.add(_queue);
    _invalidatePreload(); // Queue changed
  }

  void clearQueue() {
    if (_currentSong == null) return;
    final current = _queue[_currentIndex];
    _queue.clear();
    _queue.add(current);
    _currentIndex = 0;
    _queueController.add(_queue);
    _invalidatePreload(); // Queue changed
  }

  Future<void> _onSongCompleted() async {
    final playedSec = _songStartTime != null
        ? DateTime.now().difference(_songStartTime!).inSeconds
        : 210;
    if (_currentSong != null) {
      ImplicitSignalTracker().trackPlaybackEnd(
          song: _currentSong!,
          listenedSeconds: playedSec,
          totalDuration: _currentSong!.duration);
      NoctraLocalDatabase().recordManifest(_currentSong!,
          action: 'complete', listenedSeconds: playedSec);
    }
    if (_loopMode == LoopMode.one && _currentSong != null) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else {
      if (_autoplayDelaySeconds > 0) {
        await Future.delayed(Duration(seconds: _autoplayDelaySeconds));
      }
      if (!_skipInFlight) {
        await skipNext();
      }
    }
  }

  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    _crossfadePlayer?.dispose();
    _currentSongController.close();
    _queueController.close();
    _resolutionController.close();
    _playbackSettingsController.close();
  }
}
