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

class NoctraLocalDatabase {
  static final NoctraLocalDatabase _instance = NoctraLocalDatabase._internal();
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
  Future<void>? _initFuture; // C3: cache to prevent concurrent init() calls

  /// Serializes full-snapshot prefs writes so they complete in CALL order.
  /// Without this, two rapid async writes (favorite toggle, play recording,
  /// position save) can land out of order and the OLDER snapshot can
  /// overwrite the NEWER one on disk, losing user state on restart.
  Future<void> _prefsWriteQueue = Future.value();

  Future<T> _enqueuePrefsWrite<T>(Future<T> Function() op) {
    final result = _prefsWriteQueue.then((_) => op());
    // Keep the chain alive even when an individual write fails.
    _prefsWriteQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  List<String> get onboardedArtists => List.unmodifiable(_onboardedArtists);
  List<String> get onboardedGenres => List.unmodifiable(_onboardedGenres);
  List<String> get onboardedLanguages => List.unmodifiable(_onboardedLanguages);
  String getCachedThemeMode() => _cachedThemeMode;

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

  /// Persists the active theme so it survives app restarts.
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
    if (_initFuture != null) return _initFuture!; // C3: reuse in-flight init
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
      _favorites.addAll(_safeDecodeSongList(
          prefs.getString('noctra_favs'), 'noctra_favs', prefs));
      _downloads.clear();
      _downloads.addAll(_safeDecodeSongList(
          prefs.getString('noctra_downloads'), 'noctra_downloads', prefs));
      _recent.clear();
      _recent.addAll(_safeDecodeSongList(
          prefs.getString('noctra_recent'), 'noctra_recent', prefs));
      _customFolders.clear();
      _customFolders.addAll(_safeDecodeCustomFolders(
          prefs.getString('noctra_custom_folders'), prefs));
      _cachedTasteVector =
          _safeDecodeTasteVector(prefs.getString('noctra_taste_vector'), prefs);
      final savedTheme = prefs.getString('noctra_theme_mode') ?? 'noirBlack';
      if (savedTheme == 'amoled' || savedTheme == 'noirAmoled') {
        _cachedThemeMode = 'noirBlack';
        unawaited(prefs.setString('noctra_theme_mode', 'noirBlack'));
      } else {
        _cachedThemeMode = savedTheme;
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
      // Reset in-memory state and keep _isLoaded false so subsequent calls can retry
      _favorites.clear();
      _downloads.clear();
      _recent.clear();
      _customFolders.clear();
      _cachedTasteVector = null;
      _isLoaded = false;
    }
  }

