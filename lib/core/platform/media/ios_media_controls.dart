import 'dart:async';
import '../contracts/media_control_service.dart';

/// iOS-specific implementation of [MediaControlService].
///
/// Dispatches to MPRemoteCommandCenter and MPNowPlayingInfoCenter.
class IOSMediaControlService implements MediaControlService {
  final _playController = StreamController<void>.broadcast();
  final _pauseController = StreamController<void>.broadcast();
  final _nextController = StreamController<void>.broadcast();
  final _prevController = StreamController<void>.broadcast();
  final _seekController = StreamController<Duration>.broadcast();

  MediaMetadataItem? _activeItem;
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  Future<void> updateMetadata(
    MediaMetadataItem item, {
    Duration? position,
    bool isPlaying = false,
  }) async {
    _activeItem = item;
    _isPlaying = isPlaying;
    if (position != null) _position = position;
  }

  @override
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required Duration position,
  }) async {
    _isPlaying = isPlaying;
    _position = position;
  }

  @override
  Future<void> clear() async {
    _activeItem = null;
    _isPlaying = false;
    _position = Duration.zero;
  }

  MediaMetadataItem? get activeItem => _activeItem;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;

  void onRemotePlay() => _playController.add(null);
  void onRemotePause() => _pauseController.add(null);
  void onRemoteNext() => _nextController.add(null);
  void onRemotePrevious() => _prevController.add(null);
  void onRemoteSeek(Duration pos) => _seekController.add(pos);

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
