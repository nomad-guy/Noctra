part of '../audio_player_service.dart';

/// Mixin managing playback settings, loop/shuffle toggles, sleep timer with
/// fade-out, equalizer adjustments, and Studio Master audio effects sessions.
mixin PlayerEffectsMixin on AudioPlayerServiceBase {
  // ─── [09] Playback settings ─────────────────────────────────────────────

  void setAutoplayDelay(int sec) {
    _autoplayDelaySeconds = sec.clamp(0, 30);
    PlaybackSettingsStore.instance.save(autoplayDelaySeconds: _autoplayDelaySeconds);
    _emitSettings();
  }

  void setCrossfadeSeconds(int sec) {
    _crossfadeSeconds = sec.clamp(0, 12);
    PlaybackSettingsStore.instance.save(crossfadeSeconds: _crossfadeSeconds);
    _invalidatePlaybackOperations();
    _transitionEpoch++; // Also invalidate any active crossfade
    _emitSettings();
  }

  void toggleFade(bool enable) {
    _isFadeEnabled = enable;
    PlaybackSettingsStore.instance.save(fadeEnabled: enable);
    _invalidatePlaybackOperations();
    _transitionEpoch++;
    if (!enable) {
      _volumeEpoch++;
      final p = _player;
      final epoch = _volumeEpoch;
      _enqueue(() async {
        if (_volumeEpoch == epoch && identical(p, _player)) {
          try {
            await p.setVolume(_targetVolume);
          } catch (e) {
            NoctraLogger.w('Failed to restore volume', e);
          }
        }
      });
    }
    _emitSettings();
  }

  Future<void> toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    PlaybackSettingsStore.instance.save(shuffleEnabled: _isShuffleEnabled);
    _invalidatePlaybackOperations();
    if (_isShuffleEnabled && _queue.length > 2) {
      // Save canonical order before first shuffle.
      _canonicalQueue = List<Song>.from(_queue);
      _canonicalIndex = _currentIndex;
      final shuffled =
          AudioPlayerService.buildShuffledPlaybackOrder(_queue, _currentIndex);
      _mutateQueue(() {
        _queue
          ..clear()
          ..addAll(shuffled);
        _currentIndex = 0;
        return true;
      });
    } else if (!_isShuffleEnabled && _canonicalQueue != null) {
      final rebuilt = AudioPlayerService.restoreCanonicalOrder(
          _canonicalQueue!, List<Song>.from(_queue));
      final playing = _currentSong;
      final currentRef =
          playing == null ? null : (rebuilt.contains(playing) ? playing : null);
      final currentId = playing?.id;
      _mutateQueue(() {
        _queue
          ..clear()
          ..addAll(rebuilt);
        _currentIndex = currentRef != null
            ? _queue.indexOf(currentRef)
            : (currentId != null
                ? _queue.indexWhere((s) => s.id == currentId)
                : -1);
        if (_currentIndex < 0 || _currentIndex >= _queue.length) {
          _currentIndex =
              _queue.isEmpty ? 0 : _canonicalIndex.clamp(0, _queue.length - 1);
        }
        _canonicalQueue = null;
        return true;
      });
    }
    _emitSettings();
  }

  void toggleAutoplay() {
    _isAutoplayEnabled = !_isAutoplayEnabled;
    PlaybackSettingsStore.instance.save(autoplayEnabled: _isAutoplayEnabled);
    _emitSettings();
  }

  void toggleLoopMode() {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.off;
        break;
    }
    PlaybackSettingsStore.instance.save(loopMode: _loopMode.name);
    _emitSettings();
  }

  @override
  void _emitSettings() {
    if (!_playbackSettingsController.isClosed) {
      _playbackSettingsController.add({
        'isShuffleEnabled': _isShuffleEnabled,
        'isAutoplayEnabled': _isAutoplayEnabled,
        'isFadeEnabled': _isFadeEnabled,
        'loopMode': _loopMode.name,
        'autoplayDelaySeconds': _autoplayDelaySeconds,
        'crossfadeSeconds': _crossfadeSeconds,
      });
    }
  }

  // ─── [10] Sleep timer ───────────────────────────────────────────────────

  void cancelSleepTimer() {
    _sleepTimerEndOfTrack = false;
    setSleepTimer(0);
  }

  void setSleepTimerEndOfTrack(bool enabled) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemainingMinutes = null;
    _sleepTimerEndOfTrack = enabled;
    _emitSettings();
  }

  void setSleepTimer(int minutes) {
    _sleepTimerEndOfTrack = false;
    _sleepTimer?.cancel();
    _sleepFadeId++;
    _volumeEpoch++;
    _autoplayDelayGeneration++; // Cancel any pending autoplay delay

    if (minutes <= 0) {
      _sleepTimerRemainingMinutes = null;
      _emitSettings();
      return;
    }
    _sleepTimerRemainingMinutes = minutes;
    _emitSettings();
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) {
      if (_sleepTimerRemainingMinutes != null &&
          _sleepTimerRemainingMinutes! > 1) {
        _sleepTimerRemainingMinutes = _sleepTimerRemainingMinutes! - 1;
        _emitSettings();
      } else {
        t.cancel();
        _sleepTimerRemainingMinutes = null;
        _emitSettings();
        _enqueue(() => _runSleepFade());
      }
    });
  }

  @override
  Future<void> _runSleepFade() async {
    final p = _player;
    // Fade toward the CANONICAL target volume, never the player's live
    // volume: if a fade-in is still ramping (or a duck was active) p.volume
    // can be near zero, and the sleep fade would be a no-op that then
    // "restores" silence after pause. _targetVolume is the authoritative
    // level the user chose.
    final targetVolume = _targetVolume;
    final vEpoch = ++_volumeEpoch;
    final fadeId = _sleepFadeId;
    try {
      const steps = 10;
      for (int i = steps; i >= 0; i--) {
        if (_sleepFadeId != fadeId ||
            _volumeEpoch != vEpoch ||
            !identical(p, _player)) {
          return;
        }
        final t = i / steps;
        await p.setVolume(t * t * targetVolume);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_sleepFadeId == fadeId &&
          _volumeEpoch == vEpoch &&
          identical(p, _player)) {
        await p.pause();
        await p.setVolume(targetVolume);
      }
    } catch (e) {
      NoctraLogger.w('Sleep fade failed', e);
    }
  }

}
