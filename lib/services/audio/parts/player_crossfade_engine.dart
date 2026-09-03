part of '../audio_player_service.dart';

/// Mixin implementing smooth logarithmic volume crossfades, automatic pre-end
/// transition triggers, manual song crossfades, and atomic player swap commits.
mixin PlayerCrossfadeMixin on AudioPlayerServiceBase {
  // ─── [15] Fade-in ──────────────────────────────────────────────────────

  @override
  Future<void> _fadeIn({Duration? duration}) async {
    if (!_isFadeEnabled) {
      return;
    }
    final dur = duration ?? const Duration(milliseconds: 400);
    const steps = 20;
    final stepDelay = Duration(
        milliseconds: (dur.inMilliseconds / steps).round().clamp(10, 200));
    final vEpoch = ++_volumeEpoch;
    final p = _player;
    try {
      for (var i = 1; i <= steps; i++) {
        if (_volumeEpoch != vEpoch || !identical(p, _player)) {
          return;
        }
        final t = i / steps;
        await p.setVolume(t * t * _targetVolume);
        await Future.delayed(stepDelay);
      }
    } catch (e) {
      NoctraLogger.w('Fade-in failed', e);
      if (_volumeEpoch == vEpoch && identical(p, _player)) {
        try {
          await p.setVolume(_targetVolume);
        } catch (_) {}
      }
    }
  }

  // ─── [16] Crossfade engine (Timer-based) ───────────────────────────────

  Future<CrossfadeResult> _crossfadeTo(
      AudioPlayer nextPlayer, Song nextSong) async {
    final duration = Duration(seconds: _crossfadeSeconds);
    final tEpoch = _transitionEpoch;
    final playEpoch = _playSessionEpoch;
    final vEpoch = ++_volumeEpoch;

    // Buffer check: bufferedAhead relative to player position
    final requiredBuffer =
        Duration(milliseconds: min(_crossfadeSeconds * 1000, 3000));
    const gracePeriod = Duration(milliseconds: 500);
    final readyDeadline = DateTime.now().add(gracePeriod);

    while (nextPlayer.processingState != ProcessingState.ready) {
      if (_transitionEpoch != tEpoch ||
          _playSessionEpoch != playEpoch ||
          _volumeEpoch != vEpoch) {
        return CrossfadeResult.cancelled;
      }
      if (DateTime.now().isAfter(readyDeadline)) {
        NoctraLogger.w('Crossfade readiness timeout');
        return CrossfadeResult.failed;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    final finalBufferedAhead =
        nextPlayer.bufferedPosition - nextPlayer.position;
    if (finalBufferedAhead < requiredBuffer) {
      NoctraLogger.w(
          'Crossfade buffer insufficient: ${finalBufferedAhead.inMilliseconds}ms');
      return CrossfadeResult.failed;
    }

    final oldPlayer = _player;
    // Ramp target captured at start. If the user changes volume mid-fade,
    // setVolume bumps _volumeEpoch which cancels this ramp.
    final targetVol = _targetVolume;
    try {
      await nextPlayer.setVolume(0.0);
      // Seek to zero only if not already there (avoid discarding preload buffer)
      if (nextPlayer.position > const Duration(milliseconds: 100)) {
        await nextPlayer.seek(Duration.zero);
      }
      // Non-blocking play — DO NOT await
      _playNonBlocking(nextPlayer, 'Crossfade new player');

      // Timer-based volume ramp — 24 smooth logarithmic steps (ExoPlayer internally
      // interpolates volume between platform calls, avoiding IPC channel overload)
      const totalSteps = 24;
      int step = 0;
      final stepMs =
          (duration.inMilliseconds / totalSteps).round().clamp(35, 200);
      final completer = Completer<void>();
      Timer.periodic(Duration(milliseconds: stepMs), (timer) {
        step++;
        final progress = step / totalSteps;
        final eased = progress * progress;

        unawaited(
            oldPlayer.setVolume(targetVol * (1.0 - eased)).catchError((_) {}));
        unawaited(nextPlayer.setVolume(targetVol * eased).catchError((_) {}));

        if (step >= totalSteps ||
            _transitionEpoch != tEpoch ||
            _playSessionEpoch != playEpoch ||
            _volumeEpoch != vEpoch ||
            !identical(oldPlayer, _player)) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
        }
      });

      await completer.future;

      // Check if cancelled during ramp
      if (_transitionEpoch != tEpoch ||
          _playSessionEpoch != playEpoch ||
          _volumeEpoch != vEpoch ||
          !identical(oldPlayer, _player)) {
        try {
          await oldPlayer.setVolume(_targetVolume);
        } catch (_) {}
        try {
          await nextPlayer.stop();
        } catch (_) {}
        return CrossfadeResult.cancelled;
      }

      // Post-condition: verify next player is actually healthy before commit
      if (!nextPlayer.playing ||
          nextPlayer.processingState == ProcessingState.idle) {
        NoctraLogger.w('Crossfade: next player unhealthy at commit, aborting');
        try {
          await oldPlayer.setVolume(_targetVolume);
        } catch (_) {}
        try {
          await nextPlayer.stop();
        } catch (_) {}
        return CrossfadeResult.failed;
      }
    } catch (e) {
      try {
        await oldPlayer.setVolume(_targetVolume);
      } catch (_) {}
      try {
        await nextPlayer.stop();
      } catch (_) {}
      return CrossfadeResult.failed;
    }
    try {
      await oldPlayer.stop();
    } catch (_) {}
    return CrossfadeResult.completed;
  }

  // ─── [17] Auto-crossfade ───────────────────────────────────────────────

  @override
  void _checkAutoCrossfade(Duration pos) {
    if (_transitionInProgress) {
      return;
    }
    if (!_isFadeEnabled || _crossfadeSeconds <= 0) {
      return;
    }
    if (_loopMode == LoopMode.one) {
      return;
    }

    final duration = _player.duration;
    if (duration == null) {
      return;
    }
    final crossfadeDur = Duration(seconds: _crossfadeSeconds);
    if (duration <= crossfadeDur) {
      return;
    }

    final triggerPoint = duration - crossfadeDur;
    if (pos < triggerPoint) {
      if (_crossfadePending && _crossfadePendingSongId == _currentSong?.id) {
        _crossfadePending = false;
        _crossfadePendingSongId = null;
      }
      return;
    }

    if (_player.processingState != ProcessingState.ready || !_player.playing) {
      _crossfadePending = true;
      _crossfadePendingSongId = _currentSong?.id;
      _crossfadePendingEpoch = _playSessionEpoch;
      return;
    }

    if (_autoCrossfadeQueued) {
      return;
    }
    _crossfadePending = false;
    _crossfadePendingSongId = null;

    _autoCrossfadeQueued = true;
    final gen = ++_autoCrossfadeGeneration;
    final songId = _currentSong?.id;
    final epoch = _playSessionEpoch;
    _enqueue(() async {
      try {
        if (gen != _autoCrossfadeGeneration) {
          return;
        }
        if (epoch != _playSessionEpoch || _currentSong?.id != songId) {
          return;
        }
        final d = _player.duration;
        final p = _player.position;
        if (d == null || p < d - crossfadeDur) {
          return;
        }
        await _autoCrossfadeNext();
      } finally {
        if (gen == _autoCrossfadeGeneration) {
          _autoCrossfadeQueued = false;
        }
      }
    });
  }

  Future<void> _autoCrossfadeNext() async {
    if (_transitionInProgress) {
      return;
    }
    _transitionInProgress = true;
    final myId = ++_transitionId;
    final epoch = _playSessionEpoch;
    final tEpoch = _transitionEpoch;
    final rev = _queueRevision;

    try {
      Song? nextSong;
      if (_currentIndex < _queue.length - 1) {
        nextSong = _queue[_currentIndex + 1];
      } else if (_isAutoplayEnabled && _currentSong != null) {
        await _ensureAutoplayQueue(epoch, rev);
        if (_currentIndex < _queue.length - 1) {
          nextSong = _queue[_currentIndex + 1];
        }
      }

      if (nextSong == null ||
          epoch != _playSessionEpoch ||
          tEpoch != _transitionEpoch ||
          rev != _queueRevision) {
        return;
      }

      AudioPlayer? nextPlayer;
      if (_bufferedMatches(nextSong)) {
        nextPlayer = _bufferedNext;
        _bufferedNext = null;
        _bufferedNextSong = null;
        _bufferedNextRevision = -1;
      } else {
        nextPlayer = await _preparePlayer(nextSong, epoch);
      }

      if (nextPlayer == null ||
          epoch != _playSessionEpoch ||
          tEpoch != _transitionEpoch ||
          _transitionId != myId) {
        await _disposePlayer(nextPlayer);
        return;
      }

      final result = await _crossfadeTo(nextPlayer, nextSong);
      if (result != CrossfadeResult.completed) {
        await _disposePlayer(nextPlayer);
        if (result == CrossfadeResult.failed &&
            _player.processingState == ProcessingState.completed) {
          await _onSongCompletedInternal();
        }
        return;
      }
      if (epoch != _playSessionEpoch ||
          tEpoch != _transitionEpoch ||
          _transitionId != myId) {
        await _disposePlayer(nextPlayer);
        return;
      }

      await _commitPlayerSwap(nextPlayer, nextSong, epoch, myId);
    } finally {
      if (_transitionId == myId) {
        _transitionInProgress = false;
      }
    }
  }

  // ─── [18] Manual crossfade ─────────────────────────────────────────────

  @override
  Future<void> _crossfadeToNext(Song nextSong, int myId) async {
    final epoch = _playSessionEpoch;
    _transitionEpoch++;
    final tEpoch = _transitionEpoch;
    final rev = _queueRevision;

    AudioPlayer? nextPlayer;
    if (_bufferedMatches(nextSong)) {
      nextPlayer = _bufferedNext;
      _bufferedNext = null;
      _bufferedNextSong = null;
      _bufferedNextRevision = -1;
    } else {
      nextPlayer = await _preparePlayer(nextSong, epoch);
    }

    if (nextPlayer == null ||
        epoch != _playSessionEpoch ||
        tEpoch != _transitionEpoch ||
        rev != _queueRevision ||
        _transitionId != myId) {
      await _disposePlayer(nextPlayer);
      if (nextPlayer == null &&
          tEpoch == _transitionEpoch &&
          epoch == _playSessionEpoch &&
          rev == _queueRevision &&
          _transitionId == myId) {
        await _playSongInternal(nextSong);
      }
      return;
    }

    final result = await _crossfadeTo(nextPlayer, nextSong);
    if (result != CrossfadeResult.completed) {
      await _disposePlayer(nextPlayer);
      if (result == CrossfadeResult.failed &&
          tEpoch == _transitionEpoch &&
          epoch == _playSessionEpoch &&
          rev == _queueRevision &&
          _transitionId == myId) {
        await _playSongInternal(nextSong);
      }
      return;
    }
    if (epoch != _playSessionEpoch ||
        tEpoch != _transitionEpoch ||
        rev != _queueRevision ||
        _transitionId != myId) {
      await _disposePlayer(nextPlayer);
      return;
    }

    await _commitPlayerSwap(nextPlayer, nextSong, epoch, myId);
  }

  // ─── [19] Player swap (commit) ─────────────────────────────────────────

  Future<void> _commitPlayerSwap(
      AudioPlayer nextPlayer, Song nextSong, int epoch, int myId) async {
    var newIndex = _queue.indexOf(nextSong);
    if (newIndex < 0) {
      newIndex = _queue.indexWhere((s) => s.id == nextSong.id);
    }
    if (newIndex < 0 || epoch != _playSessionEpoch || _transitionId != myId) {
      await _disposePlayer(nextPlayer);
      return;
    }
    await _detachListeners();
    final oldPlayer = _player;
    _player = nextPlayer;
    await _attachListeners();
    await _disposePlayer(oldPlayer);
    await applyStudioMasterMode(_studioMasterMode);

    _currentIndex = newIndex;
    _currentSong = nextSong;
    _songStartTime = DateTime.now();
    _positionSaveEpoch = _playSessionEpoch;
    _lastSavedBucket = -1;
    if (!_currentSongController.isClosed) {
      _currentSongController.add(nextSong);
    }
    MusicRepository().recordSongPlayed(nextSong);
    _startPreloadNext();
  }
}
