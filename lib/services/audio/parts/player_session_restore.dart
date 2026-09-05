part of '../audio_player_service.dart';

/// Mixin handling last-playback-session restoration from local persistence.
/// Kept separate from the lifecycle/listener mixin so both files stay small
/// and each owns one responsibility: session persistence here, audio
/// session + listeners in PlayerLifecycleMixin.
mixin PlayerSessionRestoreMixin on AudioPlayerServiceBase {
  /// Restore the last persisted playback session (queue, song, position,
  /// shuffle and loop state). Serialized with every other playback op so a
  /// restore can never interleave with a user-triggered play/pause/skip.
  Future<void> restoreLastPlaybackSession({bool autoPlay = false}) {
    return _serialize(
        () => _restoreLastPlaybackSessionInternal(autoPlay: autoPlay));
  }

  Future<void> _restoreLastPlaybackSessionInternal(
      {bool autoPlay = false}) async {
    try {
      final saved = await NoctraLocalDatabase().loadPlaybackSession();
      if (saved == null) return;
      final restoredSong = saved['song'] as Song?;
      final restoredQueue = (saved['queue'] as List<Song>?) ?? [];
      final restoredIndex = (saved['currentIndex'] as int?) ?? 0;
      final isShuffle = saved['isShuffle'] == true;
      final loopModeStr = saved['loopMode'] as String? ?? 'off';

      if (restoredSong == null && restoredQueue.isEmpty) return;

      _mutateQueue(() {
        _queue.clear();
        if (restoredQueue.isNotEmpty) {
          _queue.addAll(restoredQueue);
          _currentIndex = restoredIndex.clamp(0, _queue.length - 1);
          _currentSong = _queue[_currentIndex];
        } else if (restoredSong != null) {
          _queue.add(restoredSong);
          _currentIndex = 0;
          _currentSong = restoredSong;
        }
        return true;
      });

      if (_currentSong == null) return;
      _lastSavedSongId = _currentSong!.id;
      _lastSavedPosition =
          Duration(milliseconds: (saved['positionMs'] as int?) ?? 0);

      _isShuffleEnabled = isShuffle;
      if (loopModeStr == 'one') {
        _loopMode = LoopMode.one;
      } else if (loopModeStr == 'all') {
        _loopMode = LoopMode.all;
      } else {
        _loopMode = LoopMode.off;
      }

      if (!_currentSongController.isClosed) {
        _currentSongController.add(_currentSong);
      }
      final resolved = await _resolveUrl(_currentSong!);
      final url = _extractUrl(resolved);
      if (url.isNotEmpty) {
        final src = url.startsWith('http')
            ? AudioSource.uri(Uri.parse(url),
                tag: _createMediaItem(_currentSong!))
            : AudioSource.file(url, tag: _createMediaItem(_currentSong!));
        await _player.setAudioSource(src, initialPosition: _lastSavedPosition);
        if (autoPlay) {
          await _player.setVolume(_targetVolume);
          _playNonBlocking(_player, 'restoreSession');
        }
      }
    } catch (e) {
      NoctraLogger.w('restoreLastPlaybackSession failed', e);
    }
  }
}
