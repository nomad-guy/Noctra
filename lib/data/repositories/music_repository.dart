import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../models/ai_folder_model.dart';
import '../models/ai_playlist_model.dart';
import '../sources/noctra_local_database.dart';
import 'taste_vector_engine.dart';
import '../../services/ytdlp/music_service.dart';
import '../../core/utils/noctra_logger.dart';

export '../models/ai_playlist_model.dart';

part 'parts/ai_curation_scorer.dart';
part 'parts/music_repository_ai_curation.dart';
part 'parts/music_repository_ai_presets.dart';
part 'parts/music_repository_folders.dart';
part 'parts/music_repository_reconciliation.dart';
part 'parts/music_repository_downloads.dart';
part 'parts/music_repository_favorites.dart';
part 'parts/music_repository_playback_history.dart';

class MusicRepository extends ChangeNotifier
    with
        MusicRepositoryAICurationMixin,
        MusicRepositoryFoldersMixin,
        MusicRepositoryReconciliationMixin,
        MusicRepositoryDownloadsMixin,
        MusicRepositoryFavoritesMixin,
        MusicRepositoryPlaybackHistoryMixin {
  static MusicRepository _instance = MusicRepository._internal();
  factory MusicRepository() => _instance;
  static MusicRepository get instance => _instance;

  /// Test seam only: Riverpod disposes the ChangeNotifier when a
  /// ProviderScope is torn down, after which the singleton can never be
  /// used again (debugAssertNotDisposed). Widget tests that mount the full
  /// shell across multiple tests call this to get a fresh instance.
  @visibleForTesting
  static void debugResetSingleton() {
    _instance = MusicRepository._internal();
  }

  @override
  final List<Song> _localLibrary = [];
  @override
  final List<Song> _downloads = [];
  @override
  final List<Song> _favorites = [];
  @override
  final Set<String> _downloadIds = {};
  @override
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

  @override
  bool _isLoaded = false;
  @override
  Future<void>? _initFuture;
  @override
  int _mutationGeneration = 0;
  @override
  final Set<String> _removedFavoriteIdsDuringInit = {};
  @override
  final Set<String> _removedDownloadIdsDuringInit = {};

  @override
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
      _isLoaded = false;
      NoctraLogger.w('Music repository load failed; will retry', e);
    }
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
    final db = NoctraLocalDatabase();
    db.saveFavorites(_favorites);
    db.saveDownloads(_downloads);
    db.saveRecent(_recentlyPlayed);
    db.saveCustomFolders(_customFolders);
    db.saveTasteVector(_userTasteVector);
  }

  bool isDownloaded(String songId) => _downloadIds.contains(songId);

  List<String> getTopArtists({int limit = 5}) =>
      NoctraLocalDatabase().getTopArtists(limit: limit);

  /// Preference/onboarding persistence passthroughs so presentation code
  /// never touches [NoctraLocalDatabase] directly. All reads/writes stay in
  List<String> get onboardedArtists => NoctraLocalDatabase().onboardedArtists;
  List<String> get onboardedLanguages =>
      NoctraLocalDatabase().onboardedLanguages;
  List<String> get onboardedGenres => NoctraLocalDatabase().onboardedGenres;

  Future<void> completeOnboarding({
    required List<String> languages,
    required List<String> genres,
    required List<String> artists,
  }) =>
      NoctraLocalDatabase().completeOnboarding(
        languages: languages,
        genres: genres,
        artists: artists,
      );

  Future<void> saveDownloadLocation(String key) =>
      NoctraLocalDatabase().saveDownloadLocation(key);
}
