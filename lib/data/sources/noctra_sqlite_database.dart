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
      return await openDatabase(inMemoryDatabasePath, version: 1, onCreate: _createDb);
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'noctra_neural_store.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
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
        timestamp INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS track_embeddings (
        song_id TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
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

    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_timestamp ON listening_events(timestamp DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_artist ON listening_events(artist);');
  }

  Future<void> recordListeningEvent({
    required Song song,
    required String eventType,
    required double signalScore,
    double completionRate = 1.0,
  }) async {
    try {
      final db = await database;
      await db.insert('listening_events', {
        'song_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'genre': song.genre ?? 'Music',
        'event_type': eventType,
        'signal_score': signalScore,
        'completion_rate': completionRate,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Save or update track embedding
      if (song.featureVector.isNotEmpty) {
        await db.insert(
          'track_embeddings',
          {
            'song_id': song.id,
            'title': song.title,
            'artist': song.artist,
            'vector_json': jsonEncode(song.featureVector),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      NoctraLogger.w('SQLite event recording error', e);
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
}
