import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../sources/noctra_local_database.dart';
import 'taste_vector_engine.dart';
import '../../services/ytdlp/music_service.dart';

class AIPlaylist {
  final String id, title, subtitle, artworkUrl, vibeKey;
  final List<Song> tracks;
  const AIPlaylist({required this.id, required this.title, required this.subtitle, required this.artworkUrl, required this.vibeKey, required this.tracks});
}

class VibeChip {
  final String keyName, label;
  final IconData iconData;
  const VibeChip({required this.keyName, required this.label, required this.iconData});
}

class MusicRepository extends ChangeNotifier {
  static final MusicRepository _instance = MusicRepository._internal();
  factory MusicRepository() => _instance;

  final List<Song> _localLibrary = [];
  final List<Song> _downloads = [];
  final List<Song> _favorites = [];
  final List<Song> _recentlyPlayed = [];
  final Map<String, List<Song>> _customFolders = {};
  List<double> _userTasteVector = TasteVectorEngine.getDefaultVector();

  List<Song> get localLibrary => List.unmodifiable(_localLibrary);
  List<Song> get downloads => List.unmodifiable(_downloads);
  List<Song> get favorites => List.unmodifiable(_favorites);
  List<Song> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  Map<String, List<Song>> get customFolders => Map.unmodifiable(_customFolders);
  List<double> get userTasteVector => List.unmodifiable(_userTasteVector);

  MusicRepository._internal() {
    _initDefaults();
    _loadFromDatabase();
  }

  Future<void> init() async => _loadFromDatabase();

  void _initDefaults() {
    _localLibrary.addAll([
      Song(id: 'loc_1', title: 'Starboy', artist: 'The Weeknd, Daft Punk', album: 'Starboy', artworkUrl: 'https://c.saavncdn.com/712/Starboy-English-2016-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/712/82aa1dcabcbddfa969e6bcf1231f6d3f_320.mp4', duration: const Duration(seconds: 230), genre: 'Synthwave', featureVector: [0.90, 0.2, 0.9, 0.4, 0.8, 0.1, 0.9, 0.3, 0.4, 0.95, 0.88, 0.2, 0.1, 0.3, 0.5, 0.9]),
      Song(id: 'loc_2', title: 'Blinding Lights', artist: 'The Weeknd', album: 'After Hours', artworkUrl: 'https://c.saavncdn.com/978/After-Hours-English-2020-20200319234012-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/978/db1a7c5c0caad1ea3f524bc0ae16cb6e_320.mp4', duration: const Duration(seconds: 200), genre: 'Synthwave', featureVector: [0.95, 0.1, 0.95, 0.3, 0.9, 0.1, 0.95, 0.4, 0.5, 0.98, 0.90, 0.2, 0.1, 0.4, 0.6, 0.95]),
      Song(id: 'loc_3', title: 'Midnight City', artist: 'M83', album: 'Hurry Up, We\'re Dreaming', artworkUrl: 'https://c.saavncdn.com/264/Hurry-Up-We-re-Dreaming-English-2011-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/264/0ce2a912bb0ef5d6ea72477c7f466b03_320.mp4', duration: const Duration(seconds: 243), genre: 'Indie Electro', featureVector: [0.85, 0.5, 0.8, 0.6, 0.85, 0.2, 0.75, 0.6, 0.4, 0.88, 0.80, 0.4, 0.2, 0.5, 0.7, 0.85]),
      Song(id: 'loc_4', title: 'Nightcall', artist: 'Kavinsky', album: 'OutRun', artworkUrl: 'https://c.saavncdn.com/580/Outrun-English-2013-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/580/28f645ea986b6a67f08ae2361661605f_320.mp4', duration: const Duration(seconds: 259), genre: 'Outrun Synth', featureVector: [0.99, 0.1, 0.7, 0.8, 0.95, 0.1, 0.6, 0.3, 0.2, 0.99, 0.95, 0.1, 0.1, 0.2, 0.4, 0.99]),
    ]);
  }

