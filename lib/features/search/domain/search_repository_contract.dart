import 'dart:async';
import '../../../shared/models/models.dart';

/// Pure domain contract for search operations across music catalogs.
abstract class SearchRepositoryContract {
  /// Executes search with query normalization and optional source filter.
  Future<List<Song>> search(String query, {String source = 'all'});

  /// Returns recent search queries stored locally.
  FutureOr<List<String>> getRecentQueries();

  /// Saves a search query to history.
  FutureOr<void> saveQuery(String query);

  /// Clears recent search queries.
  FutureOr<void> clearHistory();
}
