part of '../noctra_local_database.dart';

extension LocalDatabaseCatalogTopics on NoctraLocalDatabase {
  Future<List<CatalogTopic>> loadCatalogTopics() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final raw = prefs.getString('noctra_catalog_topics');
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Expected List');
      return decoded
          .whereType<Map>()
          .map((item) => CatalogTopic(
                title: item['title']?.toString() ?? '',
                category: item['category']?.toString() ?? '',
                query: item['query']?.toString() ?? '',
              ))
          .where((topic) => topic.title.isNotEmpty && topic.query.isNotEmpty)
          .take(16)
          .toList(growable: false);
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted catalog topic cache', e);
      return const [];
    }
  }

  Future<void> saveCatalogTopics(List<CatalogTopic> topics) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString(
          'noctra_catalog_topics',
          jsonEncode(topics
              .take(16)
              .map((topic) => {
                    'title': topic.title,
                    'category': topic.category,
                    'query': topic.query,
                  })
              .toList()),
        );
      } catch (e) {
        NoctraLogger.w('Failed to persist catalog topics', e);
      }
    });
  }
}
