import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../models/ai_folder_model.dart';
import '../sources/noctra_local_database.dart';
import 'taste_vector_engine.dart';
import '../../services/ytdlp/music_service.dart';
import '../../core/utils/noctra_localization.dart';

class AIPlaylist {
  final String id, title, subtitle, artworkUrl, vibeKey;
  final List<Song> tracks;
  const AIPlaylist({required this.id, required this.title, required this.subtitle, required this.artworkUrl, required this.vibeKey, this.tracks = const []});
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

  bool _isLoaded = false;
  Future<void>? _initFuture;

  MusicRepository._internal();

  Future<void> init() async {
    if (_isLoaded) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _loadFromDatabase();
    await _initFuture;
    _initFuture = null;
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
      if (tv != null && tv.length == TasteVectorEngine.vectorDimension) {
        _userTasteVector = tv;
        _cachedTasteVector = List.unmodifiable(_userTasteVector);
      }
      _isLoaded = true;
    } catch (_) {
      _isLoaded = true;
    }
    // Always notify listeners — even on partial failure — so widgets
    // don't remain stuck on stale default state.
    notifyListeners();
  }

  void initOnboardingTaste({required List<String> languages, required List<String> genres, required List<String> artists}) {
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
    if (hour < 12) return NoctraLocalization.tr('good_morning');
    if (hour < 17) return NoctraLocalization.tr('good_afternoon');
    return NoctraLocalization.tr('good_evening');
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
    return ((sim * 80) + (historyAffinity * 19)).round().clamp(10, 99);
  }

  List<String> getTopArtists({int limit = 5}) => NoctraLocalDatabase().getTopArtists(limit: limit);

  List<AIPlaylist> getSmartAIPlaylists() => getAIGeneratedPlaylists();
  List<AIPlaylist> getAIGeneratedPlaylists() => _buildAIPlaylists();

  // Build deduplicated seed track pool from all available sources.
  // Used as initial tracks for AI mix cards before live recommendations load.
  List<Song> _seedTrackPool() {
    final seen = <String>{};
    final pool = <Song>[];
    for (final src in [_favorites, _downloads, _recentlyPlayed]) {
      for (final s in src) {
        if (seen.add(s.id)) pool.add(s);
      }
    }
    return pool;
  }

  List<AIPlaylist> _buildAIPlaylists() {
    final v = _userTasteVector;
    final playlists = <AIPlaylist>[];
    final pool = _seedTrackPool();

    // Always include a "For You Today" mix
    playlists.add(AIPlaylist(
      id: 'ai_for_you',
      title: 'For You Today',
      subtitle: 'Personalized mix based on your taste',
      artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      vibeKey: 'late_night',
      tracks: pool,
    ));

    if (v.length > 10 && v[10] >= 0.60) {
      playlists.add(AIPlaylist(id: 'ai_late_night', title: 'Late Night Drive',
        subtitle: 'Dark atmosphere for the night hours',
        artworkUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        vibeKey: 'noir_night', tracks: pool));
    }
    if (v.length > 9 && v[9] >= 0.60) {
      playlists.add(AIPlaylist(id: 'ai_retro', title: 'Retro Synth Session',
        subtitle: 'Analog warmth and synthwave energy',
        artworkUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500',
        vibeKey: 'retro_synth', tracks: pool));
    }
    if (v.length > 2 && v[2] >= 0.65) {
      playlists.add(AIPlaylist(id: 'ai_energy', title: 'High Energy',
        subtitle: 'Kinetic tracks to keep you moving',
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
        vibeKey: 'high_energy', tracks: pool));
    }
    if (v.length > 19 && v[19] >= 0.60) {
      playlists.add(AIPlaylist(id: 'ai_bollywood', title: 'Desi Vibes',
        subtitle: 'Bollywood and South Asian favorites',
        artworkUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500',
        vibeKey: 'bollywood', tracks: pool));
    }
    if (v.length > 3 && v[3] >= 0.65) {
      playlists.add(AIPlaylist(id: 'ai_chill', title: 'Chill & Unwind',
        subtitle: 'Calm tracks for easy listening',
        artworkUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500',
        vibeKey: 'ambient_chill', tracks: pool));
    }

    // New Discoveries: always included
    playlists.add(AIPlaylist(
      id: 'ai_discovery',
      title: 'New Discoveries',
      subtitle: 'Fresh tracks outside your usual rotation',
      artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500',
      vibeKey: 'discovery',
      tracks: pool,
    ));

    return playlists;
  }

  // Dynamic AI curated folders based on user taste evidence
  List<AIFolder> getAICuratedFolders() {
    final v = _userTasteVector;
    final folders = <AIFolder>[];
    // Top artists data available via NoctraLocalDatabase().getTopArtists()
    final recentCount = _recentlyPlayed.length;

    // Heavy Rotation: songs replayed often (proxy: recent play count > 10)
    if (recentCount >= 10) {
      folders.add(AIFolder(
        id: 'folder_rotation', name: 'Heavy Rotation',
        description: 'Songs you keep coming back to',
        vibeKey: 'late_night', icon: Icons.repeat_rounded, trackCount: recentCount.clamp(5, 30),
      ));
    }
    if (v.length > 10 && v[10] >= 0.62) {
      folders.add(AIFolder(
        id: 'folder_night', name: 'Late Night',
        description: 'Dark and atmospheric for quiet hours',
        vibeKey: 'noir_night', icon: Icons.nightlight_round, trackCount: 15,
      ));
    }
    if (v.length > 19 && v[19] >= 0.62) {
      folders.add(AIFolder(
        id: 'folder_bollywood', name: 'Bollywood Favorites',
        description: 'Your top Bollywood and Desi picks',
        vibeKey: 'bollywood', icon: Icons.music_note_rounded, trackCount: 18,
      ));
    }
    if (v.length > 2 && v[2] >= 0.68) {
      folders.add(AIFolder(
        id: 'folder_energy', name: 'High Energy',
        description: 'Maximum energy, maximum output',
        vibeKey: 'high_energy', icon: Icons.bolt_rounded, trackCount: 12,
      ));
    }
    if (v.length > 9 && v[9] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_synth', name: 'Synthwave & Electronic',
        description: 'Retro analog and electronic sounds',
        vibeKey: 'retro_synth', icon: Icons.graphic_eq_rounded, trackCount: 14,
      ));
    }
    if (v.length > 3 && v[3] >= 0.68) {
      folders.add(AIFolder(
        id: 'folder_chill', name: 'Chill Sessions',
        description: 'Relaxed and ambient listening',
        vibeKey: 'ambient_chill', icon: Icons.spa_rounded, trackCount: 16,
      ));
    }
    if (v.length > 16 && v[16] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_sufi', name: 'Sufi & Spiritual',
        description: 'Devotional and soul-stirring music',
        vibeKey: 'late_night', icon: Icons.self_improvement_rounded, trackCount: 10,
      ));
    }
    if (v.length > 21 && v[21] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_rock', name: 'Rock Discoveries',
        description: 'Guitar-driven intensity',
        vibeKey: 'high_energy', icon: Icons.electric_bolt_rounded, trackCount: 12,
      ));
    }
    if (v.length > 5 && v[5] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_acoustic', name: 'Acoustic & Folk',
        description: 'Warm, intimate, and unplugged',
        vibeKey: 'acoustic_warm', icon: Icons.library_music_rounded, trackCount: 13,
      ));
    }

    return folders;
  }

  // Personalized mixes derived from actual dominant taste axes.
  // Generates mixes for all 6 sourceTypes: longTerm, session, genre,
  // artist, discovery, prompt — so the SessionContextTracker's session
  // blending is visible in the Library tab.
  List<AIMix> getPersonalizedMixes() {
    final mixes = <AIMix>[];
    final topArtists = NoctraLocalDatabase().getTopArtists(limit: 3);

    // Map vibeKeys to MixSourceType
    MixSourceType typeForKey(String vk) {
      if (vk == 'discovery') return MixSourceType.discovery;
      if (vk == 'bollywood') return MixSourceType.genre;
      return MixSourceType.longTerm;
    }

    for (final pl in getAIGeneratedPlaylists()) {
      mixes.add(AIMix(
        id: pl.id, title: pl.title, subtitle: pl.subtitle,
        artworkUrl: pl.artworkUrl, vibeKey: pl.vibeKey,
        sourceType: typeForKey(pl.vibeKey),
      ));
    }

    // Session-based mix: from recently played in this session
    if (_recentlyPlayed.length >= 3) {
      mixes.add(AIMix(
        id: 'ai_session_mix', title: 'Session Vibes',
        subtitle: 'Based on what you\'re feeling right now',
        artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
        vibeKey: 'late_night', sourceType: MixSourceType.session,
      ));
    }

    // Artist-based mix: from top artists
    if (topArtists.isNotEmpty) {
      mixes.add(AIMix(
        id: 'ai_artist_mix', title: '${topArtists.first} & More',
        subtitle: 'Artists you love most',
        artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500',
        vibeKey: 'high_energy', sourceType: MixSourceType.artist,
      ));
    }

    // Prompt-based mix: from favorite genres
    final topGenres = NoctraLocalDatabase().getTopGenres(limit: 2);
    if (topGenres.isNotEmpty) {
      mixes.add(AIMix(
        id: 'ai_prompt_mix', title: '${topGenres.first} Discovery',
        subtitle: 'Fresh picks in your favorite genres',
        artworkUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        vibeKey: 'deep_focus', sourceType: MixSourceType.prompt,
      ));
    }

    return mixes;
  }

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
      final score = ((sim * 85) + 14).round().clamp(10, 99);
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
      final score = ((sim * 85) + 14).round().clamp(10, 99);
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

  void renameFolder(String oldName, String newName) {
    final cleanNew = newName.trim();
    if (oldName != cleanNew && cleanNew.isNotEmpty && _customFolders.containsKey(oldName) && !_customFolders.containsKey(cleanNew)) {
      final songs = _customFolders.remove(oldName)!;
      _customFolders[cleanNew] = songs;
      _persistState();
      notifyListeners();
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
