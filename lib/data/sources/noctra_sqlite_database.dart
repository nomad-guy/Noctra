import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/utils/noctra_logger.dart';
import '../models/song_model.dart';

part 'parts/sqlite_schema_manager.dart';
part 'parts/sqlite_events_and_stats.dart';
part 'parts/sqlite_neural_state.dart';

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
      return await openDatabase(
        inMemoryDatabasePath,
        version: 2,
        onCreate: SqliteSchemaManager.createDb,
        onUpgrade: SqliteSchemaManager.upgradeDb,
      );
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'noctra_neural_store.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: SqliteSchemaManager.createDb,
      onUpgrade: SqliteSchemaManager.upgradeDb,
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA journal_mode=WAL;');
          await db.execute('PRAGMA synchronous=NORMAL;');
        } catch (_) {}
      },
    );
  }
}
