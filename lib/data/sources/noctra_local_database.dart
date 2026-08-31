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
  String _cachedThemeMode = 'dark';
  SharedPreferences? _prefs;
  bool _hasCompletedOnboarding = false;
  List<String> _onboardedArtists = [];
  List<String> _onboardedGenres = [];
  List<String> _onboardedLanguages = [];
  bool _isLoaded = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  List<String> get onboardedArtists => List.unmodifiable(_onboardedArtists);
  List<String> get onboardedGenres => List.unmodifiable(_onboardedGenres);
  List<String> get onboardedLanguages => List.unmodifiable(_onboardedLanguages);
  String getCachedThemeMode() => _cachedThemeMode;

  Future<void> init() async {
    if (_isLoaded) return;
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
      _cachedThemeMode = prefs.getString('noctra_theme_mode') ?? 'dark';

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
      NoctraLogger.e('Database initialization self-healed', e);
      _isLoaded = true;
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
          if (song.id.isNotEmpty && song.title.isNotEmpty && seen.add(song.id)) list.add(song);
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
      decoded.forEach((k, v) {
        if (k is String && v is List) {
          final songs = <Song>[];
          for (final item in v) { if (item is Map) songs.add(Song.fromMap(Map<String, dynamic>.from(item))); }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noctra_onboarded', true);
    await prefs.setStringList('noctra_onboarded_languages', languages);
    await prefs.setStringList('noctra_onboarded_genres', genres);
    await prefs.setStringList('noctra_onboarded_artists', artists);
  }

  Future<void> recordManifest(Song song, {String action = 'play', int listenedSeconds = 0, double completionRate = 1.0}) async {
    await init();
    _manifestStore.recordManifest(song, action: action, listenedSeconds: listenedSeconds, completionRate: completionRate);
    _manifestStore.persist();
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
    // Write synchronously first via cached prefs instance to survive force-kills
    // on OEM Android skins (ColorOS, MIUI) that ignore DONT_KILL_APP.
    final p = _prefs;
    if (p != null) {
      p.setString('noctra_theme_mode', mode);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString('noctra_theme_mode', mode);
    } catch (e) { NoctraLogger.e('Failed to persist theme mode', e); }
  }

  Future<void> savePlaybackPosition(Song? song, int positionMs) async {
    if (song == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('noctra_last_song', jsonEncode(song.toMap()));
      await prefs.setInt('noctra_last_pos_ms', positionMs);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadPlaybackPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
    _favorites.clear(); _favorites.addAll(songs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noctra_favs', jsonEncode(songs.map((e) => e.toMap()).toList()));
  }

  Future<void> saveDownloads(List<Song> songs) async {
    _downloads.clear(); _downloads.addAll(songs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noctra_downloads', jsonEncode(songs.map((e) => e.toMap()).toList()));
  }

  Future<void> saveRecent(List<Song> songs) async {
    _recent.clear(); _recent.addAll(songs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noctra_recent', jsonEncode(songs.take(50).map((e) => e.toMap()).toList()));
  }

  Future<void> saveCustomFolders(Map<String, List<Song>> folders) async {
    _customFolders.clear(); _customFolders.addAll(folders);
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    folders.forEach((k, v) => map[k] = v.map((s) => s.toMap()).toList());
    await prefs.setString('noctra_custom_folders', jsonEncode(map));
  }

  Future<void> saveTasteVector(List<double> vector) async {
    _cachedTasteVector = vector;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noctra_taste_vector', jsonEncode(vector));
  }

  Future<List<Song>> loadFavorites() async { await init(); return _favorites; }
  Future<List<Song>> loadDownloads() async { await init(); return _downloads; }
  Future<List<Song>> loadRecent() async { await init(); return _recent; }
  Future<Map<String, List<Song>>> loadCustomFolders() async { await init(); return _customFolders; }
  Future<List<double>?> loadTasteVector() async { await init(); return _cachedTasteVector; }
}
