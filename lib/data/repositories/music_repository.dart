import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../models/ai_folder_model.dart';
import '../sources/noctra_local_database.dart';
import 'taste_vector_engine.dart';
import '../../services/ytdlp/music_service.dart';
import '../../core/utils/noctra_localization.dart';
import '../../core/utils/noctra_logger.dart';

part 'parts/music_repository_ai_curation.dart';
part 'parts/music_repository_folders.dart';
part 'parts/music_repository_reconciliation.dart';

class AIPlaylist {
  final String id, title, subtitle, artworkUrl, vibeKey;
  final List<Song> tracks;
  const AIPlaylist(
      {required this.id,
      required this.title,
      required this.subtitle,
      required this.artworkUrl,
      required this.vibeKey,
      this.tracks = const []});
}

class VibeChip {
  final String keyName, label;
  final IconData iconData;
  const VibeChip(
      {required this.keyName, required this.label, required this.iconData});
}

class MusicRepository extends ChangeNotifier
    with
        MusicRepositoryAICurationMixin,
        MusicRepositoryFoldersMixin,
        MusicRepositoryReconciliationMixin {
  static final MusicRepository _instance = MusicRepository._internal();
  factory MusicRepository() => _instance;
  static MusicRepository get instance => _instance;

  @override
  final List<Song> _localLibrary = [];
  @override
  final List<Song> _downloads = [];
  @override
  final List<Song> _favorites = [];
  @override
  final Set<String> _downloadIds = {};
  final Set<String> _favoriteIds = {};
  @override
  final List<Song> _recentlyPlayed = [];
  @override
  final Map<String, List<Song>> _customFolders = {};
  @override
  List<double> _userTasteVector = TasteVectorEngine.getDefaultVector();
  List<double> _cachedTasteVector =
      List.unmodifiable(TasteVectorEngine.getDefaultVector());

  List<Song> get localLibrary => List.unmodifiable(_localLibrary);
  List<Song> get downloads => List.unmodifiable(_downloads);
  List<Song> get favorites => List.unmodifiable(_favorites);
  List<Song> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  Map<String, List<Song>> get customFolders =>
      Map<String, List<Song>>.unmodifiable(
        _customFolders.map((k, v) =>
            MapEntry<String, List<Song>>(k, List<Song>.unmodifiable(v))),
      );
  List<double> get userTasteVector => _cachedTasteVector;

  bool _isLoaded = false;
  @override
  Future<void>? _initFuture;
  @override
  int _mutationGeneration = 0;
  final Set<String> _removedFavoriteIdsDuringInit = {};
  final Set<String> _removedDownloadIdsDuringInit = {};

  void Function(Song)? onSongDownloadedCallback;

  MusicRepository._internal();

  @visibleForTesting
  void debugResetForTest() {
    _isLoaded = false;
    _initFuture = null;
    _mutationGeneration = 0;
    _removedFavoriteIdsDuringInit.clear();
    _removedDownloadIdsDuringInit.clear();
    _localLibrary.clear();
    _downloads.clear();
    _favorites.clear();
    _downloadIds.clear();
    _favoriteIds.clear();
    _recentlyPlayed.clear();
    _customFolders.clear();
    _userTasteVector = TasteVectorEngine.getDefaultVector();
    _cachedTasteVector = List.unmodifiable(_userTasteVector);
  }

  Future<void> init() async {
    if (_isLoaded) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _loadFromDatabase();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final db = NoctraLocalDatabase();
      final favs = await db.loadFavorites();
      final downs = await db.loadDownloads();
      final recents = await db.loadRecent();
      final folders = await db.loadCustomFolders();
      final tv = await db.loadTasteVector();

      if (_mutationGeneration == 0) {
        _favorites.clear();
        _favorites.addAll(favs);
        _favoriteIds.clear();
        _favoriteIds.addAll(favs.map((s) => s.id));

        _downloads.clear();
        _downloads.addAll(downs);
        _downloadIds.clear();
        _downloadIds.addAll(downs.map((s) => s.id));

        _customFolders.clear();
        _customFolders.addAll(folders);

        _recentlyPlayed.clear();
        _recentlyPlayed.addAll(recents);

        if (tv != null && tv.length == TasteVectorEngine.vectorDimension) {
          _userTasteVector = tv;
          _cachedTasteVector = List.unmodifiable(_userTasteVector);
        }
      } else {
        // Startup race protection: user performed mutations before/during database load!
        // Merge without overwriting fresh user actions.
        for (final fav in favs) {
          if (!_favoriteIds.contains(fav.id) &&
              !_removedFavoriteIdsDuringInit.contains(fav.id)) {
            _favorites.add(fav);
            _favoriteIds.add(fav.id);
          }
        }
        for (final down in downs) {
          if (!_downloadIds.contains(down.id) &&
              !_removedDownloadIdsDuringInit.contains(down.id)) {
            _downloads.add(down);
            _downloadIds.add(down.id);
          }
        }
        for (final entry in folders.entries) {
          final existing = _customFolders[entry.key];
          if (existing == null) {
            _customFolders[entry.key] = List<Song>.from(entry.value);
          } else {
            for (final song in entry.value) {
              if (!existing.any((s) => s.id == song.id)) {
                existing.add(song);
              }
            }
          }
        }
        for (final r in recents) {
          if (!_recentlyPlayed.any((s) => s.id == r.id)) {
            _recentlyPlayed.add(r);
          }
        }
      }

      // Reconcile disk state.
      // Crucial: pruning occurs AFTER _customFolders is loaded,
      // so stale download paths in custom folders are properly cleaned up.
      await pruneMissingDownloadedFiles();
      await cleanStaleTemporaryFiles();
      await recoverOrphanedDownloadedFiles();

      _removedFavoriteIdsDuringInit.clear();
      _removedDownloadIdsDuringInit.clear();
      _isLoaded = true;
      if (_mutationGeneration != 0) {
        _persistState();
      }
    } catch (e) {
      // Keep the repository retryable. A transient storage failure should not
      // permanently freeze the app with an empty library.
      _isLoaded = false;
      NoctraLogger.w('Music repository load failed; will retry', e);
    }
    // Always notify listeners — even on partial failure — so widgets
    // don't remain stuck on stale default state.
    notifyListeners();
  }

  void initOnboardingTaste(
      {required List<String> languages,
      required List<String> genres,
      required List<String> artists}) {
    final vec = TasteVectorEngine.createVectorFromPreferences(
      languages: languages,
      genres: genres,
      artists: artists,
    );
    _userTasteVector = vec;
    _cachedTasteVector = List.unmodifiable(_userTasteVector);
    _persistState();
    notifyListeners();
  }

  void _persistState() {
    // Every save is individually wrapped inside NoctraLocalDatabase with its
    // own error log, so a failure in one list never masks the others.
    final db = NoctraLocalDatabase();
    db.saveFavorites(_favorites);
    db.saveDownloads(_downloads);
    db.saveRecent(_recentlyPlayed);
    db.saveCustomFolders(_customFolders);
    db.saveTasteVector(_userTasteVector);
  }

  String getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return NoctraLocalization.tr('good_morning');
    if (hour < 17) return NoctraLocalization.tr('good_afternoon');
    return NoctraLocalization.tr('good_evening');
  }

  bool isFavorite(String songId) => _favoriteIds.contains(songId);
  bool isDownloaded(String songId) => _downloadIds.contains(songId);

  void toggleFavorite(Song song) {
    _mutationGeneration++;
    if (isFavorite(song.id)) {
      _favorites.removeWhere((s) => s.id == song.id);
      _favoriteIds.remove(song.id);
      if (!_isLoaded) _removedFavoriteIdsDuringInit.add(song.id);
    } else {
      if (!_isLoaded) _removedFavoriteIdsDuringInit.remove(song.id);
      // Stamp the favorite with the current LOCAL download state so a Song
      // arriving from a resolver with stale `isDownloaded=false` cannot
      // persist a favorite row that loses its offline path. Presence in the
      // downloads list IS the local truth (the download may predate this
      // resolver copy), so it drives both flags.
      final dl = _downloads.where((d) => d.id == song.id).firstOrNull;
      final path = dl?.localFilePath;
      _favorites.insert(
        0,
        song.copyWith(
          isFavorite: true,
          isDownloaded: dl != null,
          localFilePath: path,
          // Never fall back to a stale resolver path: only a path that
          // matches the local downloads list may be persisted.
          clearLocalFilePath: path == null,
        ),
      );
      _favoriteIds.add(song.id);
    }
    if (_initFuture == null) {
      NoctraLocalDatabase().saveFavorites(_favorites);
    }
    notifyListeners();
  }

  void recordSongPlayed(Song song,
      {String action = 'play', int listenedSeconds = 0}) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    // Re-stamp the playing song with the local user state (favorite /
    // downloaded) so the manifest row matches the in-memory truth.
    // Without this, a Song arriving from the resolver with stale
    // `isFavorite=false` would overwrite the manifest and break
    // analytics that join on `is_in_favorites`.
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

  void addDownloadedSong(Song song) {
    _mutationGeneration++;
    if (!_isLoaded) _removedDownloadIdsDuringInit.remove(song.id);
    _downloads.removeWhere((s) => s.id == song.id);
    _downloads.insert(0, song);
    _downloadIds.add(song.id);

    // Stamp matching favorite rows with the active offline file path
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

    // Stamp matching songs across custom playlists/folders
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

  /// Updates song metadata (artwork, title, artist, album, genre) in-place
  /// across favorites, downloads, and custom folders without altering list ordering or index positions.
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

  /// Removes a download from the offline library and (optionally) deletes its
  /// local file. A download that was never persisted to disk (web / failed
  /// rename) is still removed from the list so it stops appearing as offline.
  Future<void> removeDownloadedSong(String songId,
      {bool deleteFile = true}) async {
    _mutationGeneration++;
    if (!_isLoaded) _removedDownloadIdsDuringInit.add(songId);
    final target = _downloads.where((d) => d.id == songId).firstOrNull;
    if (target == null) return;
    _downloads.removeWhere((d) => d.id == songId);
    _downloadIds.remove(songId);

    // Un-stamp favorite rows that point at this download so they never keep
    // advertising an offline file that no longer exists (state ownership).
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

    // Un-stamp custom folders that hold this song so offline playback doesn't fail
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

  /// Bulk-adds songs to favorites with a SINGLE full-state write. Import
  /// flows (Spotify/Apple Music/YouTube Music exports) must not trigger one
  /// serialized write per matched track — that is O(N) full-list snapshots.
  /// Idempotent: songs already favorited (by ID) are skipped.
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

  List<String> getTopArtists({int limit = 5}) =>
      NoctraLocalDatabase().getTopArtists(limit: limit);
}
