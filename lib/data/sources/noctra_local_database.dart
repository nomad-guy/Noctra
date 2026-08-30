import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

class SongManifest {
  final String songId;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String language;
  final int playCount;
  final int skipCount;
  final int totalListenSeconds;
  final double completionRate;
  final int lastPlayedTimestamp;
  final List<double> featureVector;

  const SongManifest({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.language,
    required this.playCount,
    required this.skipCount,
    required this.totalListenSeconds,
    required this.completionRate,
    required this.lastPlayedTimestamp,
    required this.featureVector,
  });

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'language': language,
        'playCount': playCount,
        'skipCount': skipCount,
        'totalListenSeconds': totalListenSeconds,
        'completionRate': completionRate,
        'lastPlayedTimestamp': lastPlayedTimestamp,
        'featureVector': featureVector,
      };

  factory SongManifest.fromMap(Map<String, dynamic> map) => SongManifest(
        songId: map['songId'] ?? '',
        title: map['title'] ?? '',
        artist: map['artist'] ?? '',
        album: map['album'] ?? '',
        genre: map['genre'] ?? 'Music',
        language: map['language'] ?? 'English',
        playCount: (map['playCount'] as num?)?.toInt() ?? 0,
        skipCount: (map['skipCount'] as num?)?.toInt() ?? 0,
        totalListenSeconds: (map['totalListenSeconds'] as num?)?.toInt() ?? 0,
        completionRate: (map['completionRate'] as num?)?.toDouble() ?? 1.0,
        lastPlayedTimestamp: (map['lastPlayedTimestamp'] as num?)?.toInt() ?? 0,
        featureVector: (map['featureVector'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? List.filled(16, 0.5),
      );
}

class NoctraLocalDatabase {
  static final NoctraLocalDatabase _instance = NoctraLocalDatabase._internal();
  factory NoctraLocalDatabase() => _instance;
  NoctraLocalDatabase._internal();

  final Map<String, SongManifest> _manifests = {};
  final Map<String, int> _artistWeights = {};
  final Map<String, int> _genreWeights = {};
  final Map<String, int> _languageWeights = {};
  final List<Song> _favorites = [];
  final List<Song> _downloads = [];
  final List<Song> _recent = [];
  final Map<String, List<Song>> _customFolders = {};
  List<double> _cachedTasteVector = List.filled(16, 0.5);
  String _cachedThemeMode = 'noirBlack';
  bool _isLoaded = false;

  String getCachedThemeMode() => _cachedThemeMode;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedThemeMode = prefs.getString('noctra_theme_mode') ?? 'noirBlack';

      final rawManifests = prefs.getString('noctra_kg_manifests');
      if (rawManifests != null) {
        final decoded = jsonDecode(rawManifests) as Map<String, dynamic>?;
        decoded?.forEach((k, v) {
          final m = SongManifest.fromMap(Map<String, dynamic>.from(v));
          _manifests[k] = m;
          _artistWeights[m.artist] = (_artistWeights[m.artist] ?? 0) + m.playCount;
          _genreWeights[m.genre] = (_genreWeights[m.genre] ?? 0) + m.playCount;
          _languageWeights[m.language] = (_languageWeights[m.language] ?? 0) + m.playCount;
        });
      }

      final rawFavs = prefs.getString('noctra_favs');
      if (rawFavs != null) {
        final list = jsonDecode(rawFavs) as List?;
        _favorites.clear();
        list?.forEach((item) => _favorites.add(Song.fromMap(Map<String, dynamic>.from(item))));
      }

      final rawDowns = prefs.getString('noctra_downloads');
      if (rawDowns != null) {
        final list = jsonDecode(rawDowns) as List?;
        _downloads.clear();
        list?.forEach((item) => _downloads.add(Song.fromMap(Map<String, dynamic>.from(item))));
      }

      final rawRecent = prefs.getString('noctra_recent');
      if (rawRecent != null) {
        final list = jsonDecode(rawRecent) as List?;
        _recent.clear();
        list?.forEach((item) => _recent.add(Song.fromMap(Map<String, dynamic>.from(item))));
      }

      final rawFolders = prefs.getString('noctra_custom_folders');
      if (rawFolders != null) {
        final map = jsonDecode(rawFolders) as Map<String, dynamic>?;
        _customFolders.clear();
        map?.forEach((k, v) {
          final sList = (v as List).map((s) => Song.fromMap(Map<String, dynamic>.from(s))).toList();
          _customFolders[k] = sList;
        });
      }

      final rawTv = prefs.getString('noctra_taste_vector');
      if (rawTv != null) {
        final list = jsonDecode(rawTv) as List?;
        if (list != null && list.length == 16) {
          _cachedTasteVector = list.map((e) => (e as num).toDouble()).toList();
        }
      }

      _isLoaded = true;
    } catch (_) {}
  }

  Future<void> recordManifest(Song song, {String action = 'play', int listenedSeconds = 0, double completionRate = 1.0}) async {
    await init();
    final existing = _manifests[song.id];
    final plays = (existing?.playCount ?? 0) + (action == 'skip' ? 0 : 1);
    final skips = (existing?.skipCount ?? 0) + (action == 'skip' ? 1 : 0);
    final totalSec = (existing?.totalListenSeconds ?? 0) + listenedSeconds;

    String inferredLang = 'English';
    final lTitle = song.title.toLowerCase();
    final lArtist = song.artist.toLowerCase();
    if (lTitle.contains('tum') || lTitle.contains('dil') || lArtist.contains('arijit') || lArtist.contains('pritam') || lTitle.contains('pyaar')) {
      inferredLang = 'Hindi';
    } else if (lTitle.contains('jatt') || lArtist.contains('sidhu') || lArtist.contains('diljit') || lTitle.contains('punjabi')) {
      inferredLang = 'Punjabi';
    }

    final updated = SongManifest(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      genre: song.genre ?? 'Music',
      language: inferredLang,
      playCount: plays,
      skipCount: skips,
      totalListenSeconds: totalSec,
      completionRate: completionRate,
      lastPlayedTimestamp: DateTime.now().millisecondsSinceEpoch,
      featureVector: song.featureVector,
    );

    _manifests[song.id] = updated;
    _artistWeights[song.artist] = (_artistWeights[song.artist] ?? 0) + 1;
    _genreWeights[updated.genre] = (_genreWeights[updated.genre] ?? 0) + 1;
    _languageWeights[inferredLang] = (_languageWeights[inferredLang] ?? 0) + 1;

    _persistManifests();
  }

  void _persistManifests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      _manifests.forEach((k, v) => map[k] = v.toMap());
      await prefs.setString('noctra_kg_manifests', jsonEncode(map));
    } catch (_) {}
  }

  List<String> getTopArtists({int limit = 6}) {
    final sorted = _artistWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).where((a) => a.isNotEmpty).toList();
  }

  List<String> getTopGenres({int limit = 4}) {
    final sorted = _genreWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).where((g) => g.isNotEmpty).toList();
  }

  List<String> getTopLanguages({int limit = 3}) {
    final sorted = _languageWeights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).where((l) => l.isNotEmpty).toList();
  }

  Map<String, dynamic> getKnowledgeGraphSummary() {
    return {
      'totalTracksLearned': _manifests.length,
      'topArtists': getTopArtists(limit: 4),
      'topGenres': getTopGenres(limit: 3),
      'topLanguages': getTopLanguages(limit: 2),
    };
  }

  Future<void> saveThemeMode(String mode) async {
    _cachedThemeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noctra_theme_mode', mode);
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
        final song = Song.fromMap(Map<String, dynamic>.from(decoded));
        return {'song': song, 'positionMs': posMs};
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
    await prefs.setString('noctra_recent', jsonEncode(songs.take(40).map((e) => e.toMap()).toList()));
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
