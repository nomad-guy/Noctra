import 'dart:async';
import '../../../../shared/models/models.dart';

/// Pure domain contract for high-level playback orchestration.
///
/// Application and UI layers interact with this contract rather than
/// binding directly to `just_audio` or OS player delegates.
abstract interface class PlaybackControllerContract {
  /// Starts or transitions playback to [song].
  Future<void> playSong(Song song);

  /// Pauses the active audio session.
  Future<void> pause();

  /// Resumes playback of the current track.
  Future<void> resume();

  /// Stops playback and releases transient buffering resources.
  Future<void> stop();

  /// Seeks to [position] within the active track.
  Future<void> seek(Duration position);

  /// Advances to the next track in the queue.
  Future<void> skipToNext();

  /// Returns to the previous track or restarts the current track.
  Future<void> skipToPrevious();

  /// Sets audio output volume ([0.0] to [1.0]).
  Future<void> setVolume(double volume);

  /// Sets crossfade transition duration in seconds (0 = disabled).
  void setCrossfadeSeconds(int seconds);

  /// Currently loaded song, or null if idle.
  Song? get currentSong;

  /// Whether audio is actively playing.
  bool get isPlaying;

  /// Active playback position.
  Duration get currentPosition;

  /// Total duration of the active song.
  Duration? get duration;

  /// Broadcast stream of current song transitions.
  Stream<Song?> get currentSongStream;

  /// Broadcast stream of play/pause state transitions.
  Stream<bool> get isPlayingStream;

  /// Broadcast stream of playback position updates.
  Stream<Duration> get positionStream;

  /// Broadcast stream of buffered network position updates.
  Stream<Duration> get bufferedPositionStream;
}
