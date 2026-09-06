import 'dart:async';

/// Generic states of a playback engine.
enum EnginePlaybackStatus {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

/// Snapshot of the playback state.
class EnginePlaybackState {
  final bool isPlaying;
  final EnginePlaybackStatus status;
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final double volume;
  final double speed;
  final String? errorMessage;

  const EnginePlaybackState({
    required this.isPlaying,
    required this.status,
    required this.position,
    this.duration,
    required this.bufferedPosition,
    this.volume = 1.0,
    this.speed = 1.0,
    this.errorMessage,
  });

  static const initial = EnginePlaybackState(
    isPlaying: false,
    status: EnginePlaybackStatus.idle,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
  );
}

/// Abstract contract for a low-level platform audio engine.
///
/// Implementations may wrap `just_audio`, native ExoPlayer, AVPlayer,
/// WASAPI, or a custom audio pipeline.
abstract interface class PlaybackEngine {
  Future<void> load(String uri, {Duration? initialPosition});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<EnginePlaybackState> get stateStream;
  EnginePlaybackState get currentState;

  Future<void> dispose();
}
