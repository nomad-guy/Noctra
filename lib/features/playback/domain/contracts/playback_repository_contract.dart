import 'dart:async';
import '../../../../shared/models/models.dart';

/// Data representing a saved playback session state.
class SavedPlaybackSession {
  final Song song;
  final Duration position;
  final DateTime timestamp;

  const SavedPlaybackSession({
    required this.song,
    required this.position,
    required this.timestamp,
  });
}

/// Abstract contract for persisting and restoring playback state across app lifecycles.
abstract interface class PlaybackRepositoryContract {
  Future<void> saveSession({required Song song, required Duration position});
  Future<SavedPlaybackSession?> restoreSession();
  Future<void> clearSession();

  Future<void> saveQueue(List<Song> queue, {int activeIndex = 0});
  Future<(List<Song>, int)> restoreQueue();
  Future<void> clearQueue();
}
