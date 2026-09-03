part of '../music_repository.dart';

mixin MusicRepositoryPlaybackHistoryMixin on ChangeNotifier {
  List<Song> get _recentlyPlayed;
  Set<String> get _downloadIds;
  List<double> get _userTasteVector;
  set _userTasteVector(List<double> val);
  set _cachedTasteVector(List<double> val);
  bool isFavorite(String songId);

  void recordSongPlayed(Song song,
      {String action = 'play', int listenedSeconds = 0}) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    final stamped = song.copyWith(
      isFavorite: isFavorite(song.id),
      isDownloaded: _downloadIds.contains(song.id),
    );
    _recentlyPlayed.insert(0, stamped);
    if (_recentlyPlayed.length > 50) _recentlyPlayed.removeLast();

    NoctraLocalDatabase().recordManifest(stamped,
        action: action, listenedSeconds: listenedSeconds);
    NoctraLocalDatabase().saveRecent(_recentlyPlayed);
    updateTasteVector(stamped, action);
    notifyListeners();
  }

  void clearRecentlyPlayed() {
    _recentlyPlayed.clear();
    NoctraLocalDatabase().saveRecent(_recentlyPlayed);
    notifyListeners();
  }

  void removeRecentlyPlayed(String songId) {
    _recentlyPlayed.removeWhere((s) => s.id == songId);
    NoctraLocalDatabase().saveRecent(_recentlyPlayed);
    notifyListeners();
  }

  void updateTasteVector(Song song, String action) {
    _userTasteVector = TasteVectorEngine.updateVector(
      current: _userTasteVector,
      songVector: song.featureVector,
      action: action,
    );
    _cachedTasteVector = List.unmodifiable(_userTasteVector);
    NoctraLocalDatabase().saveTasteVector(_userTasteVector);
    notifyListeners();
  }

  int computeMatchScore(Song song) {
    final songEmbedding = song.hasUsableEmbedding
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);
    final sim =
        TasteVectorEngine.cosineSimilarity(songEmbedding, _userTasteVector);
    final historyAffinity =
        NoctraLocalDatabase().getArtistAffinity(song.artist);
    return ((sim * 80) + (historyAffinity * 19)).round().clamp(10, 99);
  }
}
