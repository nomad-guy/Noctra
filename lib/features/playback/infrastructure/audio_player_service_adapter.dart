import 'dart:async';
import '../../../../services/audio/audio_player_service.dart';
import '../../../../shared/models/models.dart';
import '../domain/contracts/playback_controller_contract.dart';

/// Adapter implementing [PlaybackControllerContract] by delegating to [AudioPlayerService].
///
/// Hides the internal complexity of dual-player crossfade ramps, preload delegates,
/// and Kotlin audio effects behind the clean domain interface.
class AudioPlayerServiceAdapter implements PlaybackControllerContract {
  final AudioPlayerService _service;

  AudioPlayerServiceAdapter({AudioPlayerService? service})
      : _service = service ?? AudioPlayerService();

  @override
  Future<void> playSong(Song song) => _service.playSong(song);

  @override
  Future<void> pause() async {
    _service.pause();
  }

  @override
  Future<void> resume() => _service.resumeOrPlay();

  @override
  Future<void> stop() async {
    await _service.player.stop();
  }

  @override
  Future<void> seek(Duration position) => _service.seek(position);

  @override
  Future<void> skipToNext() => _service.skipNext();

  @override
  Future<void> skipToPrevious() => _service.skipPrevious();

  @override
  Future<void> setVolume(double volume) => _service.setVolume(volume);

  @override
  void setCrossfadeSeconds(int seconds) =>
      _service.setCrossfadeSeconds(seconds);

  @override
  Song? get currentSong => _service.currentSong;

  @override
  bool get isPlaying => _service.player.playing;

  @override
  Duration get currentPosition => _service.player.position;

  @override
  Duration? get duration => _service.player.duration;

  @override
  Stream<Song?> get currentSongStream => _service.currentSongStream;

  @override
  Stream<bool> get isPlayingStream => _service.player.playingStream;

  @override
  Stream<Duration> get positionStream => _service.player.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _service.player.bufferedPositionStream;
}
