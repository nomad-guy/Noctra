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
  List<double> _cachedTasteVector = List.unmodifiable(TasteVectorEngine.getDefaultVector());

  List<Song> get localLibrary => List.unmodifiable(_localLibrary);
  List<Song> get downloads => List.unmodifiable(_downloads);
  List<Song> get favorites => List.unmodifiable(_favorites);
  List<Song> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  Map<String, List<Song>> get customFolders => Map.unmodifiable(_customFolders);
  List<double> get userTasteVector => _cachedTasteVector;

  MusicRepository._internal();

  Future<void> init() async => _loadFromDatabase();

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
      if (tv != null && tv.length == TasteVectorEngine.vectorDimension) {
        _userTasteVector = tv;
        _cachedTasteVector = List.unmodifiable(_userTasteVector);
      }
      notifyListeners();
    } catch (_) {}
  }

  void initOnboardingTaste({required List<String> languages, required List<String> genres, required List<String> artists}) {
    final text = '${languages.join(' ')} ${genres.join(' ')} ${artists.join(' ')}';
    final customSeed = Song(id: 'onboarding', title: text, artist: artists.join(' '), album: '', artworkUrl: '', streamUrl: '', duration: Duration.zero);
    final vec = TasteVectorEngine.extractSongEmbedding(customSeed);
    _userTasteVector = vec;
    _cachedTasteVector = List.unmodifiable(_userTasteVector);
    _persistState();
    notifyListeners();
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
    NoctraLocalDatabase().saveFavorites(_favorites);
    notifyListeners();
  }

  void recordSongPlayed(Song song, {String action = 'play', int listenedSeconds = 0}) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 50) _recentlyPlayed.removeLast();
    
    NoctraLocalDatabase().recordManifest(song, action: action, listenedSeconds: listenedSeconds);
    NoctraLocalDatabase().saveRecent(_recentlyPlayed);
    updateTasteVector(song, action);
    notifyListeners();
  }

  void clearRecentlyPlayed() { _recentlyPlayed.clear(); NoctraLocalDatabase().saveRecent(_recentlyPlayed); notifyListeners(); }
  void removeRecentlyPlayed(String songId) { _recentlyPlayed.removeWhere((s) => s.id == songId); NoctraLocalDatabase().saveRecent(_recentlyPlayed); notifyListeners(); }

  void addDownloadedSong(Song song) {
    _downloads.removeWhere((s) => s.id == song.id);
    _downloads.insert(0, song);
    NoctraLocalDatabase().saveDownloads(_downloads);
    notifyListeners();
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
    final songEmbedding = song.featureVector.every((x) => x == 0.5)
        ? TasteVectorEngine.extractSongEmbedding(song)
        : song.featureVector;
    final sim = TasteVectorEngine.cosineSimilarity(songEmbedding, _userTasteVector);
    final historyAffinity = NoctraLocalDatabase().getArtistAffinity(song.artist);
    return ((sim * 80) + (historyAffinity * 19)).round().clamp(60, 99);
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
      final songEmbedding = s.featureVector.every((x) => x == 0.5) ? TasteVectorEngine.extractSongEmbedding(s) : s.featureVector;
      final sim = TasteVectorEngine.cosineSimilarity(songEmbedding, target);
      final score = ((sim * 80) + 19).round().clamp(60, 99);
      final exp = TasteVectorEngine.generateExplanation(s, score, vibeKey, naturalPrompt);
      return {'song': s, 'score': score, 'matchPercentage': score, 'explanation': exp};
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.take(12).toList();
  }

  Future<List<Map<String, dynamic>>> curateWithAIAgent({required String prompt, String? vibeKey}) async {
    final cleanPrompt = prompt.trim();
    var searched = await MusicService.search(cleanPrompt);
    if (searched.length < 5) {
      final expanded = await MusicService.search('$cleanPrompt chill acoustic vibes');
      searched = <Song>{...searched, ...expanded}.toList();
    }
    final target = TasteVectorEngine.getTargetVector(vibeKey: vibeKey, prompt: cleanPrompt, defaultTaste: _userTasteVector);
    final candidates = searched.isNotEmpty ? searched : {..._localLibrary, ..._downloads, ..._recentlyPlayed}.toList();

    final scored = candidates.map((s) {
      final songEmbedding = s.featureVector.every((x) => x == 0.5)
          ? TasteVectorEngine.extractSongEmbedding(s)
          : s.featureVector;
      final sim = TasteVectorEngine.cosineSimilarity(songEmbedding, target);
      final score = ((sim * 80) + 19).round().clamp(60, 99);
      final exp = TasteVectorEngine.generateExplanation(s, score, vibeKey, cleanPrompt);
      return {'song': s, 'score': score, 'matchPercentage': score, 'explanation': exp};
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
      final artistFeed = await MusicService.search('${seed.artist} best songs');
      if (artistFeed.isNotEmpty) return [seed, ...artistFeed.where((s) => s.id != seed.id)];
    } catch (_) {}
    return [seed, ..._localLibrary.where((s) => s.id != seed.id)];
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

  void deleteFolder(String folderName) {
    if (folderName != 'Favorites' && _customFolders.containsKey(folderName)) {
      _customFolders.remove(folderName);
      _persistState();
      notifyListeners();
    }
  }
}
