part of '../audio_player_service.dart';

/// Mixin providing session initialization, pre-buffered player handoff,
/// and URL stream loading.
mixin PlayerSessionLoaderMixin on AudioPlayerServiceBase {
  @override
  Future<void> _playSongInternal(Song song,
      {List<Song>? newQueue,
      Duration? initialPosition,
      int? queueIndex}) async {
    final epoch = ++_playSessionEpoch;
    _recoveryAttemptsByEpoch.removeWhere((key, _) => key < epoch - 1);
    _transitionEpoch++;
    _transitionInProgress = false;
    _autoplayDelayGeneration++;

    if (newQueue != null && newQueue.isNotEmpty) {
      _mutateQueue(() {
        _queue.clear();
        _queue.addAll(newQueue);
        if (queueIndex != null &&
            queueIndex >= 0 &&
            queueIndex < _queue.length &&
            _queue[queueIndex].id == song.id) {
          _currentIndex = queueIndex;
        } else {
          final exactIdx = _queue.indexOf(song);
          _currentIndex = exactIdx >= 0
              ? exactIdx
              : _queue.indexWhere((s) => s.id == song.id);
        }
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
    } else if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < _queue.length &&
        _queue[queueIndex].id == song.id) {
      _currentIndex = queueIndex;
    } else if (!_queue.any((s) => s.id == song.id)) {
      _mutateQueue(() {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
        return true;
      });
    } else {
      final exactIdx = _queue.indexOf(song);
      _currentIndex =
          exactIdx >= 0 ? exactIdx : _queue.indexWhere((s) => s.id == song.id);
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
      _notifyPlayerSwap();
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
          await _fadeIn();
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
}
