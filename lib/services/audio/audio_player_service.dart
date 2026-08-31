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
  // just_audio 0.10 (Media3): maxSkipsOnError replaces old skip-on-error behavior
  // from the deprecated playbackEventStream. 6 = skip after 6 consecutive load failures.
  final AudioPlayer _player = AudioPlayer(maxSkipsOnError: 6);
  AudioPlayer get player => _player;

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
  final _resolutionController = StreamController<StreamResolutionMetadata>.broadcast();
  Stream<StreamResolutionMetadata> get resolutionStream => _resolutionController.stream;
  final _playbackSettingsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get playbackSettingsStream => _playbackSettingsController.stream;

  bool _isShuffleEnabled = false, _isAutoplayEnabled = true, _isFadeEnabled = false, _isFading = false, _skipInFlight = false;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isAutoplayEnabled => _isAutoplayEnabled;
  bool get isFadeEnabled => _isFadeEnabled;
  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;    int _autoplayDelaySeconds = 0, _crossfadeSeconds = 0, _lastSavedSec = 0, _playSessionEpoch = 0;
  bool _restoredPositionUsed = false;
  int _positionSaveEpoch = 0; // C2: epoch guard for position save listener
  int get autoplayDelaySeconds => _autoplayDelaySeconds;
  int get crossfadeSeconds => _crossfadeSeconds;
  int? _sleepTimerRemainingMinutes;
  int? get sleepTimerRemainingMinutes => _sleepTimerRemainingMinutes;
  Timer? _sleepTimer;
  DateTime? _songStartTime;
  Duration? _lastSavedPosition;
  String? _lastSavedSongId;
  StreamResolutionMetadata? _lastResolution;
  StreamResolutionMetadata? get lastResolution => _lastResolution;

  AudioPlayerService._internal() {
    _initAudioSession();
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _onSongCompleted();
    });
    // just_audio 0.10: errorStream replaces the removed playbackEventStream.onError
    _player.errorStream.listen((e) {
      NoctraLogger.e('AudioPlayer error: ${e.toString()}', e);
    });
    _player.positionStream.listen((pos) {
      // C2: epoch guard — skip stale events from the old song
      if (_playSessionEpoch != _positionSaveEpoch) return;
      if (_currentSong != null && _loopMode != LoopMode.one && pos.inSeconds >= 5 && pos.inSeconds != _lastSavedSec && pos.inSeconds % 5 == 0) {
        _lastSavedSec = pos.inSeconds;
        // H-R5-06: Skip saving during the first few seconds after a
        // restored position to avoid overwriting the restored 50s with 5s.
        if (_restoredPositionUsed && pos.inSeconds < 15) return;
        _restoredPositionUsed = false;
        NoctraLocalDatabase().savePlaybackPosition(_currentSong, pos.inMilliseconds);
      }
    });
  }

  Future<void> _initAudioSession() async {
    try { final s = await AudioSession.instance; await s.configure(const AudioSessionConfiguration.music()); } catch (_) {}
  }

  void setAutoplayDelay(int sec) { _autoplayDelaySeconds = sec; _emitSettings(); }
  void setCrossfadeSeconds(int sec) { _crossfadeSeconds = sec; _emitSettings(); }
  void toggleFade(bool enable) { _isFadeEnabled = enable; _emitSettings(); }
  void cancelSleepTimer() => setSleepTimer(0);

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (_isFading) {
      _isFading = false;
      _player.setVolume(1.0);
    }
    if (minutes <= 0) { _sleepTimerRemainingMinutes = null; _emitSettings(); return; }
    _sleepTimerRemainingMinutes = minutes; _emitSettings();
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) async {
      if (_sleepTimerRemainingMinutes != null && _sleepTimerRemainingMinutes! > 1) {
        _sleepTimerRemainingMinutes = _sleepTimerRemainingMinutes! - 1; _emitSettings();
      } else {
        t.cancel(); _sleepTimerRemainingMinutes = null; _emitSettings();
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
        // Always restore volume so subsequent play isn't stuck at 0
        await _player.setVolume(1.0);
      }
    });
  }

  Future<void> restoreLastPlaybackSession({bool autoPlay = false}) async {
    try {
      final saved = await NoctraLocalDatabase().loadPlaybackPosition();
      if (saved == null || saved['song'] == null) return;
      // Use a safe cast — corrupted persisted data returns null instead of crashing
      final restoredSong = saved['song'] as Song?;
      if (restoredSong == null) return;
      _currentSong = restoredSong;
      _lastSavedSongId = _currentSong!.id;
      _lastSavedPosition = Duration(milliseconds: (saved['positionMs'] as int?) ?? 0);
      _queue.clear(); _queue.add(_currentSong!); _currentIndex = 0;
      _currentSongController.add(_currentSong); _queueController.add(_queue);
      final url = await CompositeStreamResolver.resolve(_currentSong!);
      if (url != null && url.isNotEmpty) {
        final src = url.startsWith('http')
            ? AudioSource.uri(Uri.parse(url), tag: _createMediaItem(_currentSong!))
            : AudioSource.file(url, tag: _createMediaItem(_currentSong!));
        await _player.setAudioSource(src, initialPosition: _lastSavedPosition);
        if (autoPlay) { await _player.setVolume(1.0); await _player.play(); }
      }
    } catch (e) {
      NoctraLogger.w('restoreLastPlaybackSession failed', e);
    }
  }

  MediaItem _createMediaItem(Song s) => MediaItem(id: s.id, album: s.album, title: s.title, artist: s.artist, artUri: (s.artworkUrl != null && s.artworkUrl!.startsWith('http')) ? Uri.parse(s.artworkUrl!) : null, duration: s.duration, playable: true);

  Future<void> playSong(Song song, {List<Song>? newQueue, Duration? initialPosition}) async {
    final epoch = ++_playSessionEpoch;
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue.clear(); _queue.addAll(newQueue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) { _queue.insert(0, song); _currentIndex = 0; }
    } else if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song); _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }
    _currentSong = song; _songStartTime = DateTime.now();
    _currentSongController.add(song); _queueController.add(_queue);
    NoctraLocalDatabase().recordManifest(song, action: 'play');
    MusicRepository().recordSongPlayed(song);
    try { await _player.stop(); } catch (_) {}
    // C-1 + C2 fix: reset AFTER stop and bump epoch so stale position
    // stream events from the old song are ignored.
    _positionSaveEpoch = _playSessionEpoch;
    _lastSavedSec = -1;
    if (epoch != _playSessionEpoch) return;

    final sw = Stopwatch()..start();
    String resolverName = 'Local', url = '';
    try {
      if (song.localFilePath != null && song.localFilePath!.isNotEmpty && !kIsWeb) {
        try {
          final f = File(song.localFilePath!);
          if (f.existsSync() && f.lengthSync() > 1024) { resolverName = 'LocalFile'; url = song.localFilePath!; }
        } catch (_) {}
      }
      if (url.isEmpty && song.streamUrl != null && song.streamUrl!.contains('saavncdn.com')) {
        resolverName = 'JioSaavn320k'; url = song.streamUrl!;
      } else if (url.isEmpty && song.id.startsWith('jam_')) {
        resolverName = 'JamendoDirect'; url = song.streamUrl ?? '';
      } else if (url.isEmpty) {
        resolverName = 'CompositeResolver';
        url = (await CompositeStreamResolver.resolve(song)) ?? '';
      }
      sw.stop();
      if (epoch != _playSessionEpoch) return;
      _lastResolution = StreamResolutionMetadata(songId: song.id, songTitle: song.title, resolvedUrl: url, resolverUsed: resolverName, resolutionMs: sw.elapsedMilliseconds, timestamp: DateTime.now());
      if (_lastResolution != null) _resolutionController.add(_lastResolution!);
      if (epoch != _playSessionEpoch) return;

      if (url.isNotEmpty) {
        Duration startPos = initialPosition ?? ((_lastSavedPosition != null && _lastSavedSongId == song.id) ? _lastSavedPosition! : Duration.zero);
        _restoredPositionUsed = startPos.inMilliseconds > 0;
        _lastSavedPosition = null; _lastSavedSongId = null;
        final currentMediaItem = _createMediaItem(song);
        bool loaded = false;
        try {
          final src = url.startsWith('http')
              ? AudioSource.uri(Uri.parse(url), tag: currentMediaItem)
              : AudioSource.file(url, tag: currentMediaItem);
          await _player.setAudioSource(src, initialPosition: startPos);
          loaded = true;
        } catch (e) {
          NoctraLogger.w('playSong: setAudioSource failed for "${song.title}"', e);
          CompositeStreamResolver.invalidateCache(song.id);
          if (epoch == _playSessionEpoch) {
            try {
              final fallbackUrl = await CompositeStreamResolver.resolve(song, startTier: 1);
              if (fallbackUrl != null && fallbackUrl.isNotEmpty && fallbackUrl != url) {
                final fallbackSrc = fallbackUrl.startsWith('http')
                    ? AudioSource.uri(Uri.parse(fallbackUrl), tag: currentMediaItem)
                    : AudioSource.file(fallbackUrl, tag: currentMediaItem);
                await _player.setAudioSource(fallbackSrc, initialPosition: startPos);
                loaded = true;
              }
            } catch (_) {}
          }
        }
        if (loaded && epoch == _playSessionEpoch) {
          await _player.setVolume(1.0);
          await _player.play();
        }
      } else {
        NoctraLogger.w('playSong: no resolved URL for "${song.title}" by ${song.artist}', null);
      }
    } catch (e) {
      NoctraLogger.w('playSong failed for "${song.title}"', e);
    }
  }

  Future<void> resumeOrPlay() async {
    if (_player.playing) { await _player.pause(); } else {
      if (_player.processingState == ProcessingState.idle && _currentSong != null) { await playSong(_currentSong!); } else { await _player.play(); }
    }
  }

  Future<void> togglePlayPause() => resumeOrPlay();

  Future<void> skipNext() async {
    if (_skipInFlight) return;
    _skipInFlight = true;
    try {
      if (_songStartTime != null && _currentSong != null) {
        final playedSec = DateTime.now().difference(_songStartTime!).inSeconds;
        ImplicitSignalTracker().trackPlaybackEnd(song: _currentSong!, listenedSeconds: playedSec, totalDuration: _currentSong!.duration);
        NoctraLocalDatabase().recordManifest(_currentSong!, action: playedSec < 15 ? 'skip' : 'play', listenedSeconds: playedSec);
      }
      if (_queue.isNotEmpty) {
        if (_currentIndex >= _queue.length - 1 && _isAutoplayEnabled && _currentSong != null) {
          final similar = await MusicService.fetchSimilarRadioQueue(_currentSong!);
          if (similar.isNotEmpty) {
            for (final s in similar) { if (!_queue.any((q) => q.id == s.id)) _queue.add(s); }
            _queueController.add(_queue);
          }
        }
        _currentIndex = (_currentIndex + 1) % _queue.length;
        await playSong(_queue[_currentIndex]);
      }
    } finally { _skipInFlight = false; }
  }

  Future<void> skipPrevious() async {
    if (_player.position.inSeconds > 4) { await _player.seek(Duration.zero); return; }
    if (_currentIndex > 0 && _queue.isNotEmpty) { _currentIndex--; await playSong(_queue[_currentIndex]); }
  }

  Future<void> seek(Duration pos) async {
    // M-14: guard against rapid concurrent seeks corrupting player state
    if (_skipInFlight) return;
    try { await _player.seek(pos); } catch (_) {}
  }
  Future<void> setVolume(double vol) => _player.setVolume((vol.isNaN || vol.isInfinite) ? 1.0 : vol.clamp(0.0, 1.0));

  Future<void> stopAndDismiss() async { try { await _player.stop(); } catch (_) {} _currentSong = null; _currentSongController.add(null); }
  Future<void> toggleShuffle() async { _isShuffleEnabled = !_isShuffleEnabled; await _player.setShuffleModeEnabled(_isShuffleEnabled); _emitSettings(); }
  void toggleAutoplay() { _isAutoplayEnabled = !_isAutoplayEnabled; _emitSettings(); }
  Future<void> toggleLoopMode() async { _loopMode = _loopMode == LoopMode.off ? LoopMode.all : (_loopMode == LoopMode.all ? LoopMode.one : LoopMode.off); await _player.setLoopMode(_loopMode); _emitSettings(); }

  static const _effectsChannel = MethodChannel('com.noctra.app/audio_effects');

  void attachNativeEffectsSession() {
    if (!kIsWeb) {
      try {
        final sid = _player.androidAudioSessionId;
        if (sid != null && sid > 0) _effectsChannel.invokeMethod('attachSession', {'sessionId': sid});
      } catch (_) {}
    }
  }

  void applyStudioMasterMode(String mode) {
    try {
      attachNativeEffectsSession();
      _effectsChannel.invokeMethod('applyStudioMode', {'mode': mode});
    } catch (e) {
      // H-5: Log EQ failures so they're traceable; do NOT swallow silently
      NoctraLogger.w('applyStudioMasterMode failed (mode=$mode)', e);
    }
  }

  void applyEqualizer({List<double>? bands, double? bassBoost, double? virtualizer}) {
    try {
      attachNativeEffectsSession();
      _effectsChannel.invokeMethod('applyEqualizer', {
        'bands': bands ?? [0.0, 0.0, 0.0, 0.0, 0.0],
        'bassBoost': bassBoost ?? 0.0,
        'virtualizer': virtualizer ?? 0.0,
      });
    } catch (e) {
      // H-5: Log EQ failures so they're traceable
      NoctraLogger.w('applyEqualizer failed', e);
    }
  }

  void _emitSettings() {
    _playbackSettingsController.add({'shuffle': _isShuffleEnabled, 'loopMode': _loopMode, 'autoplay': _isAutoplayEnabled, 'delay': _autoplayDelaySeconds, 'crossfade': _crossfadeSeconds, 'sleepTimer': _sleepTimerRemainingMinutes, 'fade': _isFadeEnabled});
  }

  Future<void> _onSongCompleted() async {
    final playedSec = _songStartTime != null ? DateTime.now().difference(_songStartTime!).inSeconds : 210;
    if (_currentSong != null) {
      ImplicitSignalTracker().trackPlaybackEnd(song: _currentSong!, listenedSeconds: playedSec, totalDuration: _currentSong!.duration);
      NoctraLocalDatabase().recordManifest(_currentSong!, action: 'complete', listenedSeconds: playedSec);
    }
    if (_loopMode == LoopMode.one && _currentSong != null) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else {
      if (_isAutoplayEnabled && _autoplayDelaySeconds > 0) {
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
    _currentSongController.close();
    _queueController.close();
    _resolutionController.close();
    _playbackSettingsController.close();
  }
}