  List<Song> _safeDecodeSongList(
      String? jsonStr, String key, SharedPreferences prefs) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) throw const FormatException('Expected List');
      // Dedupe on identity+content: a row is dropped ONLY when it repeats an
      // already-loaded (id, title, artist) triple (re-import / double write).
      // Two DIFFERENT recordings that happen to share an ID (cross-provider
      // collision) must both survive — silently dropping one is data loss.
      final seen = <String, Set<String>>{}; // id -> {title\u0000artist} seen
      final list = <Song>[];
      for (final item in decoded) {
        if (item is Map) {
          final song = Song.fromMap(Map<String, dynamic>.from(item));
          if (song.title.isEmpty) continue;
          final effectiveId = song.id.isNotEmpty
              ? song.id
              : 'syn_${song.title.hashCode ^ song.artist.hashCode}';
          final dedupSong =
              song.id.isEmpty ? song.copyWith(id: effectiveId) : song;
          final contentKey = '${dedupSong.title}\u0000${dedupSong.artist}';
          final seenContent = seen.putIfAbsent(effectiveId, () => <String>{});
          if (seenContent.add(contentKey)) list.add(dedupSong);
        }
      }
      return list;
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted list for key $key', e);
      prefs.remove(key);
      return [];
    }
  }

  Map<String, List<Song>> _safeDecodeCustomFolders(
      String? jsonStr, SharedPreferences prefs) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) throw const FormatException('Expected Map');
      final res = <String, List<Song>>{};
      int syntheticId = 0;
      decoded.forEach((rawK, v) {
        final k = rawK?.toString();
        if (k != null && k.isNotEmpty && v is List) {
          // Content-aware dedupe, same policy as _safeDecodeSongList: only
          // drop exact (id, title, artist) repeats, never a distinct
          // recording that merely shares an ID.
          final seen = <String, Set<String>>{};
          final songs = <Song>[];
          for (final item in v) {
            if (item is Map) {
              final song = Song.fromMap(Map<String, dynamic>.from(item));
              if (song.title.isEmpty) continue;
              final effectiveId = song.id.isNotEmpty
                  ? song.id
                  : 'syn_f_${song.title.hashCode}_${syntheticId++}';
              final dedupSong =
                  song.id.isEmpty ? song.copyWith(id: effectiveId) : song;
              final contentKey = '${dedupSong.title}\u0000${dedupSong.artist}';
              final seenContent =
                  seen.putIfAbsent(effectiveId, () => <String>{});
              if (seenContent.add(contentKey)) songs.add(dedupSong);
            }
          }
          res[k] = songs;
        }
      });
      return res;
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted custom folders', e);
      prefs.remove('noctra_custom_folders');
      return {};
    }
  }

  List<double> _safeDecodeTasteVector(
      String? jsonStr, SharedPreferences prefs) {
    final def = TasteVectorEngine.getDefaultVector();
    if (jsonStr == null || jsonStr.trim().isEmpty) return def;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) throw const FormatException('Expected List');
      final list = <double>[];
      for (final e in decoded) {
        final val = (e as num).toDouble();
        list.add(val.isNaN || val.isInfinite ? 0.5 : val.clamp(0.05, 0.95));
      }
      while (list.length < TasteVectorEngine.vectorDimension) {
        list.add(0.5);
      }
      return list.take(TasteVectorEngine.vectorDimension).toList();
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted taste vector', e);
      prefs.remove('noctra_taste_vector');
      return def;
    }
  }

  Future<void> completeOnboarding(
      {required List<String> languages,
      required List<String> genres,
      required List<String> artists}) {
    _hasCompletedOnboarding = true;
    _onboardedLanguages = languages;
    _onboardedGenres = genres;
    _onboardedArtists = artists;
    return _enqueuePrefsWrite(() async {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setBool('noctra_onboarded', true);
      await prefs.setStringList('noctra_onboarded_languages', languages);
      await prefs.setStringList('noctra_onboarded_genres', genres);
      await prefs.setStringList('noctra_onboarded_artists', artists);
    });
  }

  Future<void> recordManifest(Song song,
      {String action = 'play',
      int listenedSeconds = 0,
      double completionRate = 1.0}) async {
    await init();
    _manifestStore.recordManifest(song,
        action: action,
        listenedSeconds: listenedSeconds,
        completionRate: completionRate);
    // Persist through the same serialized queue so two rapid play records
    // cannot land out of order and lose a counter increment on disk.
    await _enqueuePrefsWrite(() => _manifestStore.persist());
  }

  List<String> getTopArtists({int limit = 6}) {
    final sorted = _manifestStore.artistWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final historyList = sorted
        .take(limit)
        .map((e) => e.key)
        .where((a) => a.isNotEmpty)
        .toList();
    return <String>{..._onboardedArtists, ...historyList}.take(limit).toList();
  }

  double getArtistAffinity(String artist) {
    if (artist.isEmpty || _manifestStore.artistWeights.isEmpty) return 0.0;
    final w = _manifestStore.artistWeights[artist] ?? 0;
    return (w / 10.0).clamp(0.0, 1.0);
  }

  List<String> getTopGenres({int limit = 4}) {
    final sorted = _manifestStore.genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final history = sorted
        .take(limit)
        .map((e) => e.key)
        .where((g) => g.isNotEmpty)
        .toList();
    return <String>{..._onboardedGenres, ...history}.take(limit).toList();
  }

  List<String> getTopLanguages({int limit = 3}) {
    final sorted = _manifestStore.languageWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final history = sorted
        .take(limit)
        .map((e) => e.key)
        .where((l) => l.isNotEmpty)
        .toList();
    return <String>{..._onboardedLanguages, ...history}.take(limit).toList();
  }

  Map<String, dynamic> getKnowledgeGraphSummary() => {
        'totalTracksLearned': _manifestStore.manifests.length,
        'topArtists': getTopArtists(limit: 4),
        'topGenres': getTopGenres(limit: 3),
        'topLanguages': getTopLanguages(limit: 2),
      };

  Future<void> saveThemeMode(String mode) {
    _cachedThemeMode = mode;
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_theme_mode', mode);
      } catch (e) {
        NoctraLogger.e('Failed to persist theme mode', e);
      }
    });
  }

  Future<void> savePlaybackPosition(Song? song, int positionMs) {
    if (song == null) return Future.value();
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        final payload =
            jsonEncode({'song': song.toMap(), 'positionMs': positionMs});
        await prefs.setString('noctra_last_playback', payload);
      } catch (e) {
        NoctraLogger.w('Failed to save playback position', e);
      }
    });
  }

  Future<Map<String, dynamic>?> loadPlaybackPosition() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final combined = prefs.getString('noctra_last_playback');
      if (combined != null) {
        final decoded = jsonDecode(combined) as Map<String, dynamic>;
        final songMap = decoded['song'] as Map<String, dynamic>?;
        if (songMap != null) {
          return {
            'song': Song.fromMap(songMap),
            'positionMs': (decoded['positionMs'] as num?)?.toInt() ?? 0
          };
        }
      }
      final songJson = prefs.getString('noctra_last_song');
      final posMs = prefs.getInt('noctra_last_pos_ms') ?? 0;
      if (songJson != null) {
        final decoded = jsonDecode(songJson);
        return {
          'song': Song.fromMap(Map<String, dynamic>.from(decoded)),
          'positionMs': posMs
        };
      }
    } catch (_) {}
    return null;
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

  Future<List<CatalogTopic>> loadCatalogTopics() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final raw = prefs.getString('noctra_catalog_topics');
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Expected List');
      return decoded
          .whereType<Map>()
          .map((item) => CatalogTopic(
                title: item['title']?.toString() ?? '',
                category: item['category']?.toString() ?? '',
                query: item['query']?.toString() ?? '',
              ))
          .where((topic) => topic.title.isNotEmpty && topic.query.isNotEmpty)
          .take(16)
          .toList(growable: false);
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted catalog topic cache', e);
      return const [];
    }
  }

  Future<void> saveCatalogTopics(List<CatalogTopic> topics) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString(
          'noctra_catalog_topics',
          jsonEncode(topics
              .take(16)
              .map((topic) => {
                    'title': topic.title,
                    'category': topic.category,
                    'query': topic.query,
                  })
              .toList()),
        );
      } catch (e) {
        NoctraLogger.w('Failed to persist catalog topics', e);
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