  Future<void> _loadFromDatabase() async {
    try {
      final db = NoctraLocalDatabase();
      final favs = await db.loadFavorites();
      _favorites.clear(); _favorites.addAll(favs);
      final downs = await db.loadDownloads();
      _downloads.clear(); _downloads.addAll(downs);
      final recents = await db.loadRecent();
      _recentlyPlayed.clear(); _recentlyPlayed.addAll(recents);
      final folders = await db.loadCustomFolders();
      _customFolders.clear(); _customFolders.addAll(folders);
      final tv = await db.loadTasteVector();
      if (tv != null && tv.length == 16) _userTasteVector = tv;
      notifyListeners();
    } catch (_) {}
  }

  void _persistState() {
    try {
      final db = NoctraLocalDatabase();
      db.saveFavorites(_favorites);
      db.saveDownloads(_downloads);
      db.saveRecent(_recentlyPlayed);
      db.saveCustomFolders(_customFolders);
      db.saveTasteVector(_userTasteVector);
    } catch (_) {}
  }

  String getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  bool isFavorite(String songId) => _favorites.any((s) => s.id == songId);

  void toggleFavorite(Song song) {
    if (isFavorite(song.id)) { _favorites.removeWhere((s) => s.id == song.id); } else { _favorites.insert(0, song); }
    _persistState(); notifyListeners();
  }

