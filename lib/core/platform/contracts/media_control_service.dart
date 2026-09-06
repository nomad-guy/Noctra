import 'dart:async';

/// Platform-neutral metadata representation for OS media notifications.
class MediaMetadataItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final Duration? duration;

  const MediaMetadataItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.duration,
  });
}

/// Platform-neutral contract for OS media notifications & lockscreen controls
/// (Android MediaStyle, iOS MPRemoteCommandCenter, Windows SMTC, Linux MPRIS).
abstract interface class MediaControlService {
  Future<void> updateMetadata(MediaMetadataItem item, {Duration? position, bool isPlaying = false});
  Future<void> updatePlaybackState({required bool isPlaying, required Duration position});
  Future<void> clear();

  Stream<void> get playCommandStream;
  Stream<void> get pauseCommandStream;
  Stream<void> get nextCommandStream;
  Stream<void> get previousCommandStream;
  Stream<Duration> get seekCommandStream;
}
