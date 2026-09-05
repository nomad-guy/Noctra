part of '../audio_player_service.dart';

/// Mixin providing the primary public playback controls and skip sequencing.
mixin PlayerPlaybackMixin on AudioPlayerServiceBase {
  @override
  Future<void> playSong(Song song,
      {List<Song>? newQueue, Duration? initialPosition, int? queueIndex}) {
    return _serialize(() => _playSongInternal(song,
        newQueue: newQueue,
        initialPosition: initialPosition,
        queueIndex: queueIndex));
  }

  Future<void> skipNext() {
    return _serialize(() => _skipNextInternal());
  }

  Future<void> resumeOrPlay() => _serialize(() async {
        if (_player.playing) {
          _invalidatePlaybackOperations();
          _transitionEpoch++;
          try {
            await _player.pause();
          } catch (e) {
            NoctraLogger.w('pause failed in resumeOrPlay', e);
          }
        } else {
          if (_player.processingState == ProcessingState.idle &&
              _currentSong != null) {
            await _playSongInternal(_currentSong!);
          } else {
            _playNonBlocking(_player, 'resumeOrPlay');
          }
        }
      });

  Future<void> togglePlayPause() => resumeOrPlay();

  Future<void> skipPrevious() => _serialize(() async {
        if (_player.position.inSeconds > 4) {
          try {
            await _player.seek(Duration.zero);
          } catch (_) {}
          _invalidatePlaybackOperations();
          _transitionEpoch++;
          return;
        }
        if (_currentIndex > 0 && _queue.isNotEmpty) {
          _currentIndex--;
          await _playSongInternal(_queue[_currentIndex],
              queueIndex: _currentIndex);
        }
      });

  Future<void> seek(Duration pos) => _serialize(() async {
        _invalidatePlaybackOperations();
        _transitionEpoch++;
        try {
          await _player.seek(pos);
        } catch (_) {}
      });

  @override
  void pause() {
    _invalidatePlaybackOperations();
    _transitionEpoch++;
    _playSessionEpoch++;
    unawaited(_player.pause().catchError((e) {
      NoctraLogger.w('pause failed', e);
    }));
  }

  Future<void> setVolume(double vol) {
    final newVol = (vol.isNaN || vol.isInfinite) ? 1.0 : vol.clamp(0.0, 1.0);
    _targetVolume = newVol;
    _volumeEpoch++;
    return _player.setVolume(newVol);
  }

  Future<void> stopAndDismiss() => _serialize(() async {
        _invalidatePlaybackOperations();
        _transitionEpoch++;
        _playSessionEpoch++;
        try {
          await _player.stop();
        } catch (_) {}
        _invalidatePreload();
        _currentSong = null;
        if (!_currentSongController.isClosed) {
          _currentSongController.add(null);
        }
      });

  // ─── Test seams for end-of-song signal idempotency ─────────────────────

  @visibleForTesting
  void debugSetSongStartTimestamp(DateTime value) {
    _songStartTime = value;
  }

  @visibleForTesting
  Future<void> debugSimulateNaturalSongCompletion() async {
    await _onSongCompletedInternal();
  }

  @override
  Future<void> _skipNextInternal() async {
    if (_transitionInProgress) {
      return;
    }
    _transitionInProgress = true;
    final myId = ++_transitionId;
    try {
      if (_currentSong != null) {
        // Consume the start timestamp so the end-of-song signal fires at
        // most once per track: when a skip happens right after natural
        // completion, _onSongCompletedInternal already recorded this track
        // and cleared the timestamp, so this branch records nothing twice.
        final start = _songStartTime;
        _songStartTime = null;
        if (start != null) {
          final playedSec = DateTime.now().difference(start).inSeconds;
          ImplicitSignalTracker().trackPlaybackEnd(
              song: _currentSong!,
              listenedSeconds: playedSec,
              totalDuration: _currentSong!.duration);
          NoctraLocalDatabase().recordManifest(_currentSong!,
              action: playedSec < 15 ? 'skip' : 'play',
              listenedSeconds: playedSec);
        }
      }
      if (_queue.isNotEmpty) {
        if (_currentIndex >= _queue.length - 1 &&
            _isAutoplayEnabled &&
            _currentSong != null) {
          await _ensureAutoplayQueue(_playSessionEpoch, _queueRevision);
        }
        _currentIndex = (_currentIndex + 1) % _queue.length;
        final nextSong = _queue[_currentIndex];
        if (_isFadeEnabled && _crossfadeSeconds > 0) {
          await _crossfadeToNext(nextSong, myId);
        } else {
          await _playSongInternal(nextSong);
        }
      }
    } finally {
      if (_transitionId == myId) {
        _transitionInProgress = false;
      }
    }
  }
}