  void recordSongPlayed(Song song, {String action = 'play', int listenedSeconds = 0}) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 50) _recentlyPlayed.removeLast();
    
    // Record into Knowledge Graph Manifest for AI Agent learning
    NoctraLocalDatabase().recordManifest(song, action: action, listenedSeconds: listenedSeconds);
    updateTasteVector(song, action);
    _persistState(); notifyListeners();
  }

  void clearRecentlyPlayed() { _recentlyPlayed.clear(); _persistState(); notifyListeners(); }
  void removeRecentlyPlayed(String songId) { _recentlyPlayed.removeWhere((s) => s.id == songId); _persistState(); notifyListeners(); }

  void addDownloadedSong(Song song) {
    _downloads.removeWhere((s) => s.id == song.id);
    _downloads.insert(0, song);
    _persistState(); notifyListeners();
  }

  void updateTasteVector(Song song, String action) {
    _userTasteVector = TasteVectorEngine.updateVector(
      current: _userTasteVector,
      songVector: song.featureVector,
      action: action,
    );
    _persistState(); notifyListeners();
  }

  int computeMatchScore(Song song) {
    final sim = TasteVectorEngine.cosineSimilarity(song.featureVector, _userTasteVector);
    final historyAffinity = NoctraLocalDatabase().getArtistAffinity(song.artist);
    return (76 + (sim * 18) + (historyAffinity * 5)).round().clamp(75, 99);
  }

  List<AIPlaylist> getSmartAIPlaylists() {
    return [
      AIPlaylist(id: 'ai_1', title: 'Obsidian Noir Mix', subtitle: 'Late Night Focus • 98% Taste Resonance', artworkUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500', vibeKey: 'noir_night', tracks: _localLibrary),
      AIPlaylist(id: 'ai_2', title: 'Midnight Velocity', subtitle: 'Synthwave & Outrun Drive • AI Curated', artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500', vibeKey: 'retro_synth', tracks: _localLibrary),
      AIPlaylist(id: 'ai_3', title: 'Kinetic Wave Mix', subtitle: 'High Velocity • Peak Energy Pulse', artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500', vibeKey: 'high_energy', tracks: _localLibrary),
      AIPlaylist(id: 'ai_4', title: 'Deep Cuts & Discoveries', subtitle: 'Acoustic Warmth • 16-Axis Neural Picks', artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500', vibeKey: 'acoustic_warm', tracks: _localLibrary),
    ];
  }

  List<AIPlaylist> getAIGeneratedPlaylists() => getSmartAIPlaylists();

  List<VibeChip> getDynamicVibeChips() {
    return const [
      VibeChip(keyName: 'noir_night', label: 'Noir Night', iconData: Icons.nightlight_round),
      VibeChip(keyName: 'retro_synth', label: 'Synthwave', iconData: Icons.grid_goldenratio_rounded),
      VibeChip(keyName: 'deep_focus', label: 'Deep Focus', iconData: Icons.psychology_rounded),
      VibeChip(keyName: 'high_energy', label: 'High Energy', iconData: Icons.bolt_rounded),
      VibeChip(keyName: 'ambient_chill', label: 'Ambient Chill', iconData: Icons.spa_rounded),
    ];
  }

  String getUserMusicalArchetype() => TasteVectorEngine.calculateArchetype(_userTasteVector);

  List<Map<String, dynamic>> getDominantAxes() {
    final List<MapEntry<String, double>> pairs = [];
    for (int i = 0; i < TasteVectorEngine.axisNames.length && i < _userTasteVector.length; i++) {
      pairs.add(MapEntry(TasteVectorEngine.axisNames[i], _userTasteVector[i]));
    }
    pairs.sort((a, b) => b.value.compareTo(a.value));
    return pairs.take(4).map((e) => {'name': e.key, 'percentage': (e.value * 100).toInt(), 'weight': e.value}).toList();
  }

  List<Map<String, dynamic>> curateByVibe({String? vibeKey, String? naturalPrompt}) {
    final target = TasteVectorEngine.getTargetVector(vibeKey: vibeKey, prompt: naturalPrompt, defaultTaste: _userTasteVector);
    final candidates = {..._localLibrary, ..._downloads, ..._recentlyPlayed}.toList();
    if (candidates.isEmpty) candidates.addAll(_localLibrary);

    final scored = candidates.map((s) {
      final sim = TasteVectorEngine.cosineSimilarity(s.featureVector, target);
      final score = (78 + sim * 21).round().clamp(75, 99);
      final exp = TasteVectorEngine.generateExplanation(s, score, vibeKey, naturalPrompt);
      return {'song': s, 'score': score, 'explanation': exp};
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.take(12).toList();
  }

  Future<List<Map<String, dynamic>>> curateWithAIAgent({required String prompt, String? vibeKey}) async {
    final cleanPrompt = prompt.trim();
    var searched = await MusicService.search(cleanPrompt);
    if (searched.length < 5) {
      final expanded = await MusicService.search('$cleanPrompt chill acoustic vibes');
      searched = {...searched, ...expanded}.toList();
    }
    final target = TasteVectorEngine.getTargetVector(vibeKey: vibeKey, prompt: cleanPrompt, defaultTaste: _userTasteVector);
    final candidates = searched.isNotEmpty ? searched : {..._localLibrary, ..._downloads, ..._recentlyPlayed}.toList();

    final scored = candidates.map((s) {
      final songEmbedding = s.featureVector.every((x) => x == 0.5)
          ? TasteVectorEngine.extractSongEmbedding(s)
          : s.featureVector;
      final sim = TasteVectorEngine.cosineSimilarity(songEmbedding, target);
      final score = (80 + sim * 19).round().clamp(75, 99);
      final exp = TasteVectorEngine.generateExplanation(s, score, vibeKey, cleanPrompt);
      return {'song': s, 'score': score, 'explanation': exp};
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.take(15).toList();
  }

  Future<List<Song>> generateAIRadioForSong(Song seed) async {
    try {
      final results = await MusicService.search('${seed.artist} ${seed.title}');
      if (results.isNotEmpty) {
        final unique = results.where((s) => s.id != seed.id).toList();
        return [seed, ...unique];
      }
    } catch (_) {}
    return MusicService.fetchVibeFeed('late_night');
  }

  void createFolder(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty && !_customFolders.containsKey(clean)) {
      _customFolders[clean] = []; _persistState(); notifyListeners();
    }
  }

  void addSongToFolder(String folderName, Song song) {
    if (_customFolders.containsKey(folderName)) {
      final list = _customFolders[folderName]!;
      if (!list.any((s) => s.id == song.id)) { list.add(song); _persistState(); notifyListeners(); }
    }
  }

  void removeSongFromFolder(String folderName, String songId) {
    if (_customFolders.containsKey(folderName)) {
      _customFolders[folderName]!.removeWhere((s) => s.id == songId);
      _persistState(); notifyListeners();
    }
  }
}
