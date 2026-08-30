import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/sources/noctra_local_database.dart';
import '../ytdlp/music_service.dart';
import '../resolvers/stream_resolver.dart';
import '../../ui/screens/player_sheet.dart';

class StreamResolutionMetadata {
  final String songId, songTitle, resolverUsed;
  final String? resolvedUrl;
  final int resolutionMs;
  final DateTime timestamp;
  StreamResolutionMetadata({required this.songId, required this.songTitle, required this.resolvedUrl, required this.resolverUsed, required this.resolutionMs, required this.timestamp});
}

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  Song? _currentSong;
  Song? get currentSong => _currentSong;
  final List<Song> _queue = [];
  List<Song> get queue => List.unmodifiable(_queue);
  int _currentIndex = -1;

  final _currentSongController = StreamController<Song?>.broadcast(), _queueController = StreamController<List<Song>>.broadcast(), _resolutionController = StreamController<StreamResolutionMetadata>.broadcast(), _playbackSettingsController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<List<Song>> get queueStream => _queueController.stream;
  Stream<StreamResolutionMetadata> get resolutionStream => _resolutionController.stream;
  Stream<Map<String, dynamic>> get playbackSettingsStream => _playbackSettingsController.stream;

  bool _isShuffleEnabled = false, _isAutoplayEnabled = true, _isFadeEnabled = true, _isFading = false;
  LoopMode _loopMode = LoopMode.off;
  int _autoplayDelaySeconds = 0, _crossfadeSeconds = 0, _playSessionEpoch = 0;
  int? _sleepTimerRemainingMinutes;
  int? get sleepTimerRemainingMinutes => _sleepTimerRemainingMinutes;
  Timer? _sleepTimer;
  DateTime? _songStartTime;
  Duration? _lastSavedPosition;
  StreamResolutionMetadata? _lastResolution;
  StreamResolutionMetadata? get lastResolution => _lastResolution;

  AudioPlayerService._internal() {
    _initAudioSession();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _onSongCompleted();
    });
    _player.positionStream.listen((pos) {
      if (_currentSong != null && pos.inSeconds > 0 && pos.inSeconds % 5 == 0) {
        NoctraLocalDatabase().savePlaybackPosition(_currentSong, pos.inMilliseconds);
      }
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  void setAutoplayDelay(int sec) { _autoplayDelaySeconds = sec; _emitSettings(); }
  void setCrossfadeSeconds(int sec) { _crossfadeSeconds = sec; _emitSettings(); }
  void toggleFade(bool enable) { _isFadeEnabled = enable; _emitSettings(); }
  void cancelSleepTimer() => setSleepTimer(0);

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _isFading = false;
    if (minutes <= 0) { _sleepTimerRemainingMinutes = null; _emitSettings(); return; }
    _sleepTimerRemainingMinutes = minutes; _emitSettings();
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) async {
      if (_sleepTimerRemainingMinutes != null && _sleepTimerRemainingMinutes! > 1) {
        _sleepTimerRemainingMinutes = _sleepTimerRemainingMinutes! - 1; _emitSettings();
      } else {
        t.cancel(); _sleepTimerRemainingMinutes = null; _emitSettings();
        _isFading = true;
        for (int i = 10; i >= 0; i--) {
          if (!_isFading) return;
          await _player.setVolume(i / 10.0);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isFading) {
          await _player.pause();
          await _player.setVolume(1.0);
          _isFading = false;
        }
      }
    });
  }

  Future<void> restoreLastPlaybackSession() async {
    try {
      final saved = await NoctraLocalDatabase().loadPlaybackPosition();
      if (saved != null && saved['song'] != null) {
        _currentSong = saved['song'] as Song;
        _lastSavedPosition = Duration(milliseconds: saved['positionMs'] ?? 0);
        _queue.clear(); _queue.add(_currentSong!); _currentIndex = 0;
        _currentSongController.add(_currentSong); _queueController.add(_queue);
      }
    } catch (_) {}
  }

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

    try { await _player.stop(); } catch (_) {}
    if (epoch != _playSessionEpoch) return;

    final sw = Stopwatch()..start();
    String resolverName = 'Local';
    String? url;

    try {
      if (song.localFilePath != null && song.localFilePath!.isNotEmpty && !kIsWeb) {
        try {
          final f = File(song.localFilePath!);
          if (f.existsSync() && f.lengthSync() > 1024) { resolverName = 'LocalFile'; url = song.localFilePath; }
        } catch (_) {}
      }
      if (url == null && song.streamUrl != null && song.streamUrl!.isNotEmpty && song.streamUrl!.contains('saavncdn.com')) {
        resolverName = 'JioSaavn320k'; url = song.streamUrl;
      } else if (url == null && song.id.startsWith('jam_')) {
        resolverName = 'JamendoDirect'; url = song.streamUrl;
      } else if (url == null) {
        resolverName = 'CompositeResolver'; url = await CompositeStreamResolver.resolve(song);
      }
      sw.stop();
      _lastResolution = StreamResolutionMetadata(songId: song.id, songTitle: song.title, resolvedUrl: url, resolverUsed: resolverName, resolutionMs: sw.elapsedMilliseconds, timestamp: DateTime.now());
      if (_lastResolution != null) _resolutionController.add(_lastResolution!);

      if (url == null || url.isEmpty) url = await CompositeStreamResolver.resolve(song);

      if (url != null && url.isNotEmpty) {
        final startPos = initialPosition ?? _lastSavedPosition;
        final mediaItem = MediaItem(id: song.id, album: song.album, title: song.title, artist: song.artist, artUri: (song.artworkUrl != null && song.artworkUrl!.startsWith('http')) ? Uri.parse(song.artworkUrl!) : null, duration: song.duration);

        bool loaded = false;
        try {
          final src = url.startsWith('http') ? AudioSource.uri(Uri.parse(url), tag: mediaItem) : AudioSource.file(url, tag: mediaItem);
          await _player.setAudioSource(src, initialPosition: startPos);
          loaded = true;
        } catch (_) {
          CompositeStreamResolver.invalidateCache(song.id);
          for (int tier = 1; tier < 6; tier++) {
            try {
              final fallbackUrl = await CompositeStreamResolver.resolve(song, startTier: tier);
              if (fallbackUrl != null && fallbackUrl.isNotEmpty && fallbackUrl != url) {
                await _player.setAudioSource(AudioSource.uri(Uri.parse(fallbackUrl), tag: mediaItem), initialPosition: startPos);
                loaded = true;
                break;
              }
            } catch (_) {}
          }
        }

        if (loaded && epoch == _playSessionEpoch) {
          await _player.setVolume(1.0);
          await _player.play();
          _lastSavedPosition = null;
          if (song.id.length == 11) {
            MusicService.fetchSponsorBlockIntroSkip(song.id).then((skip) {
              if (skip != null && skip > 3.0 && _currentSong?.id == song.id) _player.seek(Duration(milliseconds: (skip * 1000).toInt()));
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Playback error: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.setVolume(1.0);
      if (_player.audioSource == null && _currentSong != null) {
        await playSong(_currentSong!, initialPosition: _lastSavedPosition);
      } else {
        await _player.play();
      }
    }
  }

  Future<void> skipNext() async {
    if (_songStartTime != null && _currentSong != null) {
      final playedSec = DateTime.now().difference(_songStartTime!).inSeconds;
      if (playedSec < 15) MusicRepository().updateTasteVector(_currentSong!, 'fast_skip');
      NoctraLocalDatabase().recordManifest(_currentSong!, action: 'skip', listenedSeconds: playedSec);
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
  }

  Future<void> skipPrevious() async {
    if (_player.position.inSeconds > 4) { await _player.seek(Duration.zero); return; }
    if (_currentIndex > 0 && _queue.isNotEmpty) { _currentIndex--; await playSong(_queue[_currentIndex]); }
  }

  Future<void> seek(Duration pos) => _player.seek(pos);
  Future<void> setVolume(double vol) => _player.setVolume((vol.isNaN || vol.isInfinite) ? 1.0 : vol.clamp(0.0, 1.0));

  Future<void> stopAndDismiss() async {
    try { await _player.stop(); } catch (_) {}
    _currentSong = null; _currentSongController.add(null);
  }

  Future<void> toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    await _player.setShuffleModeEnabled(_isShuffleEnabled);
    _emitSettings();
  }

  void toggleAutoplay() { _isAutoplayEnabled = !_isAutoplayEnabled; _emitSettings(); }

  Future<void> toggleLoopMode() async {
    _loopMode = _loopMode == LoopMode.off ? LoopMode.all : (_loopMode == LoopMode.all ? LoopMode.one : LoopMode.off);
    await _player.setLoopMode(_loopMode);
    _emitSettings();
  }

  static const _effectsChannel = MethodChannel('com.noctra.app/audio_effects');

  void applyStudioMasterMode(StudioMasterMode mode) {
    try {
      final name = mode == StudioMasterMode.spatial3d ? 'spatial3d' : (mode == StudioMasterMode.concertReverb ? 'concertReverb' : 'studioMaster');
      _effectsChannel.invokeMethod('applyStudioMode', {'mode': name});
    } catch (_) {}
  }

  void applyEqualizer({List<double>? bands, double? bassBoost, double? virtualizer}) {
    try {
      _effectsChannel.invokeMethod('applyEqualizer', {'bands': bands ?? [0.5, 0.5, 0.5, 0.5, 0.5], 'bassBoost': bassBoost ?? 0.0, 'virtualizer': virtualizer ?? 0.0});
    } catch (_) {}
  }

  void _emitSettings() {
    _playbackSettingsController.add({'shuffle': _isShuffleEnabled, 'loopMode': _loopMode, 'autoplay': _isAutoplayEnabled, 'delay': _autoplayDelaySeconds, 'crossfade': _crossfadeSeconds, 'sleepTimer': _sleepTimerRemainingMinutes, 'fade': _isFadeEnabled});
  }

  void _onSongCompleted() async {
    final playedSec = _songStartTime != null ? DateTime.now().difference(_songStartTime!).inSeconds : 210;
    if (_currentSong != null) {
      MusicRepository().updateTasteVector(_currentSong!, 'complete_listen');
      NoctraLocalDatabase().recordManifest(_currentSong!, action: 'complete', listenedSeconds: playedSec);
    }
    if (_loopMode == LoopMode.one && _currentSong != null) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else {
      if (_isAutoplayEnabled && _autoplayDelaySeconds > 0) await Future.delayed(Duration(seconds: _autoplayDelaySeconds));
      skipNext();
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
