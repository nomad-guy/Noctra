part of '../audio_player_service.dart';

/// Mixin providing radio discovery, dynamic autoplay queue buffer filling,
/// and song completion sequencing.
mixin PlayerAutoplayMixin on AudioPlayerServiceBase {
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

  @override
  Future<void> _onSongCompletedInternal() async {
    // Consume the start timestamp: the end-of-song signal is recorded at
    // most once per track. Natural completion flows through here AND then
    // calls _skipNextInternal, which used to see the stale start time and
    // record the SAME finished track a second time (double taste-vector
    // update, double neural train, double knowledge-graph reinforcement).
    final start = _songStartTime;
    _songStartTime = null;
    final fallbackSec =
        _currentSong != null && _currentSong!.duration.inSeconds > 0
            ? _currentSong!.duration.inSeconds
            : 210;
    final playedSec = start != null
        ? DateTime.now().difference(start).inSeconds
        : fallbackSec;
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
