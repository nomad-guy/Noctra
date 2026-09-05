part of '../music_repository.dart';

/// Mixin containing user playlist and custom folder CRUD operations.
mixin MusicRepositoryFoldersMixin on ChangeNotifier {
  int get _mutationGeneration;
  set _mutationGeneration(int val);
  Map<String, List<Song>> get _customFolders;
  List<Song> get _downloads;
  Future<void>? get _initFuture;

  void createFolder(String name) {
    _mutationGeneration++;
    final clean = name.trim();
    if (clean.isNotEmpty && !_customFolders.containsKey(clean)) {
      _customFolders[clean] = [];
      if (_initFuture == null) {
        NoctraLocalDatabase().saveCustomFolders(_customFolders);
      }
      notifyListeners();
    }
  }

  void addSongToFolder(String folderName, Song song) {
    _mutationGeneration++;
    if (_customFolders.containsKey(folderName)) {
      final list = _customFolders[folderName]!;
      if (!list.any((s) => s.id == song.id)) {
        final dl = _downloads.where((d) => d.id == song.id).firstOrNull;
        final path = dl?.localFilePath;
        list.add(song.copyWith(
          isDownloaded: dl != null,
          localFilePath: path,
          clearLocalFilePath: path == null,
        ));
        if (_initFuture == null) {
          NoctraLocalDatabase().saveCustomFolders(_customFolders);
        }
        notifyListeners();
      }
    }
  }

  void removeSongFromFolder(String folderName, String songId) {
    _mutationGeneration++;
    if (_customFolders.containsKey(folderName)) {
      _customFolders[folderName]!.removeWhere((s) => s.id == songId);
      if (_initFuture == null) {
        NoctraLocalDatabase().saveCustomFolders(_customFolders);
      }
      notifyListeners();
    }
  }

  void renameFolder(String oldName, String newName) {
    _mutationGeneration++;
    final cleanNew = newName.trim();
    if (oldName != cleanNew &&
        cleanNew.isNotEmpty &&
        _customFolders.containsKey(oldName) &&
        !_customFolders.containsKey(cleanNew)) {
      final songs = _customFolders.remove(oldName)!;
      _customFolders[cleanNew] = songs;
      if (_initFuture == null) {
        NoctraLocalDatabase().saveCustomFolders(_customFolders);
      }
      notifyListeners();
    }
  }

  void deleteFolder(String folderName) {
    _mutationGeneration++;
    if (folderName != 'Favorites' && _customFolders.containsKey(folderName)) {
      _customFolders.remove(folderName);
      if (_initFuture == null) {
        NoctraLocalDatabase().saveCustomFolders(_customFolders);
      }
      notifyListeners();
    }
  }
}
