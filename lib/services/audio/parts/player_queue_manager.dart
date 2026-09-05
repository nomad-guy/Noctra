part of '../audio_player_service.dart';

/// Mixin providing queue mutation, reordering, index reconciliation,
/// shuffle order generation, and test seams.
mixin PlayerQueueMixin on AudioPlayerServiceBase {
  // ─── [03] & [25] Queue Management & State ────────────────────────────────

  Timer? _queuePersistenceTimer;

  void _scheduleQueuePersistence() {
    _queuePersistenceTimer?.cancel();
    _queuePersistenceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_currentSong != null || _queue.isNotEmpty) {
        NoctraLocalDatabase()
            .savePlaybackSession(
              currentSong: _currentSong,
              positionMs: _player.position.inMilliseconds,
              queue: _queue,
              currentIndex: _currentIndex,
              isShuffle: _isShuffleEnabled,
              loopMode: _loopMode.name,
            )
            .catchError((e) => NoctraLogger.w('Debounced queue save failed', e));
      }
    });
  }

  @override
  void _mutateQueue(bool Function() mutate) {
    final changed = mutate();
    if (!changed) {
      return;
    }
    _queueRevision++;
    if (!_queueController.isClosed) {
      _queueController.add(List.unmodifiable(_queue));
    }
    _scheduleQueuePersistence();
  }

  /// Reconcile _currentIndex to match _currentSong after any queue
  /// mutation. Prefers INSTANCE identity so a playing duplicate is not
  /// re-pinned to an earlier copy with the same ID; falls back to ID only
  /// when the exact playing instance is gone (e.g. a persisted copy).
  @override
  void _reconcileIndex() {
    final current = _currentSong;
    if (current == null) {
      return;
    }
    var idx = _queue.indexOf(current);
    if (idx < 0) {
      idx = _queue.indexWhere((s) => s.id == current.id);
    }
    if (idx >= 0) {
      _currentIndex = idx;
      _currentSong = _queue[idx]; // keep instance identity authoritative
    }
  }

  void addToQueue(Song song) {
    _mutateQueue(() {
      _queue.add(song);
      return true;
    });
  }

  void playNext(Song song) {
    _mutateQueue(() {
      final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
      _queue.insert(insertAt, song);
      return true;
    });
    _invalidatePreload();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    // A queue position identifies an entry. Duplicate song IDs are legal,
    // so "removing the current song" must mean removing the entry AT the
    // current position — never any entry that merely shares the current
    // song's ID.
    final removedCurrent = _currentSong != null &&
        index == _currentIndex &&
        identical(_queue[index], _currentSong);
    _mutateQueue(() {
      _queue.removeAt(index);
      return true;
    });
    if (removedCurrent) {
      // Current entry was removed — play what now occupies that position
      // (the old next entry), else stop cleanly.
      if (_queue.isNotEmpty) {
        _currentIndex = index.clamp(0, _queue.length - 1);
        playSong(_queue[_currentIndex], queueIndex: _currentIndex);
      } else {
        _currentIndex = 0;
        _currentSong = null;
        if (!_currentSongController.isClosed) {
          _currentSongController.add(null);
        }
        unawaited(_player.stop().catchError((_) {}));
      }
    } else {
      // Removing an entry before the current one shifts the current
      // position down by one; removing a later entry leaves it as is.
      if (index < _currentIndex) {
        _currentIndex--;
      }
      _reconcileIndex();
    }
    _invalidatePreload();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) {
      return;
    }
    // Instance identity: with duplicate song IDs, ID-based reconciliation
    // can pin _currentIndex to the WRONG copy of the current song. Track
    // the moved entry by object identity and follow it.
    final movedIsCurrent =
        _currentSong != null && identical(_queue[oldIndex], _currentSong);
    _mutateQueue(() {
      final song = _queue.removeAt(oldIndex);
      final targetIndex = newIndex.clamp(0, _queue.length);
      _queue.insert(targetIndex, song);
      return true;
    });
    if (movedIsCurrent && _currentSong != null) {
      // Find the exact instance we moved — indexOf uses identity.
      final newIdx = _queue.indexOf(_currentSong!);
      if (newIdx >= 0) {
        _currentIndex = newIdx;
      }
    } else {
      _reconcileIndex();
    }
    _invalidatePreload();
  }

  void clearQueue() {
    if (_currentSong == null || _queue.isEmpty) {
      return;
    }
    _mutateQueue(() {
      final idx = _currentIndex.clamp(0, _queue.length - 1);
      final current = _queue[idx];
      _queue.clear();
      _queue.add(current);
      _currentIndex = 0;
      return true;
    });
    _invalidatePreload();
  }

  /// Updates currently playing song and queued items with newly downloaded local file path
  /// so that subsequent playback or repeats immediately use the local file without network.
  void onSongDownloaded(Song downloaded) {
    if (_currentSong?.id == downloaded.id) {
      _currentSong = _currentSong!.copyWith(
        isDownloaded: true,
        localFilePath: downloaded.localFilePath,
      );
      if (!_currentSongController.isClosed) {
        _currentSongController.add(_currentSong);
      }
    }
    bool queueUpdated = false;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id == downloaded.id) {
        _queue[i] = _queue[i].copyWith(
          isDownloaded: true,
          localFilePath: downloaded.localFilePath,
        );
        queueUpdated = true;
      }
    }
    if (queueUpdated) {
      _queueRevision++;
      if (!_queueController.isClosed) {
        _queueController.add(List.unmodifiable(_queue));
      }
    }
  }

  /// Test seam — establishes an in-memory queue + current position WITHOUT
  /// touching the platform player, so queue/transition invariants can be
  /// exercised deterministically.
  @visibleForTesting
  void debugSetPlaybackPosition({
    required List<Song> queue,
    required int index,
    Song? currentSong,
  }) {
    _queue
      ..clear()
      ..addAll(queue);
    _queueRevision++;
    if (!_queueController.isClosed) {
      _queueController.add(List.unmodifiable(_queue));
    }
    _currentIndex = index.clamp(0, _queue.isEmpty ? 0 : _queue.length - 1);
    _currentSong =
        currentSong ?? (_queue.isEmpty ? null : _queue[_currentIndex]);
  }

  /// Test seam — fires a player-swap tick WITHOUT touching the platform
  /// player. Regression guard: consecutive swap ticks must carry strictly
  /// increasing payloads so Riverpod stream dependents (position/playing
  /// UI providers) always invalidate and re-seed to the CURRENT player
  /// instance. A constant payload (e.g. `null`) is deduplicated by
  /// Riverpod's StreamProvider after the first swap, leaving the UI
  /// subscribed to a disposed player — the mini-player freeze bug.
  @visibleForTesting
  void debugNotifyPlayerSwap() {
    _notifyPlayerSwap();
  }
}
