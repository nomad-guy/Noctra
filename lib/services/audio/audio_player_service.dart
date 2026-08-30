import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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
  StreamResolutionMetadata({required this.songId, required this.songTitle, this.resolvedUrl, required this.resolverUsed, required this.resolutionMs, required this.timestamp});
}

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;
  Song? _currentSong; Song? get currentSong => _currentSong;
  final List<Song> _queue = []; List<Song> get queue => List.unmodifiable(_queue);
  int _currentIndex = -1; int get currentIndex => _currentIndex;
  bool _isShuffleEnabled = false, _isAutoplayEnabled = true, _isFadeEnabled = true;
  bool get isShuffleEnabled => _isShuffleEnabled; bool get isAutoplayEnabled => _isAutoplayEnabled; bool get isFadeEnabled => _isFadeEnabled;
  int _autoplayDelaySeconds = 3, _crossfadeSeconds = 4;
  int get autoplayDelaySeconds => _autoplayDelaySeconds; int get crossfadeSeconds => _crossfadeSeconds;
  int? _sleepTimerRemainingMinutes; int? get sleepTimerRemainingMinutes => _sleepTimerRemainingMinutes;
  Timer? _sleepTimer; LoopMode _loopMode = LoopMode.off; LoopMode get loopMode => _loopMode;
  DateTime? _songStartTime; StreamResolutionMetadata? _lastResolution; StreamResolutionMetadata? get lastResolution => _lastResolution;
  Duration? _lastSavedPosition;

  final _currentSongController = StreamController<Song?>.broadcast();
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  final _queueController = StreamController<List<Song>>.broadcast();
  Stream<List<Song>> get queueStream => _queueController.stream;
  final _resolutionController = StreamController<StreamResolutionMetadata?>.broadcast();
  Stream<StreamResolutionMetadata?> get resolutionStream => _resolutionController.stream;
  final _playbackSettingsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get playbackSettingsStream => _playbackSettingsController.stream;

  AudioPlayerService._internal() {
    _initAudioSession();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _onSongCompleted();
    });
    _player.positionStream.listen((pos) {
      if (_currentSong != null && pos.inSeconds % 5 == 0) {
        NoctraLocalDatabase().savePlaybackPosition(_currentSong, pos.inMilliseconds);
      }
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  void setAutoplayDelay(int sec) { _autoplayDelaySeconds = sec; _emitSettings(); }
  void setCrossfadeSeconds(int sec) { _crossfadeSeconds = sec; _emitSettings(); }
  void toggleFade(bool enable) { _isFadeEnabled = enable; _emitSettings(); }
  void cancelSleepTimer() => setSleepTimer(0);

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) { _sleepTimerRemainingMinutes = null; _emitSettings(); return; }
    _sleepTimerRemainingMinutes = minutes; _emitSettings();
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) async {
      if (_sleepTimerRemainingMinutes != null && _sleepTimerRemainingMinutes! > 1) {
        _sleepTimerRemainingMinutes = _sleepTimerRemainingMinutes! - 1; _emitSettings();
      } else {
        t.cancel(); _sleepTimerRemainingMinutes = null; _emitSettings();
        for (int i = 10; i >= 0; i--) { await _player.setVolume(i / 10.0); await Future.delayed(const Duration(milliseconds: 100)); }
        await _player.pause(); await _player.setVolume(1.0);
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
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue.clear(); _queue.addAll(newQueue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) { _queue.insert(0, song); _currentIndex = 0; }
    } else if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song); _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }

    _queueController.add(_queue);
    _currentSong = song;
    _currentSongController.add(_currentSong);
    _songStartTime = DateTime.now();
    MusicRepository().recordSongPlayed(song);

    try { await _player.stop(); } catch (_) {}

    final sw = Stopwatch()..start();
    String resolverName = 'Local';
    String? url;

    try {
      if (song.localFilePath != null && song.localFilePath!.isNotEmpty) {
        resolverName = 'LocalFile'; url = song.localFilePath;
      } else if (song.streamUrl != null && song.streamUrl!.isNotEmpty && song.streamUrl!.contains('saavncdn.com')) {
        resolverName = 'JioSaavn320k'; url = song.streamUrl;
      } else if (song.id.startsWith('jam_')) {
        resolverName = 'JamendoDirect'; url = song.streamUrl;
      } else {
        resolverName = 'CompositeResolver'; url = await MusicService.resolveStreamUrl(song);
      }
      sw.stop();
      _lastResolution = StreamResolutionMetadata(songId: song.id, songTitle: song.title, resolvedUrl: url, resolverUsed: resolverName, resolutionMs: sw.elapsedMilliseconds, timestamp: DateTime.now());
      _resolutionController.add(_lastResolution);

      if (url == null || url.isEmpty) {
        url = await MusicService.resolveStreamUrl(song);
      }

      if (url != null && url.isNotEmpty) {
        final startPos = initialPosition ?? _lastSavedPosition;
        final mediaItem = MediaItem(
          id: song.id,
          album: song.album,
          title: song.title,
          artist: song.artist,
          artUri: (song.artworkUrl != null && song.artworkUrl!.startsWith('http')) ? Uri.parse(song.artworkUrl!) : null,
          duration: song.duration,
        );

        bool loaded = false;
        try {
          if (url.startsWith('http')) {
            await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: mediaItem), initialPosition: startPos);
          } else {
            await _player.setAudioSource(AudioSource.file(url, tag: mediaItem), initialPosition: startPos);
          }
          loaded = true;
        } catch (_) {
          // Automatic fallback to YouTube Music / InnerTube if initial CDN stream failed
          try {
            final fallbackUrl = await CompositeStreamResolver.resolve(song);
            if (fallbackUrl != null && fallbackUrl.isNotEmpty && fallbackUrl != url) {
              await _player.setAudioSource(AudioSource.uri(Uri.parse(fallbackUrl), tag: mediaItem), initialPosition: startPos);
              loaded = true;
            }
          } catch (_) {}
        }

        if (loaded) {
          await _player.setVolume(1.0);
          await _player.play();
          _lastSavedPosition = null;

          if (song.id.length == 11) {
            MusicService.fetchSponsorBlockIntroSkip(song.id).then((skip) {
              if (skip != null && skip > 3.0 && _currentSong?.id == song.id) {
                _player.seek(Duration(milliseconds: (skip * 1000).toInt()));
              }
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
    }
    if (_queue.isNotEmpty) {
      if (_currentIndex >= _queue.length - 1 && _isAutoplayEnabled && _currentSong != null) {
        final similar = await MusicService.fetchSimilarRadioQueue(_currentSong!);
        if (similar.isNotEmpty) {
          for (final s in similar) {
            if (!_queue.any((q) => q.id == s.id)) _queue.add(s);
          }
          _queueController.add(_queue);
        }
      }
      _currentIndex = (_currentIndex + 1) % _queue.length;
      await playSong(_queue[_currentIndex]);
    }
  }

  Future<void> skipPrevious() async {
    if (_player.position.inSeconds > 4) { await _player.seek(Duration.zero); return; }
    if (_currentIndex > 0 && _queue.isNotEmpty) {
      _currentIndex--; await playSong(_queue[_currentIndex]);
    }
  }

  Future<void> seek(Duration pos) => _player.seek(pos);
  Future<void> setVolume(double vol) => _player.setVolume(vol);

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

  void applyStudioMasterMode(StudioMasterMode mode) {
    try {
      if (mode == StudioMasterMode.spatial3d) {
        _player.setSpeed(1.0); _player.setPitch(1.0);
      } else if (mode == StudioMasterMode.concertReverb) {
        _player.setSpeed(0.98); _player.setPitch(0.99);
      } else {
        _player.setSpeed(1.0); _player.setPitch(1.0);
      }
    } catch (_) {}
  }

  void applyEqualizer({List<double>? bands, double? bassBoost, double? virtualizer}) {
    try {
      if (bassBoost != null && bassBoost > 0.5) _player.setVolume(1.0);
    } catch (_) {}
  }

  void _emitSettings() {
    _playbackSettingsController.add({'shuffle': _isShuffleEnabled, 'loopMode': _loopMode, 'autoplay': _isAutoplayEnabled, 'delay': _autoplayDelaySeconds, 'crossfade': _crossfadeSeconds, 'sleepTimer': _sleepTimerRemainingMinutes, 'fade': _isFadeEnabled});
  }

  void _onSongCompleted() async {
    if (_currentSong != null) MusicRepository().updateTasteVector(_currentSong!, 'complete_listen');
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
