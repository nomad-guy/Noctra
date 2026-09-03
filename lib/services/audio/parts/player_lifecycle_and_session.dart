part of '../audio_player_service.dart';

/// Mixin handling AudioSession configuration, audio focus interruptions,
/// native player error / state / position listeners, session restoration,
/// position persistence, and service teardown.
mixin PlayerLifecycleMixin on AudioPlayerServiceBase {
  // ─── [06] Constructor & audio session ───────────────────────────────────

  Future<void> _initAudioSession() async {
    try {
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  // ─── [07] Player disposal helpers ───────────────────────────────────────

  @override
  Future<void> _disposePlayer(AudioPlayer? p) async {
    if (p == null) {
      return;
    }
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.dispose();
    } catch (_) {}
  }

  // ─── [08] Listener lifecycle ────────────────────────────────────────────

  @override
  Future<void> _attachListeners() async {
    if (_isDisposed) return;
    await _detachListeners();
    if (_isDisposed) return;
    final gen = _listenerGeneration;
    final attachedPlayer = _player;

    _stateSub = _player.playerStateStream.listen((s) {
      if (gen != _listenerGeneration) {
        return;
      }
      if (!identical(attachedPlayer, _player)) {
        return;
      }
      if (_transitionInProgress) {
        return;
      }

      if (s.processingState == ProcessingState.completed) {
        final cbGen = gen;
        final songId = _currentSong?.id;
        final epoch = _playSessionEpoch;
        final player = _player;
        _enqueue(() async {
          if (cbGen != _listenerGeneration) {
            return;
          }
          if (epoch != _playSessionEpoch || _currentSong?.id != songId) {
            return;
          }
          if (!identical(player, _player)) {
            return;
          }
          await _onSongCompletedInternal();
        });
      }

      if (_crossfadePending &&
          _crossfadePendingSongId == _currentSong?.id &&
          _crossfadePendingEpoch == _playSessionEpoch &&
          s.processingState == ProcessingState.ready &&
          _player.playing) {
        _crossfadePending = false;
        _crossfadePendingSongId = null;
        _checkAutoCrossfade(_player.position);
      }
    });

    _errorSub = _player.errorStream.listen((e) {
      if (gen != _listenerGeneration) {
        return;
      }
      if (!identical(attachedPlayer, _player)) {
        return;
      }
      if (_transitionInProgress) {
        return;
      }
      NoctraLogger.e('AudioPlayer error: ${e.toString()}', e);

      final active = _currentSong;
      if (active == null) {
        return;
      }
      final epoch = _playSessionEpoch;
      final failedPlayer = _player;
      final attempts = _recoveryAttemptsByEpoch[epoch] ?? 0;
      if (attempts >= AudioPlayerServiceBase._maxAutomaticRecoveryAttempts) {
        NoctraLogger.w('Recovery limit reached for "${active.title}"', e);
        return;
      }
      if (_recoveryInFlight) {
        return;
      }
      _recoveryInFlight = true;
      final rGen = ++_recoveryGeneration;
      final cbGen = gen;
      _enqueue(() async {
        try {
          if (cbGen != _listenerGeneration) {
            return;
          }
          if (_recoveryGeneration != rGen) {
            return;
          }
          if (_playSessionEpoch != epoch || _currentSong?.id != active.id) {
            return;
          }
          if (!identical(failedPlayer, _player)) {
            return;
          }
          _recoveryAttemptsByEpoch[epoch] = attempts + 1;
          await _playSongInternal(active, initialPosition: _player.position);
          _recoveryAttemptsByEpoch.remove(epoch);
        } finally {
          _recoveryInFlight = false;
        }
      });
    });

    _positionSub = _player.positionStream.listen((pos) {
      if (gen != _listenerGeneration) {
        return;
      }
      if (!identical(attachedPlayer, _player)) {
        return;
      }
      if (_playSessionEpoch != _positionSaveEpoch) {
        return;
      }
      final activeSong = _currentSong;
      if (activeSong != null &&
          _loopMode != LoopMode.one &&
          pos.inSeconds >= 5) {
        final bucket = pos.inSeconds ~/ 5;
        if (bucket > _lastSavedBucket) {
          _lastSavedBucket = bucket;
          if (_restoredPositionUsed && pos.inSeconds < 15) {
            return;
          }
          _restoredPositionUsed = false;
          NoctraLocalDatabase()
              .savePlaybackPosition(activeSong, pos.inMilliseconds)
              .catchError((e) => NoctraLogger.w('Position save failed', e));
        }
      }
      _checkAutoCrossfade(pos);
    });
  }

  @override
  Future<void> _detachListeners() async {
    _listenerGeneration++;
    await Future.wait([
      _stateSub?.cancel() ?? Future.value(),
      _errorSub?.cancel() ?? Future.value(),
      _positionSub?.cancel() ?? Future.value(),
    ]);
    _stateSub = null;
    _errorSub = null;
    _positionSub = null;
  }

  // ─── [26] Persistence ──────────────────────────────────────────────────

  Future<void> restoreLastPlaybackSession({bool autoPlay = false}) {
    return _serialize(
        () => _restoreLastPlaybackSessionInternal(autoPlay: autoPlay));
  }

  Future<void> _restoreLastPlaybackSessionInternal(
      {bool autoPlay = false}) async {
    try {
      final saved = await NoctraLocalDatabase().loadPlaybackPosition();
      if (saved == null || saved['song'] == null) {
        return;
      }
      final restoredSong = saved['song'] as Song?;
      if (restoredSong == null) {
        return;
      }
      _currentSong = restoredSong;
      _lastSavedSongId = _currentSong!.id;
      _lastSavedPosition =
          Duration(milliseconds: (saved['positionMs'] as int?) ?? 0);
      _mutateQueue(() {
        _queue.clear();
        _queue.add(_currentSong!);
        _currentIndex = 0;
        return true;
      });
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

  // ─── [27] Disposal ─────────────────────────────────────────────────────

  void dispose() {
    _isDisposed = true;
    _sleepTimer?.cancel();
    _detachListeners();
    _player.dispose();
    _disposePlayer(_bufferedNext);
    _invalidatePreload();
    _currentSongController.close();
    _queueController.close();
    _resolutionController.close();
    _playbackSettingsController.close();
  }
}
