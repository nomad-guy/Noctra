import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/noctra_logger.dart';
import '../models/song_model.dart';

class NoctraSqliteDatabase {
  static final NoctraSqliteDatabase _instance = NoctraSqliteDatabase._internal();
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
      return await openDatabase(inMemoryDatabasePath, version: 2, onCreate: _createDb, onUpgrade: _upgradeDb);
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

    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_timestamp ON listening_events(timestamp DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_artist ON listening_events(artist);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_song ON listening_events(song_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_embeddings_artist ON track_embeddings(artist);');
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
      // Add new columns to existing tables (safe — ignores if already exists)
      final eventCols = await db.rawQuery("PRAGMA table_info(listening_events)");
      final eventColNames = eventCols.map((c) => c['name'] as String).toSet();
      if (!eventColNames.contains('duration_listened_ms')) {
        await db.execute('ALTER TABLE listening_events ADD COLUMN duration_listened_ms INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE listening_events ADD COLUMN total_duration_ms INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE listening_events ADD COLUMN is_in_favorites INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE listening_events ADD COLUMN is_downloaded INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE listening_events ADD COLUMN replay_count INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE listening_events ADD COLUMN audio_features_json TEXT');
      }

      final embedCols = await db.rawQuery("PRAGMA table_info(track_embeddings)");
      final embedColNames = embedCols.map((c) => c['name'] as String).toSet();
      if (!embedColNames.contains('genre')) {
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN genre TEXT');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN album TEXT');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN duration_ms INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN is_in_favorites INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN is_downloaded INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN replay_count INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN total_listen_time_ms INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN skip_count INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN last_listened_at INTEGER');
        await db.execute('ALTER TABLE track_embeddings ADD COLUMN audio_features_json TEXT');
      }

      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_song ON listening_events(song_id);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_embeddings_artist ON track_embeddings(artist);');
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

      // Record the listening event with full metadata
      await db.insert('listening_events', {
        'song_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'genre': song.genre ?? 'Music',
        'event_type': eventType,
        'signal_score': signalScore,
        'completion_rate': completionRate,
        'duration_listened_ms': durationListenedMs,
        'total_duration_ms': totalDurationMs,          'is_in_favorites': 0,
          'is_downloaded': song.isDownloaded ? 1 : 0,
          'replay_count': song.replayCount,
          'audio_features_json': audioFeaturesJson,
          'timestamp': now,
      });

      // Upsert track embedding with full per-song metadata
      // First, get existing stats for this song
      int existingReplays = 0;
      int existingListenTime = 0;
      int existingSkips = 0;
      try {
        final existing = await db.query('track_embeddings',
            where: 'song_id = ?', whereArgs: [song.id], limit: 1);
        if (existing.isNotEmpty) {
          existingReplays = (existing.first['replay_count'] as int?) ?? 0;
          existingListenTime = (existing.first['total_listen_time_ms'] as int?) ?? 0;
          existingSkips = (existing.first['skip_count'] as int?) ?? 0;
        }
      } catch (_) {}

      // Update counters based on event type
      int newReplays = existingReplays;
      int newListenTime = existingListenTime;
      int newSkips = existingSkips;
      if (eventType == 'complete_listen' || eventType == 'deep_listen' || eventType == 'replay') {
        newReplays++;
      }
      if (eventType == 'fast_skip' || eventType == 'short_skip') {
        newSkips++;
      }
      newListenTime += durationListenedMs;

      await db.insert(
        'track_embeddings',
        {
          'song_id': song.id,
          'title': song.title,
          'artist': song.artist,
          'genre': song.genre,
          'album': song.album,
          'duration_ms': song.duration.inMilliseconds,
          'is_in_favorites': 0,
          'is_downloaded': song.isDownloaded ? 1 : 0,
          'replay_count': newReplays,
          'total_listen_time_ms': newListenTime,
          'skip_count': newSkips,
          'last_listened_at': now,
          'audio_features_json': audioFeaturesJson,
          'vector_json': jsonEncode(song.featureVector),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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

  /// Get aggregate listening stats for pattern features.
  Future<Map<String, dynamic>> getListeningStats() async {
    try {
      final db = await database;
      final totalEvents = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM listening_events')) ?? 0;
      final totalSkips = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM listening_events WHERE event_type IN ('fast_skip', 'short_skip')")) ?? 0;
      final totalReplays = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM listening_events WHERE event_type IN ('complete_listen', 'replay')")) ?? 0;
      final totalListenTime = Sqflite.firstIntValue(
          await db.rawQuery('SELECT SUM(duration_listened_ms) FROM listening_events')) ?? 0;
      final uniqueArtists = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(DISTINCT artist) FROM listening_events')) ?? 0;
      final uniqueGenres = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(DISTINCT genre) FROM listening_events')) ?? 0;

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
      final res = await db.query('neural_user_profile', where: 'id = 1', limit: 1);
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

  Future<void> saveNeuralUserVector(List<double> vector, int interactions) async {
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
      final rows = await db.query('neural_model_state', where: 'id = 1', limit: 1);
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
