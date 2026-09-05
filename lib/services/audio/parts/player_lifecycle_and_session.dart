part of '../audio_player_service.dart';

/// Mixin handling AudioSession configuration, audio focus interruptions,
/// native player error / state / position listeners, session restoration,
/// position persistence, and service teardown.
mixin PlayerLifecycleMixin on AudioPlayerServiceBase {
  // ─── [06] Constructor & audio session ───────────────────────────────────

  StreamSubscription<void>? _becomingNoisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _resumeOnInterruptionEnd = false;

  Future<void> _initAudioSession() async {
    try {
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());

      // Auto-pause when audio output changes abruptly (headphones unplugged / BT disconnected)
      _becomingNoisySub?.cancel();
      _becomingNoisySub = s.becomingNoisyEventStream.listen((_) {
        NoctraLogger.d('Audio becoming noisy: pausing playback');
        pause();
      });

      // Handle phone calls and transient audio focus interruptions
      _interruptionSub?.cancel();
      _interruptionSub = s.interruptionEventStream.listen((event) {
        NoctraLogger.d(
            'Audio interruption: ${event.type}, begin=${event.begin}');
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (_player.playing) {
                _player.setVolume(0.2);
              }
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _resumeOnInterruptionEnd = _player.playing;
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_targetVolume);
              break;
            case AudioInterruptionType.pause:
              if (_resumeOnInterruptionEnd) {
                _resumeOnInterruptionEnd = false;
                _playNonBlocking(_player, 'interruption ended resume');
              }
              break;
            case AudioInterruptionType.unknown:
              _resumeOnInterruptionEnd = false;
              break;
          }
        }
      });
    } catch (e) {
      NoctraLogger.w('Failed to initialize AudioSession listeners', e);
    }
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
          CompositeStreamResolver.invalidateCache(active.id);
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
              .savePlaybackSession(
                currentSong: activeSong,
                positionMs: pos.inMilliseconds,
                queue: _queue,
                currentIndex: _currentIndex,
                isShuffle: _isShuffleEnabled,
                loopMode: _loopMode.name,
              )
              .catchError((e) => NoctraLogger.w('Position save failed', e));
        }
      }
      _checkAutoCrossfade(pos);
    });

    _sessionSub = _player.androidAudioSessionIdStream.listen((sid) {
      if (gen != _listenerGeneration || !identical(attachedPlayer, _player)) {
        return;
      }
      if (sid != null && sid > 0) {
        attachNativeEffectsSession();
      }
    });
  }

  @override
  Future<void> _detachListeners() async {
    _listenerGeneration++;
    await Future.wait([
      _stateSub?.cancel() ?? Future.value(),
      _errorSub?.cancel() ?? Future.value(),
      _positionSub?.cancel() ?? Future.value(),
      _sessionSub?.cancel() ?? Future.value(),
    ]);
    _stateSub = null;
    _errorSub = null;
    _positionSub = null;
    _sessionSub = null;
  }

  // ─── [26] Persistence ──────────────────────────────────────────────────
  // Session restore now lives in PlayerSessionRestoreMixin
  // (parts/player_session_restore.dart).

  // ─── [27] Disposal ─────────────────────────────────────────────────────

  void dispose() {
    _isDisposed = true;
    _becomingNoisySub?.cancel();
    _interruptionSub?.cancel();
    _sleepTimer?.cancel();
    _detachListeners();
    _player.dispose();
    _disposePlayer(_bufferedNext);
    _invalidatePreload();
    _currentSongController.close();
    _queueController.close();
    _resolutionController.close();
    _playbackSettingsController.close();
    _playerSwapController.close();
  }
}
