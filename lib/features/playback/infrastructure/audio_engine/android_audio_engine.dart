import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../../../core/platform/contracts/playback_engine.dart';

/// Android-specific implementation of [PlaybackEngine].
///
/// Wraps [AudioPlayer] with native audio attributes and state mapping.
class AndroidAudioEngine implements PlaybackEngine {
  final AudioPlayer _player;
  final bool _ownsPlayer;
  final StreamController<EnginePlaybackState> _stateController =
      StreamController<EnginePlaybackState>.broadcast();
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  EnginePlaybackState _currentState = EnginePlaybackState.initial;

  AndroidAudioEngine({AudioPlayer? player})
      : _player = player ?? AudioPlayer(),
        _ownsPlayer = player == null {
    _initListeners();
  }

  void _initListeners() {
    _playerStateSub = _player.playerStateStream.listen((ps) {
      final status = _mapProcessingState(ps.processingState);
      _currentState = EnginePlaybackState(
        isPlaying: ps.playing,
        status: status,
        position: _player.position,
        duration: _player.duration,
        bufferedPosition: _player.bufferedPosition,
        volume: _player.volume,
        speed: _player.speed,
      );
      if (!_stateController.isClosed) {
        _stateController.add(_currentState);
      }
    });
  }

  EnginePlaybackStatus _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return EnginePlaybackStatus.idle;
      case ProcessingState.loading:
        return EnginePlaybackStatus.loading;
      case ProcessingState.buffering:
        return EnginePlaybackStatus.buffering;
      case ProcessingState.ready:
        return EnginePlaybackStatus.ready;
      case ProcessingState.completed:
        return EnginePlaybackStatus.completed;
    }
  }

  @override
  Future<void> load(String uri, {Duration? initialPosition}) async {
    await _player.setUrl(uri, initialPosition: initialPosition);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed.clamp(0.25, 3.0));

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<EnginePlaybackState> get stateStream => _stateController.stream;

  @override
  EnginePlaybackState get currentState => _currentState;

  @override
  Future<void> dispose() async {
    await _playerStateSub?.cancel();
    await _positionSub?.cancel();
    await _stateController.close();
    if (_ownsPlayer) {
      await _player.dispose();
    }
  }
}
