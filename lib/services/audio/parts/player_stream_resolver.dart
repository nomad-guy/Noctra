part of '../audio_player_service.dart';

/// Mixin managing URL resolution, media item packaging, player preparation,
/// and preloading the upcoming track.
mixin PlayerStreamResolverMixin on AudioPlayerServiceBase {
  // ─── [12] Media item factory ────────────────────────────────────────────

  @override
  MediaItem _createMediaItem(Song s) => MediaItem(
      id: s.id,
      album: s.album,
      title: s.title,
      artist: s.artist,
      artUri: (s.artworkUrl != null && s.artworkUrl!.startsWith('http'))
          ? Uri.parse(s.artworkUrl!)
          : null,
      duration: s.duration,
      playable: true);

  // ─── [13] URL resolution ────────────────────────────────────────────────

  @override
  Future<String> _resolveUrl(Song song) async {
    if (song.localFilePath != null &&
        song.localFilePath!.isNotEmpty &&
        !kIsWeb) {
      try {
        final f = File(song.localFilePath!);
        if (f.existsSync() && f.lengthSync() > 1024) {
          return 'LocalFile:${song.localFilePath!}';
        }
      } catch (_) {}
    }
    // Only return Song.streamUrl as a JioSaavn shortcut when its host
    // is actually the JioSaavn CDN — substring matching is unsafe.
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      final host = Uri.tryParse(song.streamUrl!)?.host.toLowerCase();
      if (host == 'aac.saavncdn.com' ||
          host == 'saavncdn.com' ||
          host == 'www.jiosaavn.com' ||
          host == 'jiosaavn.com' ||
          (host != null && host.endsWith('.saavncdn.com'))) {
        return 'JioSaavn320k:${song.streamUrl!}';
      }
    }
    if (song.id.startsWith('jam_')) {
      return 'JamendoDirect:${song.streamUrl ?? ''}';
    }
    final url = await CompositeStreamResolver.resolve(song) ?? '';
    return 'CompositeResolver:$url';
  }

  @override
  String _extractUrl(String resolved) {
    final colonIdx = resolved.indexOf(':');
    if (colonIdx > 0 && colonIdx < 20) {
      return resolved.substring(colonIdx + 1);
    }
    return resolved;
  }

  @override
  String _extractResolver(String resolved) {
    final colonIdx = resolved.indexOf(':');
    if (colonIdx > 0 && colonIdx < 20) {
      return resolved.substring(0, colonIdx);
    }
    return 'CompositeResolver';
  }

  // ─── [14] Player preparation ───────────────────────────────────────────

  @override
  Future<AudioPlayer?> _preparePlayer(Song song, int epoch) async {
    AudioPlayer? p;
    try {
      final resolved = await _resolveUrl(song);
      final url = _extractUrl(resolved);
      if (url.isEmpty || epoch != _playSessionEpoch) {
        return null;
      }
      p = AudioPlayer(maxSkipsOnError: 6);
      final mediaItem = _createMediaItem(song);
      final src = url.startsWith('http')
          ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
          : AudioSource.file(url, tag: mediaItem);
      await p.setAudioSource(src);
      await p.setVolume(0.0);
      return p;
    } catch (e) {
      NoctraLogger.w('Failed to prepare player for: ${song.title}', e);
      await _disposePlayer(p);
      return null;
    }
  }

  /// Non-blocking play with error logging — NEVER await player.play() for playback start.
  @override
  void _playNonBlocking(AudioPlayer p, String context) {
    p.play().catchError((e) {
      NoctraLogger.w('$context: play() failed', e);
    });
  }

  // ─── [20] Preloading ───────────────────────────────────────────────────

  @override
  Future<void> _invalidatePreload() async {
    final player = _bufferedNext;
    _bufferedNext = null;
    _bufferedNextSong = null;
    _bufferedNextRevision = -1;
    _preloadingGeneration++;
    _preloading = false;
    if (player != null) {
      await _disposePlayer(player);
    }
  }

  @override
  void _startPreloadNext() {
    if (_preloading) {
      return;
    }
    final nextIndex = _currentIndex + 1;
    final gen = ++_preloadingGeneration;

    if (nextIndex >= _queue.length) {
      if (_isAutoplayEnabled && _currentSong != null) {
        _preloading = true;
        final epoch = _playSessionEpoch;
        final rev = _queueRevision;
        _getRadioQueue(_currentSong!).then((similar) {
          if (gen != _preloadingGeneration ||
              epoch != _playSessionEpoch ||
              rev != _queueRevision) {
            _preloading = false;
            return;
          }
          if (!_isAutoplayEnabled) {
            _preloading = false;
            return;
          }
          if (similar.isNotEmpty) {
            _mutateQueue(() {
              var added = false;
              for (final s in similar) {
                if (!_queue.any((q) => q.id == s.id)) {
                  _queue.add(s);
                  added = true;
                }
              }
              return added;
            });
            _reconcileIndex();
            if (_currentIndex + 1 < _queue.length) {
              _prepareNextPlayer(_queue[_currentIndex + 1], epoch, rev)
                  .whenComplete(() {
                if (gen == _preloadingGeneration) {
                  _preloading = false;
                }
              });
            } else {
              _preloading = false;
            }
          } else {
            _preloading = false;
          }
        }).catchError((_) {
          _preloading = false;
          return null;
        });
      }
      return;
    }

    _preloading = true;
    final epoch = _playSessionEpoch;
    final rev = _queueRevision;
    _prepareNextPlayer(_queue[nextIndex], epoch, rev).whenComplete(() {
      if (gen == _preloadingGeneration) {
        _preloading = false;
      }
    });
  }

  Future<void> _prepareNextPlayer(Song song, int epoch, int revision) async {
    AudioPlayer? nextPlayer;
    try {
      final resolved = await _resolveUrl(song);
      final url = _extractUrl(resolved);
      if (url.isEmpty ||
          epoch != _playSessionEpoch ||
          revision != _queueRevision) {
        return;
      }

      nextPlayer = AudioPlayer(maxSkipsOnError: 6);
      final mediaItem = _createMediaItem(song);
      final src = url.startsWith('http')
          ? AudioSource.uri(Uri.parse(url), tag: mediaItem)
          : AudioSource.file(url, tag: mediaItem);
      await nextPlayer.setAudioSource(src);
      await nextPlayer.setVolume(0.0);

      if (epoch != _playSessionEpoch || revision != _queueRevision) {
        await _disposePlayer(nextPlayer);
        return;
      }

      final oldBuffered = _bufferedNext;
      _bufferedNext = nextPlayer;
      _bufferedNextSong = song;
      _bufferedNextRevision = revision;
      if (oldBuffered != null) {
        await _disposePlayer(oldBuffered);
      }
    } catch (e) {
      NoctraLogger.w('Pre-buffer failed for: ${song.title}', e);
      await _disposePlayer(nextPlayer);
    }
  }

  /// True when a pre-buffered player is still valid for [song]: it must
  /// belong to the current queue revision, otherwise the queue entry it
  /// was prepared for may have been removed or re-created under the same
  /// ID (duplicates / remove-then-add) and the preload is stale.
  @override
  bool _bufferedMatches(Song song) =>
      _bufferedNext != null &&
      _bufferedNextSong != null &&
      _bufferedNextSong!.id == song.id &&
      _bufferedNextRevision == _queueRevision;
}
