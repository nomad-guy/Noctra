import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/noctra_logger.dart';
import '../models/song_model.dart';

class NoctraSqliteDatabase {
  static final NoctraSqliteDatabase _instance =
      NoctraSqliteDatabase._internal();
  factory NoctraSqliteDatabase() => _instance;
  NoctraSqliteDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // In-memory web fallback
      return await openDatabase(inMemoryDatabasePath,
          version: 2, onCreate: _createDb, onUpgrade: _upgradeDb);
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'noctra_neural_store.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA journal_mode=WAL;');
          await db.execute('PRAGMA synchronous=NORMAL;');
        } catch (_) {}
      },
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS listening_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL,
        title TEXT,
        artist TEXT,
        genre TEXT,
        event_type TEXT NOT NULL,
        signal_score REAL NOT NULL,
        completion_rate REAL DEFAULT 1.0,
        duration_listened_ms INTEGER DEFAULT 0,
        total_duration_ms INTEGER DEFAULT 0,
        is_in_favorites INTEGER DEFAULT 0,
        is_downloaded INTEGER DEFAULT 0,
        replay_count INTEGER DEFAULT 0,
        audio_features_json TEXT,
        timestamp INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS track_embeddings (
        song_id TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        genre TEXT,
        album TEXT,
        duration_ms INTEGER DEFAULT 0,
        is_in_favorites INTEGER DEFAULT 0,
        is_downloaded INTEGER DEFAULT 0,
        replay_count INTEGER DEFAULT 0,
        total_listen_time_ms INTEGER DEFAULT 0,
        skip_count INTEGER DEFAULT 0,
        last_listened_at INTEGER,
        audio_features_json TEXT,
        vector_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS neural_user_profile (
        id INTEGER PRIMARY KEY,
        user_vector_json TEXT NOT NULL,
        interaction_count INTEGER DEFAULT 0,
        last_updated INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS neural_model_state (
        id INTEGER PRIMARY KEY,
        state_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_timestamp ON listening_events(timestamp DESC);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_artist ON listening_events(artist);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_song ON listening_events(song_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_type ON listening_events(event_type);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_embeddings_artist ON track_embeddings(artist);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_embeddings_genre ON track_embeddings(genre);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_embeddings_last_listened ON track_embeddings(last_listened_at DESC);');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS neural_model_state (
          id INTEGER PRIMARY KEY,
          state_json TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
    }
    if (oldVersion < 3) {
      // Add new columns to existing tables — each checked independently
      // so an interrupted migration does not prevent later columns.
      Future<void> addColumnIfMissing(
          String table, String col, String typeDef) async {
        final cols = await db.rawQuery('PRAGMA table_info($table)');
        final names = cols.map((c) => c['name'] as String).toSet();
        if (!names.contains(col)) {
          await db.execute('ALTER TABLE $table ADD COLUMN $col $typeDef');
        }
      }

      await addColumnIfMissing(
          'listening_events', 'duration_listened_ms', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'listening_events', 'total_duration_ms', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'listening_events', 'is_in_favorites', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'listening_events', 'is_downloaded', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'listening_events', 'replay_count', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'listening_events', 'audio_features_json', 'TEXT');

      await addColumnIfMissing('track_embeddings', 'genre', 'TEXT');
      await addColumnIfMissing('track_embeddings', 'album', 'TEXT');
      await addColumnIfMissing(
          'track_embeddings', 'duration_ms', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'track_embeddings', 'is_in_favorites', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'track_embeddings', 'is_downloaded', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'track_embeddings', 'replay_count', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'track_embeddings', 'total_listen_time_ms', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'track_embeddings', 'skip_count', 'INTEGER DEFAULT 0');
      await addColumnIfMissing(
          'track_embeddings', 'last_listened_at', 'INTEGER');
      await addColumnIfMissing(
          'track_embeddings', 'audio_features_json', 'TEXT');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_events_song ON listening_events(song_id);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_embeddings_artist ON track_embeddings(artist);');
    }
  }

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

      // Atomic increment counters — no read-modify-write race.
      final replayInc = (eventType == 'complete_listen' ||
              eventType == 'deep_listen' ||
              eventType == 'replay')
          ? 1
          : 0;
      final skipInc =
          (eventType == 'fast_skip' || eventType == 'short_skip') ? 1 : 0;

      // The event row and the embedding counter update are ONE logical
      // operation: a crash between the two would leave an event whose counter
      // increments never landed (or vice versa). Run both inside a single
      // transaction so the pair commits or rolls back together.
      await db.transaction((txn) async {
        // Record the listening event with full metadata
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

        // Single atomic UPSERT — no update-then-insert race window.
        // Two concurrent events cannot both see "row missing" and race.
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

  /// Get per-song stats for neural network features.
  Future<Map<String, dynamic>?> getSongStats(String songId) async {
    try {
      final db = await database;
      final res = await db.query('track_embeddings',
          where: 'song_id = ?', whereArgs: [songId], limit: 1);
      if (res.isNotEmpty) return res.first;
    } catch (_) {}
    return null;
  }

  /// Get aggregate listening stats for pattern features in a single SQL pass.
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

  Future<List<double>?> loadNeuralUserVector() async {
    try {
      final db = await database;
      final res =
          await db.query('neural_user_profile', where: 'id = 1', limit: 1);
      if (res.isNotEmpty) {
        final jsonStr = res.first['user_vector_json'] as String?;
        if (jsonStr != null) {
          final list = jsonDecode(jsonStr) as List;
          return list.map((e) => (e as num).toDouble()).toList();
        }
      }
    } catch (e) {
      NoctraLogger.w('SQLite loadNeuralUserVector error', e);
    }
    return null;
  }

  Future<void> saveNeuralUserVector(
      List<double> vector, int interactions) async {
    try {
      final db = await database;
      await db.insert(
        'neural_user_profile',
        {
          'id': 1,
          'user_vector_json': jsonEncode(vector),
          'interaction_count': interactions,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      NoctraLogger.w('SQLite saveNeuralUserVector error', e);
    }
  }

  Future<Map<String, dynamic>?> loadNeuralModelState() async {
    try {
      final db = await database;
      final rows =
          await db.query('neural_model_state', where: 'id = 1', limit: 1);
      if (rows.isEmpty) return null;
      final raw = rows.first['state_json'];
      if (raw is! String) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (e) {
      NoctraLogger.w('SQLite loadNeuralModelState error', e);
      return null;
    }
  }

  Future<void> saveNeuralModelState(Map<String, dynamic> state) async {
    try {
      final db = await database;
      await db.insert(
        'neural_model_state',
        {
          'id': 1,
          'state_json': jsonEncode(state),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      NoctraLogger.w('SQLite saveNeuralModelState error', e);
    }
  }
}
