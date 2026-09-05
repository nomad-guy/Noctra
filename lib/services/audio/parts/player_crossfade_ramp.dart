part of '../audio_player_service.dart';

/// Mixin providing logarithmic volume ramp algorithms and crossfade execution.
mixin PlayerCrossfadeRampMixin on AudioPlayerServiceBase {
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

  Future<CrossfadeResult> _crossfadeTo(
      AudioPlayer nextPlayer, Song nextSong) async {
    final duration = Duration(seconds: _crossfadeSeconds);
    final tEpoch = _transitionEpoch;
    final playEpoch = _playSessionEpoch;
    final vEpoch = ++_volumeEpoch;

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
    final targetVol = _targetVolume;
    try {
      await nextPlayer.setVolume(0.0);
      if (nextPlayer.position > const Duration(milliseconds: 100)) {
        await nextPlayer.seek(Duration.zero);
      }
      _playNonBlocking(nextPlayer, 'Crossfade new player');

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
}
