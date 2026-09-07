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

  static final List<String> _recentHistoryIds = [];
  static final List<String> _recentNormalizedTitles = [];

  static String _normalizeTitleKey(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '') // remove parenthetical like (Remastered)
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  @override
  Future<List<Song>> _getRadioQueue(Song seed) async {
    final existing = _radioRequests[seed.id];
    if (existing != null) {
      return existing;
    }

    final excludeIds = <String>{seed.id, ..._recentHistoryIds};
    for (final s in _queue) {
      excludeIds.add(s.id);
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
      final queueIds = _queue.map((s) => s.id).toSet();
      final queueTitles = _queue.map((s) => _normalizeTitleKey(s.title)).toSet();
      final historyTitles = _recentNormalizedTitles.toSet();

      final filtered = <Song>[];
      final seenBatchTitles = <String>{};
      for (final s in results) {
        if (s.id == seed.id || queueIds.contains(s.id) || _recentHistoryIds.contains(s.id)) {
          continue;
        }
        final key = _normalizeTitleKey(s.title);
        if (key.isNotEmpty &&
            (queueTitles.contains(key) ||
                historyTitles.contains(key) ||
                !seenBatchTitles.add(key))) {
          continue;
        }
        filtered.add(s);
      }
      return filtered;
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

      // Track session history to avoid repetitive AI radio / autoplay recommendations
      _recentHistoryIds.add(_currentSong!.id);
      if (_recentHistoryIds.length > 60) {
        _recentHistoryIds.removeAt(0);
      }
      final titleKey = _normalizeTitleKey(_currentSong!.title);
      if (titleKey.isNotEmpty) {
        _recentNormalizedTitles.add(titleKey);
        if (_recentNormalizedTitles.length > 60) {
          _recentNormalizedTitles.removeAt(0);
        }
      }
    }

    if (_sleepTimerEndOfTrack) {
      _sleepTimerEndOfTrack = false;
      _emitSettings();
      await _runSleepFade();
      await _player.stop();
      _invalidatePlaybackOperations();
      return;
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
