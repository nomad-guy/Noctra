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

/// Result of a crossfade transition attempt.
enum CrossfadeResult { completed, cancelled, failed }

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  static AudioPlayerService get instance => _instance;

  // ── Player references ──

  /// Currently audible player. Only one player is ACTIVE at any time.
  AudioPlayer _player = AudioPlayer(maxSkipsOnError: 6);
  AudioPlayer get player => _player;

  /// Inactive player — recycled during crossfade. Never playing except during transition.
  AudioPlayer? _secondary;

  /// Pre-buffered player for the next track (source set, paused, buffering).
  AudioPlayer? _bufferedNext;
  Song? _bufferedNextSong;
  bool _preloading = false;

  // ── Subscription lifecycle ──
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<Duration>? _positionSub;

  void _attachListeners() {
    _detachListeners();
    _stateSub = _player.playerStateStream.listen((s) {
      if (_transitionInProgress) { return; }
      if (s.processingState == ProcessingState.completed) { _onSongCompleted(); }
    });
    _errorSub = _player.errorStream.listen((e) {
      if (_transitionInProgress) { return; }
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
        _serialize(() async {
          if (_playSessionEpoch != epoch || _currentSong?.id != active.id) { return; }
          await playSong(active, initialPosition: pos);
        });
      }
    });
    _positionSub = _player.positionStream.listen((pos) {
      if (_playSessionEpoch != _positionSaveEpoch) { return; }
      final activeSong = _currentSong;
      if (activeSong != null &&
          _loopMode != LoopMode.one &&
          pos.inSeconds >= 5 &&
          pos.inSeconds != _lastSavedSec &&
          pos.inSeconds % 5 == 0) {
        _lastSavedSec = pos.inSeconds;
        if (_restoredPositionUsed && pos.inSeconds < 15) { return; }
        _restoredPositionUsed = false;
        NoctraLocalDatabase()
            .savePlaybackPosition(activeSong, pos.inMilliseconds);
      }
      _checkAutoCrossfade(pos);
    });
  }

  void _detachListeners() {
    _stateSub?.cancel();
    _stateSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  // ── Serialized operation chain ──

  /// Single serialization mechanism for ALL playback state mutations.
  /// Ensures playSong, skipNext, autoCrossfade, recovery never run concurrently.
  Future<void> _opChain = Future.value();

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _opChain.then((_) => operation());
    _opChain = next.catchError((_) {});
    return next;
  }

  // ── Queue / state ──

  final List<Song> _queue = [];
  List<Song> get queue => List.unmodifiable(_queue);
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  Song? _currentSong;
  Song? get currentSong => _currentSong;

  /// Monotonically increasing counter — incremented on every queue mutation.
  int _queueRevision = 0;

  /// Centralized queue mutation helper — ensures revision is always incremented.
  void _mutateQueue(void Function() mutate) {
    mutate();
    _queueRevision++;
    _queueController.add(List.unmodifiable(_queue));
  }

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
      _isFading = false;
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
  int _transitionEpoch = 0;

  /// Transition ID — each transition gets a unique token for ownership tracking.
  int _transitionId = 0;

  /// Whether a transition is currently in progress.
  bool _transitionInProgress = false;

  /// Shared volume transition epoch — prevents sleep-fade vs crossfade fighting.
  int _volumeEpoch = 0;

  /// Minimum queue depth to maintain for autoplay.
  static const int _minAutoplayBuffer = 3;

  /// Single in-flight radio request — prevents duplicate network calls.
  Future<List<Song>>? _radioRequest;

  AudioPlayerService._internal() {
    _initAudioSession();
    _attachListeners();
  }

  Future<void> _initAudioSession() async {
    try {
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  // ── Settings ──

  void setAutoplayDelay(int sec) {
    _autoplayDelaySeconds = sec.clamp(0, 30);
    _emitSettings();
  }

  void setCrossfadeSeconds(int sec) {
    _crossfadeSeconds = sec.clamp(0, 12);
    _emitSettings();
  }

  void toggleFade(bool enable) {
    _isFadeEnabled = enable;
    if (!enable) {
      // Invalidate any active volume transition
      _volumeEpoch++;
      _transitionEpoch++;
      try {
        _player.setVolume(1.0);
      } catch (_) {}
    }
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
        // Use shared volume epoch for sleep fade
        final vEpoch = ++_volumeEpoch;
        _isFading = true;
        for (int i = 10; i >= 0; i--) {
          if (!_isFading || _volumeEpoch != vEpoch) { break; }
          await _player.setVolume(i / 10.0);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isFading && _volumeEpoch == vEpoch) {
          await _player.pause();
          _isFading = false;
        }
        await _player.setVolume(1.0);
      }
    });
  }

  // ── Safe player disposal ──

  Future<void> _disposePlayer(AudioPlayer? p) async {
    if (p == null) { return; }
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.dispose();
    } catch (_) {}
  }

  // ── Fade helpers ──

  Future<void> _fadeIn({Duration? duration}) async {
    if (!_isFadeEnabled) { return; }
    final dur = duration ?? const Duration(milliseconds: 400);
    const steps = 20;
    final stepDelay = Duration(
        milliseconds: (dur.inMilliseconds / steps).round().clamp(10, 200));
    final vEpoch = ++_volumeEpoch;
    for (var i = 1; i <= steps; i++) {
      if (_volumeEpoch != vEpoch) { return; }
      await _player.setVolume(i / steps);
      await Future.delayed(stepDelay);
    }
  }

  // ── Crossfade ──

  Future<CrossfadeResult> _crossfadeTo(
      AudioPlayer nextPlayer, Song nextSong) async {
    final duration = Duration(seconds: _crossfadeSeconds);
    const steps = 30;
    final stepDelay = Duration(
        milliseconds: (duration.inMilliseconds / steps).round().clamp(10, 200));
    final tEpoch = _transitionEpoch;
    final playEpoch = _playSessionEpoch;
    final vEpoch = ++_volumeEpoch;

    // Check buffer readiness
    final buffered = nextPlayer.bufferedPosition;
    final requiredBuffer = Duration(seconds: _crossfadeSeconds.clamp(1, 3));
    if (buffered < requiredBuffer) {
      NoctraLogger.w('Crossfade buffer insufficient: ${buffered.inMilliseconds}ms < ${requiredBuffer.inMilliseconds}ms');
      return CrossfadeResult.failed;
    }

    await nextPlayer.setVolume(0.0);
    await nextPlayer.seek(Duration.zero);
    await nextPlayer.play();

    for (var i = 1; i <= steps; i++) {
      if (_transitionEpoch != tEpoch ||
          _playSessionEpoch != playEpoch ||
          _volumeEpoch != vEpoch) {
        try {
          await nextPlayer.stop();
          await nextPlayer.setVolume(1.0);
        } catch (_) {}
        return CrossfadeResult.cancelled;
      }
      final progress = i / steps;
      await Future.wait([
        _player.setVolume(1.0 - progress),
        nextPlayer.setVolume(progress),
      ]);
      await Future.delayed(stepDelay);
    }

    try {
      await _player.stop();
    } catch (_) {}

    return CrossfadeResult.completed;
  }

  /// Auto-crossfade check — triggered by position stream.
  void _checkAutoCrossfade(Duration pos) {
    if (_transitionInProgress) { return; }
    if (!_isFadeEnabled || _crossfadeSeconds <= 0) { return; }
    if (_loopMode == LoopMode.one) { return; }

    final duration = _player.duration;
    if (duration == null) { return; }
    if (duration.inSeconds <= _crossfadeSeconds) { return; }

    if (_player.processingState != ProcessingState.ready &&
        _player.processingState != ProcessingState.buffering) { return; }
    if (!_player.playing) { return; }

    final crossfadeDur = Duration(seconds: _crossfadeSeconds);
    final triggerPoint = duration - crossfadeDur;
    if (pos < triggerPoint) { return; }

    _serialize(() => _autoCrossfadeNext());
  }

  Future<void> _autoCrossfadeNext() async {
    if (_transitionInProgress) { return; }
    _transitionInProgress = true;
    final myId = ++_transitionId;
    final epoch = _playSessionEpoch;
    final tEpoch = _transitionEpoch;
    final rev = _queueRevision;

    try {
      Song? nextSong;
      if (_currentIndex < _queue.length - 1) {
        nextSong = _queue[_currentIndex + 1];
      } else if (_isAutoplayEnabled && _currentSong != null) {
        await _ensureAutoplayQueue(epoch, rev);
        if (_currentIndex < _queue.length - 1) {
          nextSong = _queue[_currentIndex + 1];
        }
      }

      if (nextSong == null ||
          epoch != _playSessionEpoch ||
          tEpoch != _transitionEpoch ||
          rev != _queueRevision) { return; }

      AudioPlayer? nextPlayer;
      if (_bufferedNext != null && _bufferedNextSong?.id == nextSong.id) {
        // Transfer ownership atomically
        nextPlayer = _bufferedNext;
        _bufferedNext = null;
        _bufferedNextSong = null;
        NoctraLogger.d('Auto-crossfade using pre-buffered: ${nextSong.title}');
      } else {
        nextPlayer = await _preparePlayer(nextSong, epoch);
      }

      if (nextPlayer == null ||
          epoch != _playSessionEpoch ||
          tEpoch != _transitionEpoch ||
          _transitionId != myId) {
        await _disposePlayer(nextPlayer);
        return;
      }

      final result = await _crossfadeTo(nextPlayer, nextSong);

      // Validate ALL conditions before promotion
      if (result != CrossfadeResult.completed) {
        await _disposePlayer(nextPlayer);
        return;
      }
      if (epoch != _playSessionEpoch ||
          tEpoch != _transitionEpoch ||
          _transitionId != myId) {
        await _disposePlayer(nextPlayer);
        return;
      }

      // Validate queue identity BEFORE player swap
      final expectedId = nextSong.id;
      final newIndex = _queue.indexWhere((s) => s.id == expectedId);
      if (newIndex < 0) {
        await _disposePlayer(nextPlayer);
        return;
      }

      // ALL checks passed — commit the swap
      _detachListeners();
      _secondary = _player;
      _player = nextPlayer;
      _attachListeners();

      _currentIndex = newIndex;
      _currentSong = nextSong;
      _songStartTime = DateTime.now();
      _currentSongController.add(nextSong);
      MusicRepository().recordSongPlayed(nextSong);

      _startPreloadNext();
    } finally {
      if (_transitionId == myId) {
        _transitionInProgress = false;
      }
    }
  }

  Future<void> _ensureAutoplayQueue(int epoch, int revision) async {
    final remaining = _queue.length - _currentIndex - 1;
    if (remaining >= _minAutoplayBuffer) { return; }
    if (_currentSong == null) { return; }

    final similar = await _getRadioQueue(_currentSong!);
    if (similar.isEmpty ||
        epoch != _playSessionEpoch ||
        revision != _queueRevision) { return; }

    _mutateQueue(() {
      for (final s in similar) {
        if (!_queue.any((q) => q.id == s.id)) { _queue.add(s); }
      }
    });
  }

  /// Single in-flight radio request — prevents duplicate network calls.
  Future<List<Song>> _getRadioQueue(Song seed) {
    final existing = _radioRequest;
    if (existing != null) { return existing; }

    final request = MusicService.fetchSimilarRadioQueue(seed);
    _radioRequest = request;

    request.whenComplete(() {
      if (identical(_radioRequest, request)) {
        _radioRequest = null;
      }
    });

    return request;
  }

  // ── Preloading ──

  Future<void> _invalidatePreload() async {
    final player = _bufferedNext;
    _bufferedNext = null;
    _bufferedNextSong = null;
    _preloading = false;
    if (player != null) {
      await _disposePlayer(player);
    }
  }

  void _startPreloadNext() {
    if (_preloading) { return; }
    final nextIndex = _currentIndex + 1;

    if (nextIndex >= _queue.length) {
      if (_isAutoplayEnabled && _currentSong != null) {
        _preloading = true;
        final epoch = _playSessionEpoch;
        final rev = _queueRevision;
        _getRadioQueue(_currentSong!).then((similar) {
          if (epoch != _playSessionEpoch || rev != _queueRevision) {
            _preloading = false;
            return;
          }
          if (similar.isNotEmpty) {
            _mutateQueue(() {
              for (final s in similar) {
                if (!_queue.any((q) => q.id == s.id)) { _queue.add(s); }
              }
            });
            if (_currentIndex + 1 < _queue.length) {
              _prepareNextPlayer(_queue[_currentIndex + 1], epoch, rev)
                  .whenComplete(() => _preloading = false);
            } else {
              _preloading = false;
            }
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

    _preloading = true;
    final epoch = _playSessionEpoch;
    final rev = _queueRevision;
    final song = _queue[nextIndex];
    _prepareNextPlayer(song, epoch, rev)
        .whenComplete(() => _preloading = false);
  }

  Future<void> _prepareNextPlayer(
      Song song, int epoch, int revision) async {
    try {
      final resolved = await _resolveUrl(song);
      final url = _extractUrl(resolved);
      if (url.isEmpty ||
          epoch != _playSessionEpoch ||
          revision != _queueRevision) { return; }

      final nextPlayer = AudioPlayer(maxSkipsOnError: 6);
      final mediaItem = _createMediaItem(song);
      final src = url.startsWith('http')
          ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
          : AudioSource.file(url, tag: mediaItem);

      await nextPlayer.setAudioSource(src);
      await nextPlayer.setVolume(0.0);

      if (epoch != _playSessionEpoch || revision != _queueRevision) {
        await _disposePlayer(nextPlayer);
        return;
      }

      // Dispose old buffered player
      final oldBuffered = _bufferedNext;
      _bufferedNext = nextPlayer;
      _bufferedNextSong = song;
      if (oldBuffered != null) {
        await _disposePlayer(oldBuffered);
      }
      NoctraLogger.d('Pre-buffered next track: ${song.title}');
    } catch (e) {
      NoctraLogger.w('Pre-buffer failed for: ${song.title}', e);
    }
  }

  // ── URL Resolution ──

  Future<String> _resolveUrl(Song song) async {
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

  String _extractUrl(String resolved) {
    final colonIdx = resolved.indexOf(':');
    if (colonIdx > 0 && colonIdx < 20) {
      return resolved.substring(colonIdx + 1);
    }
    return resolved;
  }

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
      if (saved == null || saved['song'] == null) { return; }
      final restoredSong = saved['song'] as Song?;
      if (restoredSong == null) { return; }
      _currentSong = restoredSong;
      _lastSavedSongId = _currentSong!.id;
      _lastSavedPosition =
          Duration(milliseconds: (saved['positionMs'] as int?) ?? 0);
      _mutateQueue(() {
        _queue.clear();
        _queue.add(_currentSong!);
        _currentIndex = 0;
      });
      _currentSongController.add(_currentSong);
      final resolved = await _resolveUrl(_currentSong!);
      final url = _extractUrl(resolved);
      if (url.isNotEmpty) {
        final src = url.startsWith('http')
            ? AudioSource.uri(Uri.parse(url),
                tag: _createMediaItem(_currentSong!))
            : AudioSource.file(url, tag: _createMediaItem(_currentSong!));
        await _player.setAudioSource(src,
            initialPosition: _lastSavedPosition);
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
    return _serialize(() async {
      final epoch = ++_playSessionEpoch;
      _recoveryAttemptsByEpoch.removeWhere((key, _) => key < epoch - 1);
      _transitionEpoch++;
      _transitionInProgress = false;

      if (newQueue != null && newQueue.isNotEmpty) {
        _mutateQueue(() {
          _queue.clear();
          _queue.addAll(newQueue);
          _currentIndex = _queue.indexWhere((s) => s.id == song.id);
          if (_currentIndex == -1) {
            _queue.insert(0, song);
            _currentIndex = 0;
          }
        });
        // _invalidatePreload is async — clear ownership first, dispose after
        final oldBuffered = _bufferedNext;
        _bufferedNext = null;
        _bufferedNextSong = null;
        _preloading = false;
        if (oldBuffered != null) { _disposePlayer(oldBuffered); }
      } else if (!_queue.any((s) => s.id == song.id)) {
        _mutateQueue(() {
          _queue.add(song);
          _currentIndex = _queue.length - 1;
        });
      } else {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }
      _currentSong = song;
      _songStartTime = DateTime.now();
      _currentSongController.add(song);
      MusicRepository().recordSongPlayed(song);
      try {
        await _player.stop();
      } catch (_) {}
      _positionSaveEpoch = _playSessionEpoch;
      _lastSavedSec = -1;
      if (epoch != _playSessionEpoch) { return; }

      // Use pre-buffered player if available
      if (_bufferedNext != null && _bufferedNextSong?.id == song.id) {
        final buffered = _bufferedNext!;
        _bufferedNext = null;
        _bufferedNextSong = null;

        _detachListeners();
        _secondary = _player;
        _player = buffered;
        _attachListeners();

        try {
          await _player.seek(Duration.zero);
          if (_isFadeEnabled) {
            await _player.setVolume(0.0);
            await _player.play();
            await _fadeIn();
          } else {
            await _player.setVolume(1.0);
            await _player.play();
          }
          await applyStudioMasterMode(_studioMasterMode);
          _startPreloadNext();
          return;
        } catch (e) {
          NoctraLogger.w('Pre-buffered player failed, falling back', e);
        }
      }

      final sw = Stopwatch()..start();
      String resolverName = 'Local', url = '';
      try {
        final resolved = await _resolveUrl(song);
        resolverName = _extractResolver(resolved);
        url = _extractUrl(resolved);
        sw.stop();
        if (epoch != _playSessionEpoch) { return; }
        _lastResolution = StreamResolutionMetadata(
            songId: song.id,
            songTitle: song.title,
            resolvedUrl: url,
            resolverUsed: resolverName,
            resolutionMs: sw.elapsedMilliseconds,
            timestamp: DateTime.now());
        if (_lastResolution != null) { _resolutionController.add(_lastResolution!); }
        if (epoch != _playSessionEpoch) { return; }

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
            if (_isFadeEnabled) {
              await _player.setVolume(0.0);
              await _player.play();
              await _fadeIn();
            } else {
              await _player.setVolume(1.0);
              await _player.play();
            }
            await applyStudioMasterMode(_studioMasterMode);
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
    });
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
    return _serialize(() async {
      if (_transitionInProgress) { return; }
      _transitionInProgress = true;
      final myId = ++_transitionId;
      try {
        if (_songStartTime != null && _currentSong != null) {
          final playedSec =
              DateTime.now().difference(_songStartTime!).inSeconds;
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
            await _ensureAutoplayQueue(
                _playSessionEpoch, _queueRevision);
          }
          _currentIndex = (_currentIndex + 1) % _queue.length;
          final nextSong = _queue[_currentIndex];

          if (_isFadeEnabled && _crossfadeSeconds > 0) {
            await _crossfadeToNext(nextSong, myId);
          } else {
            await playSong(nextSong);
          }
        }
      } finally {
        if (_transitionId == myId) {
          _transitionInProgress = false;
        }
      }
    });
  }

  Future<void> _crossfadeToNext(Song nextSong, int myId) async {
    final epoch = _playSessionEpoch;
    final tEpoch = _transitionEpoch;
    _transitionEpoch++;

    AudioPlayer? nextPlayer;
    if (_bufferedNext != null && _bufferedNextSong?.id == nextSong.id) {
      nextPlayer = _bufferedNext;
      _bufferedNext = null;
      _bufferedNextSong = null;
      NoctraLogger.d('Manual crossfade using pre-buffered: ${nextSong.title}');
    } else {
      nextPlayer = await _preparePlayer(nextSong, epoch);
    }

    if (nextPlayer == null ||
        epoch != _playSessionEpoch ||
        tEpoch != _transitionEpoch ||
        _transitionId != myId) {
      await _disposePlayer(nextPlayer);
      await playSong(nextSong);
      return;
    }

    final result = await _crossfadeTo(nextPlayer, nextSong);

    // Validate ALL conditions before promotion
    if (result != CrossfadeResult.completed) {
      await _disposePlayer(nextPlayer);
      return;
    }
    if (epoch != _playSessionEpoch ||
        tEpoch != _transitionEpoch ||
        _transitionId != myId) {
      await _disposePlayer(nextPlayer);
      return;
    }

    // Validate queue identity BEFORE player swap
    final expectedId = nextSong.id;
    final newIndex = _queue.indexWhere((s) => s.id == expectedId);
    if (newIndex < 0) {
      await _disposePlayer(nextPlayer);
      return;
    }

    // ALL checks passed — commit
    _detachListeners();
    _secondary = _player;
    _player = nextPlayer;
    _attachListeners();

    _currentIndex = newIndex;
    _currentSong = nextSong;
    _songStartTime = DateTime.now();
    _currentSongController.add(nextSong);
    MusicRepository().recordSongPlayed(nextSong);

    _startPreloadNext();
  }

  Future<AudioPlayer?> _preparePlayer(Song song, int epoch) async {
    try {
      final resolved = await _resolveUrl(song);
      final url = _extractUrl(resolved);
      if (url.isEmpty || epoch != _playSessionEpoch) { return null; }

      final p = AudioPlayer(maxSkipsOnError: 6);
      final mediaItem = _createMediaItem(song);
      final src = url.startsWith('http')
          ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
          : AudioSource.file(url, tag: mediaItem);

      await p.setAudioSource(src);
      await p.setVolume(0.0);
      return p;
    } catch (e) {
      NoctraLogger.w('Failed to prepare player for: ${song.title}', e);
      return null;
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
    _transitionInProgress = false;
    try {
      await _player.stop();
    } catch (_) {}
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
    if (kIsWeb || !Platform.isAndroid) { return false; }
    try {
      final sid = _player.androidAudioSessionId;
      if (sid == null || sid <= 0) { return false; }
      return (await _effectsChannel
              .invokeMethod<bool>('attachSession', {'sessionId': sid})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyStudioMasterMode(String mode) async {
    try {
      if (!await attachNativeEffectsSession()) { return false; }
      final applied = (await _effectsChannel
              .invokeMethod<bool>('applyStudioMode', {'mode': mode})) ??
          false;
      if (applied) { _studioMasterMode = mode; }
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
    _mutateQueue(() {
      _queue.add(song);
    });
    NoctraLogger.d('addToQueue: ${song.title} (queue size: ${_queue.length})');
  }

  void playNext(Song song) {
    _mutateQueue(() {
      final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
      _queue.insert(insertAt, song);
    });
    NoctraLogger.d('playNext: ${song.title}');
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) { return; }
    final wasPlaying = index == _currentIndex;
    _mutateQueue(() {
      _queue.removeAt(index);
    });
    if (wasPlaying && _queue.isNotEmpty) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    } else if (index < _currentIndex) {
      _currentIndex--;
    }
    _invalidatePreload();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) { return; }
    _mutateQueue(() {
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
    });
    _invalidatePreload();
  }

  void clearQueue() {
    if (_currentSong == null) { return; }
    _mutateQueue(() {
      final current = _queue[_currentIndex];
      _queue.clear();
      _queue.add(current);
      _currentIndex = 0;
    });
    _invalidatePreload();
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
      await skipNext();
    }
  }

  void dispose() {
    _sleepTimer?.cancel();
    _detachListeners();
    _player.dispose();
    _disposePlayer(_secondary);
    _invalidatePreload();
    _currentSongController.close();
    _queueController.close();
    _resolutionController.close();
    _playbackSettingsController.close();
  }
}
