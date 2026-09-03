part of '../noctra_sqlite_database.dart';

extension SqliteNeuralState on NoctraSqliteDatabase {
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
