import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/platform/contracts/playback_engine.dart';
import 'package:noctra/core/platform/contracts/media_control_service.dart';
import 'package:noctra/core/platform/media/no_op_media_controls.dart';

class FakePlaybackEngine implements PlaybackEngine {
  final _stateController = StreamController<EnginePlaybackState>.broadcast();
  final _posController = StreamController<Duration>.broadcast();
  final _bufController = StreamController<Duration>.broadcast();
  final _durController = StreamController<Duration?>.broadcast();

  EnginePlaybackState _state = EnginePlaybackState.initial;

  @override
  Future<void> load(String uri, {Duration? initialPosition}) async {
    _state = EnginePlaybackState(
      isPlaying: false,
      status: EnginePlaybackStatus.ready,
      position: initialPosition ?? Duration.zero,
      bufferedPosition: Duration.zero,
      duration: const Duration(minutes: 3),
    );
    _stateController.add(_state);
  }

  @override
  Future<void> play() async {
    _state = EnginePlaybackState(
      isPlaying: true,
      status: EnginePlaybackStatus.ready,
      position: _state.position,
      bufferedPosition: _state.bufferedPosition,
      duration: _state.duration,
      volume: _state.volume,
    );
    _stateController.add(_state);
  }

  @override
  Future<void> pause() async {
    _state = EnginePlaybackState(
      isPlaying: false,
      status: EnginePlaybackStatus.ready,
      position: _state.position,
      bufferedPosition: _state.bufferedPosition,
      duration: _state.duration,
      volume: _state.volume,
    );
    _stateController.add(_state);
  }

  @override
  Future<void> stop() async {
    _state = EnginePlaybackState.initial;
    _stateController.add(_state);
  }

  @override
  Future<void> seek(Duration position) async {
    _state = EnginePlaybackState(
      isPlaying: _state.isPlaying,
      status: _state.status,
      position: position,
      bufferedPosition: _state.bufferedPosition,
      duration: _state.duration,
    );
    _posController.add(position);
    _stateController.add(_state);
  }

  @override
  Future<void> setVolume(double volume) async {
    _state = EnginePlaybackState(
      isPlaying: _state.isPlaying,
      status: _state.status,
      position: _state.position,
      bufferedPosition: _state.bufferedPosition,
      duration: _state.duration,
      volume: volume.clamp(0.0, 1.0),
    );
    _stateController.add(_state);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _state = EnginePlaybackState(
      isPlaying: _state.isPlaying,
      status: _state.status,
      position: _state.position,
      bufferedPosition: _state.bufferedPosition,
      duration: _state.duration,
      speed: speed.clamp(0.25, 3.0),
    );
    _stateController.add(_state);
  }

  @override
  Stream<Duration> get positionStream => _posController.stream;
  @override
  Stream<Duration?> get durationStream => _durController.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufController.stream;
  @override
  Stream<EnginePlaybackState> get stateStream => _stateController.stream;
  @override
  EnginePlaybackState get currentState => _state;

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _posController.close();
    await _bufController.close();
    await _durController.close();
  }
}

void main() {
  group('Cross-Platform PlaybackEngine Contract Tests', () {
    late PlaybackEngine engine;

    setUp(() {
      engine = FakePlaybackEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('Initial state is idle and not playing', () {
      expect(engine.currentState.isPlaying, isFalse);
      expect(engine.currentState.status, EnginePlaybackStatus.idle);
      expect(engine.currentState.position, Duration.zero);
    });

    test('Load transitions to ready state', () async {
      await engine.load('https://example.com/audio.flac');
      expect(engine.currentState.status, EnginePlaybackStatus.ready);
      expect(engine.currentState.isPlaying, isFalse);
    });

    test('Play transitions to playing state', () async {
      await engine.load('https://example.com/audio.flac');
      await engine.play();
      expect(engine.currentState.isPlaying, isTrue);
    });

    test('Pause maintains position and halts playing', () async {
      await engine.load('https://example.com/audio.flac');
      await engine.play();
      await engine.seek(const Duration(seconds: 45));
      await engine.pause();

      expect(engine.currentState.isPlaying, isFalse);
      expect(engine.currentState.position, const Duration(seconds: 45));
    });

    test('Volume is clamped within [0.0, 1.0]', () async {
      await engine.setVolume(1.5);
      expect(engine.currentState.volume, 1.0);

      await engine.setVolume(-0.5);
      expect(engine.currentState.volume, 0.0);
    });
  });

  group('Cross-Platform MediaControlService Tests', () {
    test('NoOpMediaControlService handles commands without crashing', () async {
      final service = NoOpMediaControlService();
      const item = MediaMetadataItem(
        id: 't1',
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        duration: Duration(minutes: 3),
      );

      await service.updateMetadata(item, isPlaying: true);
      expect(service.currentItem?.title, 'Song Title');
      expect(service.isPlaying, isTrue);

      var playTriggered = false;
      final sub = service.playCommandStream.listen((_) => playTriggered = true);
      service.triggerPlay();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(playTriggered, isTrue);
      await sub.cancel();
      service.dispose();
    });
  });
}
