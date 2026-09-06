import 'dart:async';
import '../contracts/media_control_service.dart';

/// In-memory and test implementation of [MediaControlService].
class NoOpMediaControlService implements MediaControlService {
  final _playController = StreamController<void>.broadcast();
  final _pauseController = StreamController<void>.broadcast();
  final _nextController = StreamController<void>.broadcast();
  final _prevController = StreamController<void>.broadcast();
  final _seekController = StreamController<Duration>.broadcast();

  MediaMetadataItem? currentItem;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;

  @override
  Future<void> updateMetadata(
    MediaMetadataItem item, {
    Duration? position,
    bool isPlaying = false,
  }) async {
    currentItem = item;
    this.isPlaying = isPlaying;
    if (position != null) currentPosition = position;
  }

  @override
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required Duration position,
  }) async {
    this.isPlaying = isPlaying;
    currentPosition = position;
  }

  @override
  Future<void> clear() async {
    currentItem = null;
    isPlaying = false;
    currentPosition = Duration.zero;
  }

  void triggerPlay() => _playController.add(null);
  void triggerPause() => _pauseController.add(null);
  void triggerNext() => _nextController.add(null);
  void triggerPrevious() => _prevController.add(null);
  void triggerSeek(Duration pos) => _seekController.add(pos);

  @override
  Stream<void> get playCommandStream => _playController.stream;
  @override
  Stream<void> get pauseCommandStream => _pauseController.stream;
  @override
  Stream<void> get nextCommandStream => _nextController.stream;
  @override
  Stream<void> get previousCommandStream => _prevController.stream;
  @override
  Stream<Duration> get seekCommandStream => _seekController.stream;

  void dispose() {
    _playController.close();
    _pauseController.close();
    _nextController.close();
    _prevController.close();
    _seekController.close();
  }
}
