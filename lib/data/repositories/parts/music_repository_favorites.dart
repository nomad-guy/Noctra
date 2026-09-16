part of '../music_repository.dart';

mixin MusicRepositoryFavoritesMixin on ChangeNotifier {
  int get _mutationGeneration;
  set _mutationGeneration(int val);
  bool get _isLoaded;
  Set<String> get _removedFavoriteIdsDuringInit;
  List<Song> get _favorites;
  Set<String> get _favoriteIds;
  List<Song> get _downloads;
  Future<void>? get _initFuture;

  /// Taste-signal hook owned by the main class (see MusicRepository).
  void Function(Song)? get onFavoriteToggled;

  bool isFavorite(String songId) => _favoriteIds.contains(songId);

  void toggleFavorite(Song song) {
    _mutationGeneration++;
    if (isFavorite(song.id)) {
      _favorites.removeWhere((s) => s.id == song.id);
      _favoriteIds.remove(song.id);
      if (!_isLoaded) _removedFavoriteIdsDuringInit.add(song.id);
    } else {
      if (!_isLoaded) _removedFavoriteIdsDuringInit.remove(song.id);
      final dl = _downloads.where((d) => d.id == song.id).firstOrNull;
      final path = dl?.localFilePath;
      _favorites.insert(
        0,
        song.copyWith(
          isFavorite: true,
          isDownloaded: dl != null,
          localFilePath: path,
          clearLocalFilePath: path == null,
        ),
      );
      _favoriteIds.add(song.id);
      // Strongest positive taste signal — fired via onFavoriteToggled so the
      // composition layer routes it to the signal tracker without a
      // data → services/ai dependency (architecture rule).
      onFavoriteToggled?.call(song);
    }
    if (_initFuture == null) {
      NoctraLocalDatabase().saveFavorites(_favorites);
    }
    notifyListeners();
  }

  void addSongsToFavorites(Iterable<Song> songs) {
    _mutationGeneration++;
    var added = false;
    for (final song in songs) {
      if (isFavorite(song.id)) continue;
      final dl = _downloads.where((d) => d.id == song.id).firstOrNull;
      final path = dl?.localFilePath;
      _favorites.insert(
        0,
        song.copyWith(
          isFavorite: true,
          isDownloaded: dl != null,
          localFilePath: path,
          clearLocalFilePath: path == null,
        ),
      );
      _favoriteIds.add(song.id);
      added = true;
    }
    if (added) {
      if (_initFuture == null) NoctraLocalDatabase().saveFavorites(_favorites);
      notifyListeners();
    }
  }
}
