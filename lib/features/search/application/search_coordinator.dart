import 'dart:async';
import '../../../shared/models/models.dart';
import '../domain/search_repository_contract.dart';

/// State representation for the search screen.
class SearchState {
  final String query;
  final String selectedSource;
  final bool isSearching;
  final List<Song> results;
  final String? errorMessage;

  const SearchState({
    this.query = '',
    this.selectedSource = 'all',
    this.isSearching = false,
    this.results = const [],
    this.errorMessage,
  });

  SearchState copyWith({
    String? query,
    String? selectedSource,
    bool? isSearching,
    List<Song>? results,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      selectedSource: selectedSource ?? this.selectedSource,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      errorMessage: errorMessage,
    );
  }
}

/// Application coordinator managing search execution and history.
class SearchCoordinator {
  final SearchRepositoryContract _repository;
  int _currentExecutionId = 0;

  SearchCoordinator(this._repository);

  int get currentExecutionId => _currentExecutionId;

  /// Executes an isolated search query bounded by the given execution ID.
  Future<List<Song>> executeSearch(
    String query, {
    String source = 'all',
    required int executionId,
  }) async {
    _currentExecutionId = executionId;
    final clean = query.trim();
    if (clean.isEmpty) {
      return const [];
    }

    try {
      final results = await _repository.search(clean, source: source);
      if (_currentExecutionId == executionId) {
        if (clean.length >= 2) {
          unawaited(Future.sync(() => _repository.saveQuery(clean)));
        }
        return results;
      }
      return const [];
    } catch (e) {
      if (_currentExecutionId == executionId) {
        rethrow;
      }
      return const [];
    }
  }

  Future<List<String>> fetchHistory() async {
    return await _repository.getRecentQueries();
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
  }
}
