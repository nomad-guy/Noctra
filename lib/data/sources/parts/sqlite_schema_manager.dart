part of '../noctra_sqlite_database.dart';

extension SqliteSchemaManager on NoctraSqliteDatabase {
  static Future<void> createDb(Database db, int version) async {
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

  static Future<void> upgradeDb(
      Database db, int oldVersion, int newVersion) async {
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
}
