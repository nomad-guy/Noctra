import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/noctra_logger.dart';
import '../models/catalog_topic.dart';
import '../models/download_location.dart';
import '../models/song_model.dart';
import '../repositories/taste_vector_engine.dart';
import 'noctra_manifest_store.dart';

part 'parts/local_database_playback.dart';
part 'parts/local_database_decoders.dart';
part 'parts/local_database_manifests.dart';
part 'parts/local_database_catalog_topics.dart';

class NoctraLocalDatabase {
  static final NoctraLocalDatabase _instance =
      NoctraLocalDatabase._internal();
  factory NoctraLocalDatabase() => _instance;
  NoctraLocalDatabase._internal();

  final NoctraManifestStore _manifestStore = NoctraManifestStore();
  final List<Song> _favorites = [];
  final List<Song> _downloads = [];
  final List<Song> _recent = [];
  final Map<String, List<Song>> _customFolders = {};
  List<double>? _cachedTasteVector;
  String _cachedThemeMode = 'noirBlack';
  SharedPreferences? _prefs;
  bool _hasCompletedOnboarding = false;
  List<String> _onboardedArtists = [];
  List<String> _onboardedGenres = [];
  List<String> _onboardedLanguages = [];
  bool _isLoaded = false;
  Future<void>? _initFuture;

  Future<void> _prefsWriteQueue = Future.value();

