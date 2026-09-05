part of '../audio_player_service.dart';

/// Mixin managing playback settings, loop/shuffle toggles, sleep timer with
/// fade-out, equalizer adjustments, and Studio Master audio effects sessions.
mixin PlayerEffectsMixin on AudioPlayerServiceBase {
  // ─── [09] Playback settings ─────────────────────────────────────────────

  void setAutoplayDelay(int sec) {
    _autoplayDelaySeconds = sec.clamp(0, 30);
    _emitSettings();
  }

  void setCrossfadeSeconds(int sec) {
    _crossfadeSeconds = sec.clamp(0, 12);
    _invalidatePlaybackOperations();
    _transitionEpoch++; // Also invalidate any active crossfade
    _emitSettings();
  }

  void toggleFade(bool enable) {
    _isFadeEnabled = enable;
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
    _emitSettings();
  }

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

  void cancelSleepTimer() => setSleepTimer(0);

  void setSleepTimer(int minutes) {
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

  Future<void> _runSleepFade() async {
    final p = _player;
    final originalVolume = p.volume;
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
        await p.setVolume(t * t * originalVolume);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_sleepFadeId == fadeId &&
          _volumeEpoch == vEpoch &&
          identical(p, _player)) {
        await p.pause();
        await p.setVolume(originalVolume);
      }
    } catch (e) {
      NoctraLogger.w('Sleep fade failed', e);
    }
  }

  // ─── [11] Audio effects ─────────────────────────────────────────────────

  static const _effectsChannel =
      MethodChannel('com.nomadguy.noctra/audio_effects');

  List<double>? _lastEqualizerBands;
  double? _lastBassBoost;
  double? _lastVirtualizer;

  @override
  Future<bool> attachNativeEffectsSession() async {
    if (!NoctraCapabilities.supportsNativeAudioEffects) {
      return false;
    }
    try {
      int? sid = _player.androidAudioSessionId;
      if (sid == null || sid <= 0) {
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          sid = _player.androidAudioSessionId;
          if (sid != null && sid > 0) break;
        }
      }
      if (sid == null || sid <= 0) {
        return false;
      }
      final attached = (await _effectsChannel
              .invokeMethod<bool>('attachSession', {'sessionId': sid})) ??
          false;
      if (attached) {
        if (_studioMasterMode.isNotEmpty && _studioMasterMode != 'off') {
          _effectsChannel.invokeMethod('applyStudioMode', {
            'sessionId': sid,
            'mode': _studioMasterMode,
          }).catchError((_) => false);
        }
        if (_lastEqualizerBands != null) {
          _effectsChannel.invokeMethod('applyEqualizer', {
            'sessionId': sid,
            'bands': _lastEqualizerBands,
            'bassBoost': _lastBassBoost ?? 0.0,
            'virtualizer': _lastVirtualizer ?? 0.0,
          }).catchError((_) => false);
        }
      }
      return attached;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> applyStudioMasterMode(String mode) async {
    try {
      final sid = _player.androidAudioSessionId ?? 0;
      final applied = (await _effectsChannel.invokeMethod<bool>('applyStudioMode', {
            'sessionId': sid,
            'mode': mode,
          })) ??
          false;
      if (applied) {
        _studioMasterMode = mode;
      }
      return applied;
    } catch (e) {
      NoctraLogger.w('applyStudioMasterMode failed (mode=$mode)', e);
      return false;
    }
  }

  void applyEqualizer(
      {List<double>? bands, double? bassBoost, double? virtualizer}) {
    try {
      if (bands != null) _lastEqualizerBands = List<double>.from(bands);
      if (bassBoost != null) _lastBassBoost = bassBoost;
      if (virtualizer != null) _lastVirtualizer = virtualizer;

      final sid = _player.androidAudioSessionId ?? 0;
      _effectsChannel.invokeMethod('applyEqualizer', {
        'sessionId': sid,
        'bands': bands ?? [0.0, 0.0, 0.0, 0.0, 0.0],
        'bassBoost': bassBoost ?? 0.0,
        'virtualizer': virtualizer ?? 0.0,
      }).then<void>((_) {}, onError: (Object e) {
        NoctraLogger.w('applyEqualizer failed', e);
      });
    } catch (e) {
      NoctraLogger.w('applyEqualizer failed', e);
    }
  }

  @override
  Future<Map<String, dynamic>> getAudioEngineStatus() async {
    if (!NoctraCapabilities.supportsNativeAudioEffects) {
      return {'engine': 'none', 'isDynamics': false};
    }
    try {
      final res = await _effectsChannel
          .invokeMapMethod<String, dynamic>('getEngineStatus');
      return res ?? {'engine': 'none', 'isDynamics': false};
    } catch (_) {
      return {'engine': 'none', 'isDynamics': false};
    }
  }
}
