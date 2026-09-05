part of '../noctra_local_database.dart';

extension LocalDatabasePlayback on NoctraLocalDatabase {
  Future<void> savePlaybackSession({
    required Song? currentSong,
    required int positionMs,
    List<Song> queue = const [],
    int currentIndex = 0,
    bool isShuffle = false,
    String loopMode = 'off',
  }) {
    if (currentSong == null && queue.isEmpty) return Future.value();
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        final payload = jsonEncode({
          'song': currentSong?.toMap(),
          'positionMs': positionMs,
          'queue': queue.map((e) => e.toMap()).toList(),
          'currentIndex': currentIndex,
          'isShuffle': isShuffle,
          'loopMode': loopMode,
        });
        await prefs.setString('noctra_last_playback', payload);
      } catch (e) {
        NoctraLogger.w('Failed to save playback session', e);
      }
    });
  }

  Future<void> savePlaybackPosition(Song? song, int positionMs,
      {List<Song>? queue,
      int? currentIndex,
      bool? isShuffle,
      String? loopMode}) {
    return savePlaybackSession(
      currentSong: song,
      positionMs: positionMs,
      queue: queue ?? (song != null ? [song] : []),
      currentIndex: currentIndex ?? 0,
      isShuffle: isShuffle ?? false,
      loopMode: loopMode ?? 'off',
    );
  }

  Future<Map<String, dynamic>?> loadPlaybackSession() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final combined = prefs.getString('noctra_last_playback');
      if (combined != null) {
        final decoded = jsonDecode(combined);
        if (decoded is Map<String, dynamic>) {
          Song? song;
          if (decoded['song'] is Map) {
            try {
              song = Song.fromMap(
                  Map<String, dynamic>.from(decoded['song'] as Map));
            } catch (_) {}
          }
          final posMs = (decoded['positionMs'] as num?)?.toInt() ?? 0;
          final queueList = <Song>[];
          if (decoded['queue'] is List) {
            for (final item in decoded['queue'] as List) {
              if (item is Map) {
                try {
                  queueList
                      .add(Song.fromMap(Map<String, dynamic>.from(item)));
                } catch (_) {}
              }
            }
          }
          final currIdx = (decoded['currentIndex'] as num?)?.toInt() ?? 0;
          final isShuffle = decoded['isShuffle'] == true;
          final loopMode = decoded['loopMode']?.toString() ?? 'off';

          return {
            'song': song,
            'positionMs': posMs,
            'queue': queueList,
            'currentIndex': currIdx,
            'isShuffle': isShuffle,
            'loopMode': loopMode,
          };
        }
      }
      final songJson = prefs.getString('noctra_last_song');
      final posMs = prefs.getInt('noctra_last_pos_ms') ?? 0;
      if (songJson != null) {
        final decoded = jsonDecode(songJson);
        final song = Song.fromMap(Map<String, dynamic>.from(decoded));
        return {
          'song': song,
          'positionMs': posMs,
          'queue': [song],
          'currentIndex': 0,
          'isShuffle': false,
          'loopMode': 'off',
        };
      }
    } catch (e) {
      NoctraLogger.w('loadPlaybackSession error', e);
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadPlaybackPosition() =>
      loadPlaybackSession();
}
