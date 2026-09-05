import 'dart:async';
import '../../../services/ytdlp/music_service.dart';
import '../../../shared/models/models.dart';
import '../domain/search_repository_contract.dart';

/// Infrastructure implementation of [SearchRepositoryContract].
/// Bridges search requests to [MusicService] and maintains recent queries.
class SearchRepositoryImpl implements SearchRepositoryContract {
  final List<String> _recentQueries = [];
  static const int _maxHistory = 20;

  @override
  Future<List<Song>> search(String query, {String source = 'all'}) async {
    return await MusicService.search(query, source: source);
  }

  @override
  List<String> getRecentQueries() {
    return List.unmodifiable(_recentQueries);
  }

  @override
  Future<void> saveQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _recentQueries.remove(clean);
    _recentQueries.insert(0, clean);
    if (_recentQueries.length > _maxHistory) {
      _recentQueries.removeLast();
    }
  }

  @override
  Future<void> clearHistory() async {
    _recentQueries.clear();
  }
}
