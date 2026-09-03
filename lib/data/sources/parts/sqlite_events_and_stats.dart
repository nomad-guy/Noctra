part of '../noctra_sqlite_database.dart';

extension SqliteEventsAndStats on NoctraSqliteDatabase {
  Future<void> recordListeningEvent({
    required Song song,
    required String eventType,
    required double signalScore,
    double completionRate = 1.0,
    int durationListenedMs = 0,
    int totalDurationMs = 0,
    String? audioFeaturesJson,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final replayInc = (eventType == 'complete_listen' ||
              eventType == 'deep_listen' ||
              eventType == 'replay')
          ? 1
          : 0;
      final skipInc =
          (eventType == 'fast_skip' || eventType == 'short_skip') ? 1 : 0;

      await db.transaction((txn) async {
        await txn.insert('listening_events', {
          'song_id': song.id,
          'title': song.title,
          'artist': song.artist,
          'genre': song.genre ?? 'Music',
          'event_type': eventType,
          'signal_score': signalScore,
          'completion_rate': completionRate,
          'duration_listened_ms': durationListenedMs,
          'total_duration_ms': totalDurationMs,
          'is_in_favorites': 0,
          'is_downloaded': song.isDownloaded ? 1 : 0,
          'replay_count': song.replayCount,
          'audio_features_json': audioFeaturesJson,
          'timestamp': now,
        });

        final vectorJson = jsonEncode(song.featureVector);
        await txn.rawInsert(
          'INSERT INTO track_embeddings ('
          'song_id, title, artist, genre, album, duration_ms, '
          'is_in_favorites, is_downloaded, replay_count, '
          'total_listen_time_ms, skip_count, last_listened_at, '
          'audio_features_json, vector_json, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(song_id) DO UPDATE SET '
          'replay_count = track_embeddings.replay_count + excluded.replay_count, '
          'skip_count = track_embeddings.skip_count + excluded.skip_count, '
          'total_listen_time_ms = track_embeddings.total_listen_time_ms + '
          'excluded.total_listen_time_ms, '
          'last_listened_at = excluded.last_listened_at, '
          'audio_features_json = COALESCE(excluded.audio_features_json, '
          'track_embeddings.audio_features_json), '
          'updated_at = excluded.updated_at',
          [
            song.id,
            song.title,
            song.artist,
            song.genre,
            song.album,
            song.duration.inMilliseconds,
            song.isFavorite ? 1 : 0,
            song.isDownloaded ? 1 : 0,
            replayInc,
            durationListenedMs,
            skipInc,
            now,
            audioFeaturesJson,
            vectorJson,
            now
          ],
        );
      });
    } catch (e) {
      NoctraLogger.w('SQLite event recording error', e);
    }
  }

  Future<Map<String, dynamic>?> getSongStats(String songId) async {
    try {
      final db = await database;
      final res = await db.query('track_embeddings',
          where: 'song_id = ?', whereArgs: [songId], limit: 1);
      if (res.isNotEmpty) return res.first;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> getListeningStats() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) AS total_events,
          SUM(CASE WHEN event_type IN ('fast_skip', 'short_skip') THEN 1 ELSE 0 END) AS total_skips,
          SUM(CASE WHEN event_type IN ('complete_listen', 'replay') THEN 1 ELSE 0 END) AS total_replays,
          COALESCE(SUM(duration_listened_ms), 0) AS total_listen_time_ms,
          COUNT(DISTINCT artist) AS unique_artists,
          COUNT(DISTINCT genre) AS unique_genres
        FROM listening_events
      ''');
      if (rows.isNotEmpty) {
        final r = rows.first;
        final totalEvents = (r['total_events'] as num?)?.toInt() ?? 0;
        final totalSkips = (r['total_skips'] as num?)?.toInt() ?? 0;
        final totalReplays = (r['total_replays'] as num?)?.toInt() ?? 0;
        final totalListenTime =
            (r['total_listen_time_ms'] as num?)?.toInt() ?? 0;
        final uniqueArtists = (r['unique_artists'] as num?)?.toInt() ?? 0;
        final uniqueGenres = (r['unique_genres'] as num?)?.toInt() ?? 0;

        return {
          'total_events': totalEvents,
          'total_skips': totalSkips,
          'total_replays': totalReplays,
          'total_listen_time_ms': totalListenTime,
          'unique_artists': uniqueArtists,
          'unique_genres': uniqueGenres,
          'skip_rate': totalEvents > 0 ? totalSkips / totalEvents : 0.0,
          'replay_ratio': totalEvents > 0 ? totalReplays / totalEvents : 0.0,
        };
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getRecentEvents({int limit = 50}) async {
    try {
      final db = await database;
      return await db.query(
        'listening_events',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    } catch (e) {
      NoctraLogger.w('SQLite getRecentEvents error', e);
      return [];
    }
  }
}
