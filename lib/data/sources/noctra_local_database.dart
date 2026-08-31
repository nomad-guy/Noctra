import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/noctra_logger.dart';
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

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  List<String> get onboardedArtists => List.unmodifiable(_onboardedArtists);
  List<String> get onboardedGenres => List.unmodifiable(_onboardedGenres);
  List<String> get onboardedLanguages => List.unmodifiable(_onboardedLanguages);
  String getCachedThemeMode() => _cachedThemeMode;

  /// Persists the active theme so it survives app restarts.
  Future<void> saveCachedThemeMode(String modeName) => saveThemeMode(modeName);

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
      _onboardedLanguages = prefs.getStringList('noctra_onboarded_languages') ?? [];

      _favorites.clear();
      _favorites.addAll(_safeDecodeSongList(prefs.getString('noctra_favs'), 'noctra_favs', prefs));
      _downloads.clear();
      _downloads.addAll(_safeDecodeSongList(prefs.getString('noctra_downloads'), 'noctra_downloads', prefs));
      _recent.clear();
      _recent.addAll(_safeDecodeSongList(prefs.getString('noctra_recent'), 'noctra_recent', prefs));
      _customFolders.clear();
      _customFolders.addAll(_safeDecodeCustomFolders(prefs.getString('noctra_custom_folders'), prefs));
      _cachedTasteVector = _safeDecodeTasteVector(prefs.getString('noctra_taste_vector'), prefs);
      _cachedThemeMode = prefs.getString('noctra_theme_mode') ?? 'noirBlack';

      final kgStr = prefs.getString('noctra_kg_manifests');
      if (kgStr != null) {
        try {
          _manifestStore.loadFromRawMap(jsonDecode(kgStr) as Map<String, dynamic>);
        } catch (e) {
          NoctraLogger.w('Self-healing manifests knowledge graph', e);
          prefs.remove('noctra_kg_manifests');
        }
      }
      _isLoaded = true;
    } catch (e) {
      NoctraLogger.e('Database initialization failed; will retry on next access', e);
      // Reset in-memory state and keep _isLoaded false so subsequent calls can retry
      _favorites.clear();
      _downloads.clear();
      _recent.clear();
      _customFolders.clear();
      _cachedTasteVector = null;
      _isLoaded = false;
    }
  }

  List<Song> _safeDecodeSongList(String? jsonStr, String key, SharedPreferences prefs) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) throw const FormatException('Expected List');
      final seen = <String>{};
      final list = <Song>[];
      for (final item in decoded) {
        if (item is Map) {
          final song = Song.fromMap(Map<String, dynamic>.from(item));
          if (song.title.isEmpty) continue;
          final effectiveId = song.id.isNotEmpty ? song.id : 'syn_${song.title.hashCode ^ song.artist.hashCode}';
          final dedupSong = song.id.isEmpty ? song.copyWith(id: effectiveId) : song;
          if (seen.add(effectiveId)) list.add(dedupSong);
        }
      }
      return list;
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted list for key $key', e);
      prefs.remove(key);
      return [];
    }
  }

  Map<String, List<Song>> _safeDecodeCustomFolders(String? jsonStr, SharedPreferences prefs) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) throw const FormatException('Expected Map');
      final res = <String, List<Song>>{};
      int syntheticId = 0;
      decoded.forEach((rawK, v) {
        final k = rawK?.toString();
        if (k != null && k.isNotEmpty && v is List) {
          final seen = <String>{};
          final songs = <Song>[];
          for (final item in v) {
            if (item is Map) {
              final song = Song.fromMap(Map<String, dynamic>.from(item));
              if (song.title.isEmpty) continue;
              final effectiveId = song.id.isNotEmpty ? song.id : 'syn_f_${song.title.hashCode}_${syntheticId++}';
              final dedupSong = song.id.isEmpty ? song.copyWith(id: effectiveId) : song;
              if (seen.add(effectiveId)) songs.add(dedupSong);
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

  List<double> _safeDecodeTasteVector(String? jsonStr, SharedPreferences prefs) {
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
      while (list.length < TasteVectorEngine.vectorDimension) { list.add(0.5); }
      return list.take(TasteVectorEngine.vectorDimension).toList();
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted taste vector', e);
      prefs.remove('noctra_taste_vector');
      return def;
    }
  }

  Future<void> completeOnboarding({required List<String> languages, required List<String> genres, required List<String> artists}) async {
    _hasCompletedOnboarding = true;
    _onboardedLanguages = languages;
    _onboardedGenres = genres;
    _onboardedArtists = artists;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool('noctra_onboarded', true);
    await prefs.setStringList('noctra_onboarded_languages', languages);
    await prefs.setStringList('noctra_onboarded_genres', genres);
    await prefs.setStringList('noctra_onboarded_artists', artists);
  }

  Future<void> recordManifest(Song song, {String action = 'play', int listenedSeconds = 0, double completionRate = 1.0}) async {
    await init();
    _manifestStore.recordManifest(song, action: action, listenedSeconds: listenedSeconds, completionRate: completionRate);
    await _manifestStore.persist();
  }

  List<String> getTopArtists({int limit = 6}) {
    final sorted = _manifestStore.artistWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final historyList = sorted.take(limit).map((e) => e.key).where((a) => a.isNotEmpty).toList();
    return <String>{..._onboardedArtists, ...historyList}.take(limit).toList();
  }

  double getArtistAffinity(String artist) {
    if (artist.isEmpty || _manifestStore.artistWeights.isEmpty) return 0.0;
    final w = _manifestStore.artistWeights[artist] ?? 0;
    return (w / 10.0).clamp(0.0, 1.0);
  }

  List<String> getTopGenres({int limit = 4}) {
    final sorted = _manifestStore.genreWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final history = sorted.take(limit).map((e) => e.key).where((g) => g.isNotEmpty).toList();
    return <String>{..._onboardedGenres, ...history}.take(limit).toList();
  }

  List<String> getTopLanguages({int limit = 3}) {
    final sorted = _manifestStore.languageWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final history = sorted.take(limit).map((e) => e.key).where((l) => l.isNotEmpty).toList();
    return <String>{..._onboardedLanguages, ...history}.take(limit).toList();
  }

  Map<String, dynamic> getKnowledgeGraphSummary() => {
    'totalTracksLearned': _manifestStore.manifests.length,
    'topArtists': getTopArtists(limit: 4),
    'topGenres': getTopGenres(limit: 3),
    'topLanguages': getTopLanguages(limit: 2),
  };

  Future<void> saveThemeMode(String mode) async {
    _cachedThemeMode = mode;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString('noctra_theme_mode', mode);
    } catch (e) {
      NoctraLogger.e('Failed to persist theme mode', e);
    }
  }

  Future<void> savePlaybackPosition(Song? song, int positionMs) async {
    if (song == null) return;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final payload = jsonEncode({'song': song.toMap(), 'positionMs': positionMs});
      await prefs.setString('noctra_last_playback', payload);
    } catch (_) {}
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
          return {'song': Song.fromMap(songMap), 'positionMs': (decoded['positionMs'] as num?)?.toInt() ?? 0};
        }
      }
      final songJson = prefs.getString('noctra_last_song');
      final posMs = prefs.getInt('noctra_last_pos_ms') ?? 0;
      if (songJson != null) {
        final decoded = jsonDecode(songJson);
        return {'song': Song.fromMap(Map<String, dynamic>.from(decoded)), 'positionMs': posMs};
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveFavorites(List<Song> songs) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('noctra_favs', jsonEncode(songs.map((e) => e.toMap()).toList()));
    _favorites.clear();
    _favorites.addAll(songs);
  }

  Future<void> saveDownloads(List<Song> songs) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('noctra_downloads', jsonEncode(songs.map((e) => e.toMap()).toList()));
    _downloads.clear();
    _downloads.addAll(songs);
  }

  Future<void> saveRecent(List<Song> songs) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('noctra_recent', jsonEncode(songs.take(50).map((e) => e.toMap()).toList()));
    _recent.clear();
    _recent.addAll(songs);
  }

  Future<void> saveCustomFolders(Map<String, List<Song>> folders) async {
    _customFolders.clear(); _customFolders.addAll(folders);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final map = <String, dynamic>{};
    folders.forEach((k, v) => map[k] = v.map((s) => s.toMap()).toList());
    await prefs.setString('noctra_custom_folders', jsonEncode(map));
  }

  Future<void> saveTasteVector(List<double> vector) async {
    _cachedTasteVector = vector;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('noctra_taste_vector', jsonEncode(vector));
  }

  Future<List<Song>> loadFavorites() async { await init(); return List<Song>.unmodifiable(_favorites); }
  Future<List<Song>> loadDownloads() async { await init(); return List<Song>.unmodifiable(_downloads); }
  Future<List<Song>> loadRecent() async { await init(); return List<Song>.unmodifiable(_recent); }
  Future<Map<String, List<Song>>> loadCustomFolders() async { await init(); return Map<String, List<Song>>.unmodifiable(_customFolders); }
  Future<List<double>?> loadTasteVector() async { await init(); return _cachedTasteVector != null ? List<double>.unmodifiable(_cachedTasteVector!) : null; }
}
