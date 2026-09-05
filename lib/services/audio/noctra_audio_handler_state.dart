import 'package:audio_service/audio_service.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import 'audio_player_service.dart';

/// Helper to serialize and mirror AudioPlayerService state into audio_service's
/// MediaItem and PlaybackState streams, skipping redundant updates.
class NoctraAudioHandlerStateMirror {
  String? _lastSongKey;
  bool _lastPlaying = false;
  String _lastProcessing = 'idle';
  int _lastPositionSec = -1;
  int _lastDurationMs = -1;
  int _lastQueueIndex = -1;
  String _lastRepeat = 'none';
  bool _lastShuffle = false;
  bool _lastFavorite = false;

  void push({
    required Song? song,
    required AudioPlayerService svc,
    required void Function(MediaItem?) pushMediaItem,
    required void Function(PlaybackState) pushPlaybackState,
    bool forceSong = false,
  }) {
    _pushSong(song, svc, pushMediaItem, force: forceSong);
    _pushState(song, svc, pushPlaybackState);
  }

  void _pushSong(
    Song? song,
    AudioPlayerService svc,
    void Function(MediaItem?) pushMediaItem, {
    required bool force,
  }) {
    if (song == null) {
      if (_lastSongKey != null || force) {
        _lastSongKey = null;
        pushMediaItem(null);
      }
      return;
    }
    final duration = playerDuration(song, svc);
    final key = '${song.id}|${song.title}|${song.artist}|'
        '${song.album}|${song.artworkUrl}|$duration';
    if (key == _lastSongKey && !force) return;
    _lastSongKey = key;
    pushMediaItem(MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: duration,
      artUri: (song.artworkUrl != null && song.artworkUrl!.startsWith('http'))
          ? Uri.tryParse(song.artworkUrl!)
          : null,
      playable: true,
    ));
  }

  Duration? playerDuration(Song song, AudioPlayerService svc) {
    if (svc.currentSong?.id == song.id) {
      final live = svc.player.duration;
      if (live != null && live > Duration.zero) return live;
    }
    return song.duration;
  }

  void _pushState(
    Song? song,
    AudioPlayerService svc,
    void Function(PlaybackState) pushPlaybackState,
  ) {
    final player = svc.player;
    final playing = player.playing;
    final processingName = song == null ? 'idle' : player.processingState.name;
    final processing = switch (processingName) {
      'loading' => AudioProcessingState.loading,
      'buffering' => AudioProcessingState.buffering,
      'ready' => AudioProcessingState.ready,
      'completed' => AudioProcessingState.completed,
      _ => AudioProcessingState.idle,
    };
    final position = (song == null || processing == AudioProcessingState.idle)
        ? Duration.zero
        : player.position;
    final durationMs =
        song == null ? -1 : (playerDuration(song, svc)?.inMilliseconds ?? -1);
    final queueIndex = song == null ? null : svc.currentIndex;
    final repeat = svc.loopMode.name;
    final shuffle = svc.isShuffleEnabled;
    final isFav = song != null && MusicRepository().isFavorite(song.id);

    final posSec = position.inSeconds;
    if (playing == _lastPlaying &&
        processingName == _lastProcessing &&
        posSec == _lastPositionSec &&
        durationMs == _lastDurationMs &&
        queueIndex == _lastQueueIndex &&
        repeat == _lastRepeat &&
        shuffle == _lastShuffle &&
        isFav == _lastFavorite) {
      return;
    }
    _lastPlaying = playing;
    _lastProcessing = processingName;
    _lastPositionSec = posSec;
    _lastDurationMs = durationMs;
    _lastQueueIndex = queueIndex ?? -1;
    _lastRepeat = repeat;
    _lastShuffle = shuffle;
    _lastFavorite = isFav;

    final favControl = MediaControl.custom(
      androidIcon:
          isFav ? 'drawable/ic_favorite' : 'drawable/ic_favorite_border',
      label: isFav ? 'Unlike' : 'Like',
      name: 'toggleFavorite',
      extras: song != null ? {'trackId': song.id} : null,
    );

    pushPlaybackState(PlaybackState(
      controls: [
        favControl,
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [1, 2, 3],
      processingState: processing,
      playing: playing,
      updatePosition: position,
      bufferedPosition: position,
      speed: player.speed,
      queueIndex: queueIndex,
      repeatMode: switch (repeat) {
        'all' => AudioServiceRepeatMode.all,
        'one' => AudioServiceRepeatMode.one,
        _ => AudioServiceRepeatMode.none,
      },
      shuffleMode:
          shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }
}