  Future<T> _enqueuePrefsWrite<T>(Future<T> Function() op) {
    final result = _prefsWriteQueue.then((_) => op());
    _prefsWriteQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  List<String> get onboardedArtists => List.unmodifiable(_onboardedArtists);
  List<String> get onboardedGenres => List.unmodifiable(_onboardedGenres);
  List<String> get onboardedLanguages => List.unmodifiable(_onboardedLanguages);
  String getCachedThemeMode() => _cachedThemeMode;

  static String normalizeThemeMode(String? raw) {
    if (raw == null) return 'noirBlack';
    final lower = raw.trim().toLowerCase();
    if (lower == 'noirwhite' || lower == 'light') return 'noirWhite';
    if (lower == 'liquidglass' || lower == 'liquid_glass') return 'liquidGlass';
    return 'noirBlack';
  }

  String getCachedDownloadLocation() {
    try {
      return _prefs?.getString('noctra_download_location') ??
          DownloadLocation.appDocs;
    } catch (_) {
      return DownloadLocation.appDocs;
    }
  }

  Future<void> saveDownloadLocation(String key) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_download_location', key);
      } catch (e) {
        NoctraLogger.w('Failed to persist download location', e);
      }
    });
  }

  Future<void> saveCachedThemeMode(String modeName) => saveThemeMode(modeName);

  @visibleForTesting
  void debugResetForTest() {
    _prefs = null;
    _isLoaded = false;
    _initFuture = null;
    _favorites.clear();
    _downloads.clear();
    _recent.clear();
    _customFolders.clear();
    _cachedTasteVector = null;
    _cachedThemeMode = 'noirBlack';
    _hasCompletedOnboarding = false;
    _onboardedArtists = [];
    _onboardedGenres = [];
    _onboardedLanguages = [];
    _manifestStore.debugResetForTest();
    _prefsWriteQueue = Future.value();
  }

  Future<void> init() async {
    if (_isLoaded) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doInit();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _hasCompletedOnboarding = prefs.getBool('noctra_onboarded') ?? false;
      _onboardedArtists = prefs.getStringList('noctra_onboarded_artists') ?? [];
      _onboardedGenres = prefs.getStringList('noctra_onboarded_genres') ?? [];
      _onboardedLanguages =
          prefs.getStringList('noctra_onboarded_languages') ?? [];

      _favorites.clear();
      _favorites.addAll(LocalDatabaseDecoders.safeDecodeSongList(
          prefs.getString('noctra_favs'), 'noctra_favs', prefs));
      _downloads.clear();
      _downloads.addAll(LocalDatabaseDecoders.safeDecodeSongList(
          prefs.getString('noctra_downloads'), 'noctra_downloads', prefs));
      _recent.clear();
      _recent.addAll(LocalDatabaseDecoders.safeDecodeSongList(
          prefs.getString('noctra_recent'), 'noctra_recent', prefs));
      _customFolders.clear();
      _customFolders.addAll(LocalDatabaseDecoders.safeDecodeCustomFolders(
          prefs.getString('noctra_custom_folders'), prefs));
      _cachedTasteVector = LocalDatabaseDecoders.safeDecodeTasteVector(
          prefs.getString('noctra_taste_vector'), prefs);
      final savedTheme = prefs.getString('noctra_theme_mode');
      _cachedThemeMode = normalizeThemeMode(savedTheme);
      if (savedTheme != _cachedThemeMode) {
        unawaited(prefs.setString('noctra_theme_mode', _cachedThemeMode));
      }

      final kgStr = prefs.getString('noctra_kg_manifests');
      if (kgStr != null) {
        try {
          _manifestStore
              .loadFromRawMap(jsonDecode(kgStr) as Map<String, dynamic>);
        } catch (e) {
          NoctraLogger.w('Self-healing manifests knowledge graph', e);
          prefs.remove('noctra_kg_manifests');
        }
      }
      _isLoaded = true;
    } catch (e) {
      NoctraLogger.e(
          'Database initialization failed; will retry on next access', e);
      _favorites.clear();
      _downloads.clear();
      _recent.clear();
      _customFolders.clear();
      _cachedTasteVector = null;
      _isLoaded = false;
    }
  }

  Future<void> saveThemeMode(String mode) {
    final clean = normalizeThemeMode(mode);
    _cachedThemeMode = clean;
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_theme_mode', clean);
      } catch (e) {
        NoctraLogger.e('Failed to persist theme mode', e);
      }
    });
  }

  Future<void> saveFavorites(List<Song> songs) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString(
            'noctra_favs', jsonEncode(songs.map((e) => e.toMap()).toList()));
        _favorites
          ..clear()
          ..addAll(songs);
      } catch (e) {
        NoctraLogger.w('Failed to save favorites', e);
      }
    });
  }

  Future<void> saveDownloads(List<Song> songs) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_downloads',
            jsonEncode(songs.map((e) => e.toMap()).toList()));
        _downloads
          ..clear()
          ..addAll(songs);
      } catch (e) {
        NoctraLogger.w('Failed to save downloads', e);
      }
    });
  }

  Future<void> saveRecent(List<Song> songs) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_recent',
            jsonEncode(songs.take(50).map((e) => e.toMap()).toList()));
        _recent
          ..clear()
          ..addAll(songs.take(50));
      } catch (e) {
        NoctraLogger.w('Failed to save recent tracks', e);
      }
    });
  }

  Future<void> saveCustomFolders(Map<String, List<Song>> folders) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        final map = <String, dynamic>{};
        folders.forEach((k, v) => map[k] = v.map((s) => s.toMap()).toList());
        await prefs.setString('noctra_custom_folders', jsonEncode(map));
        _customFolders
          ..clear()
          ..addAll(folders);
      } catch (e) {
        NoctraLogger.w('Failed to save custom folders', e);
      }
    });
  }

  Future<void> saveTasteVector(List<double> vector) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_taste_vector', jsonEncode(vector));
        _cachedTasteVector = List<double>.unmodifiable(vector);
      } catch (e) {
        NoctraLogger.w('Failed to save taste vector', e);
      }
    });
  }

  Future<List<Song>> loadFavorites() async {
    await init();
    return List<Song>.unmodifiable(_favorites);
  }

  Future<List<Song>> loadDownloads() async {
    await init();
    return List<Song>.unmodifiable(_downloads);
  }

  Future<List<Song>> loadRecent() async {
    await init();
    return List<Song>.unmodifiable(_recent);
  }

  Future<Map<String, List<Song>>> loadCustomFolders() async {
    await init();
    return Map<String, List<Song>>.unmodifiable(_customFolders);
  }

  Future<List<double>?> loadTasteVector() async {
    await init();
    return _cachedTasteVector != null
        ? List<double>.unmodifiable(_cachedTasteVector!)
        : null;
  }
}
