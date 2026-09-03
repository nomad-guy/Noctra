part of '../audio_player_service.dart';

/// Mixin providing the primary public playback controls, internal playback session
/// progression, song completion sequencing, and radio autoplay queue discovery.
mixin PlayerPlaybackMixin on AudioPlayerServiceBase {
  // ─── [21] Radio / autoplay ─────────────────────────────────────────────

  @override
  Future<void> _ensureAutoplayQueue(int epoch, int revision) async {
    final remaining = _queue.length - _currentIndex - 1;
    if (remaining >= AudioPlayerServiceBase._minAutoplayBuffer) {
      return;
    }
    if (_currentSong == null) {
      return;
    }

    final seedId = _currentSong!.id;
    final similar = await _getRadioQueue(_currentSong!);
    if (similar.isEmpty ||
        epoch != _playSessionEpoch ||
        revision != _queueRevision) {
      return;
    }
    if (_currentSong?.id != seedId) {
      return;
    }
    if (!_isAutoplayEnabled) {
      return;
    }

    final currentIds = _queue.map((s) => s.id).toSet();
    final safeResults = similar
        .where(
          (s) => s.id != _currentSong?.id && !currentIds.contains(s.id),
        )
        .toList();

    if (safeResults.isNotEmpty) {
      _mutateQueue(() {
        var added = false;
        for (final s in safeResults) {
          if (!_queue.any((q) => q.id == s.id)) {
            _queue.add(s);
            added = true;
          }
        }
        return added;
      });
      _reconcileIndex();
    }
  }

  @override
  Future<List<Song>> _getRadioQueue(Song seed) async {
    final existing = _radioRequests[seed.id];
    if (existing != null) {
      return existing;
    }

    final excludeIds = <String>{seed.id};
    for (int i = _currentIndex + 1;
        i < min(_queue.length, _currentIndex + 4);
        i++) {
      excludeIds.add(_queue[i].id);
    }
    final gen = ++_radioGeneration;
    final request =
        MusicService.fetchSimilarRadioQueue(seed, excludeIds: excludeIds);
    _radioRequests[seed.id] = request;
    try {
      final results = await request;
      if (gen != _radioGeneration) {
        return [];
      }
      return results.where((s) => !_queue.any((q) => q.id == s.id)).toList();
    } finally {
      _radioRequests.remove(seed.id);
    }
  }

  // ─── [22] Public playback API ──────────────────────────────────────────

  Future<void> playSong(Song song,
      {List<Song>? newQueue, Duration? initialPosition}) {
    return _serialize(() => _playSongInternal(song,
        newQueue: newQueue, initialPosition: initialPosition));
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
          await _playSongInternal(_queue[_currentIndex]);
        }
      });

  Future<void> seek(Duration pos) => _serialize(() async {
        _invalidatePlaybackOperations();
        _transitionEpoch++;
        try {
          await _player.seek(pos);
        } catch (_) {}
      });

  void pause() {
    _invalidatePlaybackOperations();
    _transitionEpoch++;
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
        try {
          await _player.stop();
        } catch (_) {}
        _invalidatePreload();
        _currentSong = null;
        if (!_currentSongController.isClosed) {
          _currentSongController.add(null);
        }
      });

  // ─── [23] Internal playback operations ─────────────────────────────────

  @override
  Future<void> _playSongInternal(Song song,
      {List<Song>? newQueue, Duration? initialPosition}) async {
    final epoch = ++_playSessionEpoch;
    _recoveryAttemptsByEpoch.removeWhere((key, _) => key < epoch - 1);
    _transitionEpoch++;
    _transitionInProgress = false;
    _autoplayDelayGeneration++;

    if (newQueue != null && newQueue.isNotEmpty) {
      _mutateQueue(() {
        _queue.clear();
        _queue.addAll(newQueue);
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
        if (_currentIndex == -1) {
          _queue.insert(0, song);
          _currentIndex = 0;
        }
        return true;
      });
      final oldBuffered = _bufferedNext;
      _bufferedNext = null;
      _bufferedNextSong = null;
      _bufferedNextRevision = -1;
      _preloading = false;
      if (oldBuffered != null) {
        _disposePlayer(oldBuffered);
      }
    } else if (!_queue.any((s) => s.id == song.id)) {
      _mutateQueue(() {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
        return true;
      });
    } else {
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }

    final current = (_currentIndex >= 0 && _currentIndex < _queue.length)
        ? _queue[_currentIndex]
        : song;
    _currentSong = current;
    _songStartTime = DateTime.now();
    if (!_currentSongController.isClosed) {
      _currentSongController.add(current);
    }
    MusicRepository().recordSongPlayed(current);
    try {
      await _player.stop();
    } catch (_) {}
    _positionSaveEpoch = _playSessionEpoch;
    _lastSavedBucket = -1;
    _invalidatePlaybackOperations();
    if (epoch != _playSessionEpoch) {
      return;
    }

    if (_bufferedMatches(song)) {
      final buffered = _bufferedNext!;
      _bufferedNext = null;
      _bufferedNextSong = null;
      _bufferedNextRevision = -1;
      await _detachListeners();
      final oldPlayer = _player;
      _player = buffered;
      await _attachListeners();
      await _disposePlayer(oldPlayer);
      try {
        if (_isFadeEnabled) {
          await _player.setVolume(0.0);
          _playNonBlocking(_player, 'Pre-buffered play');
          await _fadeIn();
        } else {
          await _player.setVolume(_targetVolume);
          _playNonBlocking(_player, 'Pre-buffered play');
        }
        await applyStudioMasterMode(_studioMasterMode);
        _startPreloadNext();
        return;
      } catch (e) {
        NoctraLogger.w('Pre-buffered player failed, falling back', e);
      }
    }

    final sw = Stopwatch()..start();
    String resolverName = 'Local', url = '';
    try {
      final resolved = await _resolveUrl(song);
      resolverName = _extractResolver(resolved);
      url = _extractUrl(resolved);
      sw.stop();
      if (epoch != _playSessionEpoch) {
        return;
      }
      _lastResolution = StreamResolutionMetadata(
          songId: song.id,
          songTitle: song.title,
          resolvedUrl: url,
          resolverUsed: resolverName,
          resolutionMs: sw.elapsedMilliseconds,
          timestamp: DateTime.now());
      if (!_resolutionController.isClosed) {
        _resolutionController.add(_lastResolution!);
      }
      if (epoch != _playSessionEpoch) {
        return;
      }

      if (url.isEmpty) {
        NoctraLogger.w('playSong: no resolved URL for "${song.title}"');
        return;
      }

      final startPos = initialPosition ??
          ((_lastSavedPosition != null && _lastSavedSongId == song.id)
              ? _lastSavedPosition!
              : Duration.zero);
      _restoredPositionUsed = startPos.inMilliseconds > 0;
      _lastSavedPosition = null;
      _lastSavedSongId = null;

      final mediaItem = _createMediaItem(song);
      var loaded = false;
      try {
        final src = url.startsWith('http')
            ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
            : AudioSource.file(url, tag: mediaItem);
        await _player.setAudioSource(src, initialPosition: startPos);
        loaded = true;
      } catch (e) {
        NoctraLogger.w(
            'playSong: setAudioSource failed for "${song.title}"', e);
        CompositeStreamResolver.invalidateCache(song.id);
        if (epoch == _playSessionEpoch) {
          try {
            final fallback =
                await CompositeStreamResolver.resolve(song, startTier: 1);
            final fallbackUrl = fallback ?? '';
            if (fallbackUrl.isNotEmpty && fallbackUrl != url) {
              final src2 = fallbackUrl.startsWith('http')
                  ? AudioSource.uri(Uri.parse(fallbackUrl), tag: mediaItem)
                  : AudioSource.file(fallbackUrl, tag: mediaItem);
              await _player.setAudioSource(src2, initialPosition: startPos);
              loaded = true;
            }
          } catch (_) {}
        }
      }

      if (loaded && epoch == _playSessionEpoch) {
        if (_isFadeEnabled) {
          await _player.setVolume(0.0);
          _playNonBlocking(_player, 'playSong');
          await (this as dynamic)._fadeIn();
        } else {
          await _player.setVolume(_targetVolume);
          _playNonBlocking(_player, 'playSong');
        }
        await applyStudioMasterMode(_studioMasterMode);
        _startPreloadNext();
      }
    } catch (e) {
      NoctraLogger.w('playSong failed for "${song.title}"', e);
    }
  }

  Future<void> _skipNextInternal() async {
    if (_transitionInProgress) {
      return;
    }
    _transitionInProgress = true;
    final myId = ++_transitionId;
    try {
      if (_songStartTime != null && _currentSong != null) {
        final playedSec = DateTime.now().difference(_songStartTime!).inSeconds;
        ImplicitSignalTracker().trackPlaybackEnd(
            song: _currentSong!,
            listenedSeconds: playedSec,
            totalDuration: _currentSong!.duration);
        NoctraLocalDatabase().recordManifest(_currentSong!,
            action: playedSec < 15 ? 'skip' : 'play',
            listenedSeconds: playedSec);
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

  // ─── [24] Song completion handler ──────────────────────────────────────

  @override
  Future<void> _onSongCompletedInternal() async {
    final playedSec = _songStartTime != null
        ? DateTime.now().difference(_songStartTime!).inSeconds
        : 210;
    if (_currentSong != null) {
      ImplicitSignalTracker().trackPlaybackEnd(
          song: _currentSong!,
          listenedSeconds: playedSec,
          totalDuration: _currentSong!.duration);
      NoctraLocalDatabase().recordManifest(_currentSong!,
          action: 'complete', listenedSeconds: playedSec);
    }
    if (_loopMode == LoopMode.one && _currentSong != null) {
      await _player.seek(Duration.zero);
      _playNonBlocking(_player, 'LoopMode.one replay');
    } else if (_loopMode == LoopMode.off &&
        !_isAutoplayEnabled &&
        _currentIndex >= _queue.length - 1) {
      await _player.stop();
      _invalidatePlaybackOperations();
    } else {
      if (_autoplayDelaySeconds > 0) {
        final delayGen = ++_autoplayDelayGeneration;
        await Future.delayed(Duration(seconds: _autoplayDelaySeconds));
        if (delayGen != _autoplayDelayGeneration) {
          return;
        }
      }
      await _skipNextInternal();
    }
  }
}
