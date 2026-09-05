part of '../music_repository.dart';

mixin MusicRepositoryDownloadsMixin on ChangeNotifier {
  int get _mutationGeneration;
  set _mutationGeneration(int val);
  bool get _isLoaded;
  Set<String> get _removedDownloadIdsDuringInit;
  List<Song> get _downloads;
  Set<String> get _downloadIds;
  List<Song> get _favorites;
  Map<String, List<Song>> get _customFolders;
  Future<void>? get _initFuture;
  void Function(Song)? get onSongDownloadedCallback;

  void addDownloadedSong(Song song) {
    _mutationGeneration++;
    if (!_isLoaded) _removedDownloadIdsDuringInit.remove(song.id);
    _downloads.removeWhere((s) => s.id == song.id);
    _downloads.insert(0, song);
    _downloadIds.add(song.id);

    var favTouched = false;
    for (var i = 0; i < _favorites.length; i++) {
      if (_favorites[i].id == song.id) {
        _favorites[i] = _favorites[i].copyWith(
          isDownloaded: true,
          localFilePath: song.localFilePath,
        );
        favTouched = true;
      }
    }

    var foldersTouched = false;
    _customFolders.forEach((folderName, songs) {
      for (var i = 0; i < songs.length; i++) {
        if (songs[i].id == song.id) {
          songs[i] = songs[i].copyWith(
            isDownloaded: true,
            localFilePath: song.localFilePath,
          );
          foldersTouched = true;
        }
      }
    });

    if (_initFuture == null) {
      NoctraLocalDatabase().saveDownloads(_downloads);
      if (favTouched) NoctraLocalDatabase().saveFavorites(_favorites);
      if (foldersTouched) NoctraLocalDatabase().saveCustomFolders(_customFolders);
    }
    notifyListeners();
    onSongDownloadedCallback?.call(song);
  }

  void updateSongMetadata(Song updatedSong) {
    var favTouched = false;
    for (var i = 0; i < _favorites.length; i++) {
      if (_favorites[i].id == updatedSong.id) {
        _favorites[i] = _favorites[i].copyWith(
          title: updatedSong.title,
          artist: updatedSong.artist,
          album: updatedSong.album,
          artworkUrl: updatedSong.artworkUrl,
          genre: updatedSong.genre,
        );
        favTouched = true;
      }
    }
    var dlTouched = false;
    for (var i = 0; i < _downloads.length; i++) {
      if (_downloads[i].id == updatedSong.id) {
        _downloads[i] = _downloads[i].copyWith(
          title: updatedSong.title,
          artist: updatedSong.artist,
          album: updatedSong.album,
          artworkUrl: updatedSong.artworkUrl,
          genre: updatedSong.genre,
        );
        dlTouched = true;
      }
    }
    var folderTouched = false;
    _customFolders.forEach((_, songs) {
      for (var i = 0; i < songs.length; i++) {
        if (songs[i].id == updatedSong.id) {
          songs[i] = songs[i].copyWith(
            title: updatedSong.title,
            artist: updatedSong.artist,
            album: updatedSong.album,
            artworkUrl: updatedSong.artworkUrl,
            genre: updatedSong.genre,
          );
          folderTouched = true;
        }
      }
    });
    if (favTouched) NoctraLocalDatabase().saveFavorites(_favorites);
    if (dlTouched) NoctraLocalDatabase().saveDownloads(_downloads);
    if (folderTouched) NoctraLocalDatabase().saveCustomFolders(_customFolders);
    if (favTouched || dlTouched || folderTouched) notifyListeners();
  }

  Future<void> removeDownloadedSong(String songId,
      {bool deleteFile = true}) async {
    _mutationGeneration++;
    if (!_isLoaded) _removedDownloadIdsDuringInit.add(songId);
    final target = _downloads.where((d) => d.id == songId).firstOrNull;
    if (target == null) return;
    _downloads.removeWhere((d) => d.id == songId);
    _downloadIds.remove(songId);

    var favoritesTouched = false;
    for (var i = 0; i < _favorites.length; i++) {
      final fav = _favorites[i];
      if (fav.id == songId && (fav.isDownloaded || fav.localFilePath != null)) {
        _favorites[i] = fav.copyWith(
          isDownloaded: false,
          clearLocalFilePath: true,
        );
        favoritesTouched = true;
      }
    }

    var foldersTouched = false;
    _customFolders.forEach((_, songs) {
      for (var i = 0; i < songs.length; i++) {
        final s = songs[i];
        if (s.id == songId && (s.isDownloaded || s.localFilePath != null)) {
          songs[i] = s.copyWith(
            isDownloaded: false,
            clearLocalFilePath: true,
          );
          foldersTouched = true;
        }
      }
    });

    if (_initFuture == null) {
      NoctraLocalDatabase().saveDownloads(_downloads);
      if (favoritesTouched) {
        NoctraLocalDatabase().saveFavorites(_favorites);
      }
      if (foldersTouched) {
        NoctraLocalDatabase().saveCustomFolders(_customFolders);
      }
    }
    notifyListeners();
    if (deleteFile && !kIsWeb && target.localFilePath != null) {
      try {
        final f = File(target.localFilePath!);
        if (f.existsSync()) await f.delete();
      } catch (e) {
        NoctraLogger.w('Failed to delete local file for $songId', e);
      }
    }
  }
}
