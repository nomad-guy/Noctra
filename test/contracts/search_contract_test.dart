import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/search/application/search_coordinator.dart';
import 'package:noctra/features/search/domain/search_repository_contract.dart';
import 'package:noctra/shared/models/models.dart';

class FakeSearchRepository implements SearchRepositoryContract {
  final List<String> history = [];
  final List<Song> catalog;

  FakeSearchRepository(this.catalog);

  @override
  Future<List<Song>> search(String query, {String source = 'all'}) async {
    final lower = query.toLowerCase();
    return catalog.where((s) => s.title.toLowerCase().contains(lower)).toList();
  }

  @override
  List<String> getRecentQueries() => List.unmodifiable(history);

  @override
  void saveQuery(String query) {
    if (!history.contains(query)) history.insert(0, query);
  }

  @override
  void clearHistory() => history.clear();
}

void main() {
  group('Search Subsystem Contract Tests', () {
    late FakeSearchRepository fakeRepo;
    late SearchCoordinator coordinator;

    setUp(() {
      fakeRepo = FakeSearchRepository([
        Song(
          id: 'test_1',
          title: 'Starboy',
          artist: 'The Weeknd',
          duration: const Duration(seconds: 230),
        ),
        Song(
          id: 'test_2',
          title: 'Starlight',
          artist: 'Muse',
          duration: const Duration(seconds: 240),
        ),
      ]);
      coordinator = SearchCoordinator(fakeRepo);
    });

    test('executes search and returns matching tracks', () async {
      final results = await coordinator.executeSearch('Star', executionId: 1);
      expect(results.length, equals(2));
      expect(results.first.title, equals('Starboy'));
    });

    test('ignores outdated execution ID results', () async {
      final future1 = coordinator.executeSearch('Starboy', executionId: 1);
      final results2 = await coordinator.executeSearch('Starlight', executionId: 2);
      final results1 = await future1;

      expect(results2.length, equals(1));
      expect(results2.first.title, equals('Starlight'));
      // Stale execution ID 1 gets discarded
      expect(results1, isEmpty);
    });

    test('records query in history upon successful execution', () async {
      await coordinator.executeSearch('Starboy', executionId: 1);
      final history = await coordinator.fetchHistory();
      expect(history, contains('Starboy'));
    });
  });
}
