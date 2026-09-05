part of '../audio_player_service.dart';

/// Mixin implementing automatic pre-end transition triggers,
/// manual song crossfades, and atomic player swap commits.
mixin PlayerCrossfadeMixin on AudioPlayerServiceBase, PlayerCrossfadeRampMixin {
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
    _notifyPlayerSwap();
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
