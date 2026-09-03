import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../models/ai_folder_model.dart';
import '../sources/noctra_local_database.dart';
import 'taste_vector_engine.dart';
import '../../services/ytdlp/music_service.dart';
import '../../core/utils/noctra_localization.dart';
import '../../core/utils/noctra_logger.dart';

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

class MusicRepository extends ChangeNotifier {
  static final MusicRepository _instance = MusicRepository._internal();
  factory MusicRepository() => _instance;
  static MusicRepository get instance => _instance;

  final List<Song> _localLibrary = [];
  final List<Song> _downloads = [];
  final List<Song> _favorites = [];
  final Set<String> _downloadIds = {};
  final Set<String> _favoriteIds = {};
  final List<Song> _recentlyPlayed = [];
  final Map<String, List<Song>> _customFolders = {};
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
  Future<void>? _initFuture;

  MusicRepository._internal();

  @visibleForTesting
  void debugResetForTest() {
    _isLoaded = false;
    _initFuture = null;
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
      _favorites.clear();
      _favorites.addAll(favs);
      _favoriteIds.clear();
      _favoriteIds.addAll(favs.map((s) => s.id));
      final downs = await db.loadDownloads();
      _downloads.clear();
      _downloads.addAll(downs);
      _downloadIds.clear();
      _downloadIds.addAll(downs.map((s) => s.id));
      // Reconcile the DB against the filesystem: a download whose local file
      // was deleted out-of-band (or that lost its path) is stale and must not
      // keep masquerading as available offline.
      await pruneMissingDownloadedFiles();
      final recents = await db.loadRecent();
      _recentlyPlayed.clear();
      _recentlyPlayed.addAll(recents);
      final folders = await db.loadCustomFolders();
      _customFolders.clear();
      _customFolders.addAll(folders);
      final tv = await db.loadTasteVector();
      if (tv != null && tv.length == TasteVectorEngine.vectorDimension) {
        _userTasteVector = tv;
        _cachedTasteVector = List.unmodifiable(_userTasteVector);
      }
      _isLoaded = true;
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
    if (isFavorite(song.id)) {
      _favorites.removeWhere((s) => s.id == song.id);
      _favoriteIds.remove(song.id);
    } else {
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
    NoctraLocalDatabase().saveFavorites(_favorites);
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

    NoctraLocalDatabase().saveDownloads(_downloads);
    if (favTouched) NoctraLocalDatabase().saveFavorites(_favorites);
    if (foldersTouched) NoctraLocalDatabase().saveCustomFolders(_customFolders);
    notifyListeners();
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

    NoctraLocalDatabase().saveDownloads(_downloads);
    if (favoritesTouched) {
      NoctraLocalDatabase().saveFavorites(_favorites);
    }
    if (foldersTouched) {
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
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

  /// Removes downloaded entries whose backing file no longer exists (deleted
  /// out-of-band, SD-card removal, failed download cleanup) or whose path was
  /// lost. Returns how many entries were pruned. Never deletes files.
  Future<int> pruneMissingDownloadedFiles() async {
    if (_downloads.isEmpty) return 0;
    if (kIsWeb) {
      // No local filesystem on web: downloads are represented without a file
      // path by design (MusicService.downloadTrack returns isDownloaded=true
      // with no path on web). Never prune them here.
      return 0;
    }
    final stale = <String>[];
    for (final d in _downloads) {
      final path = d.localFilePath;
      if (path == null || path.isEmpty) {
        stale.add(d.id);
        continue;
      }
      try {
        if (!File(path).existsSync()) stale.add(d.id);
      } catch (_) {
        stale.add(d.id); // unreadable/invalid path — treat as missing
      }
    }
    if (stale.isEmpty) return 0;
    _downloads.removeWhere((d) => stale.contains(d.id));
    _downloadIds.removeAll(stale);

    // Mirror the removal onto favorite rows that point at now-missing files.
    var favoritesTouched = false;
    for (var i = 0; i < _favorites.length; i++) {
      final fav = _favorites[i];
      if (stale.contains(fav.id) &&
          (fav.isDownloaded || fav.localFilePath != null)) {
        _favorites[i] =
            fav.copyWith(isDownloaded: false, clearLocalFilePath: true);
        favoritesTouched = true;
      }
    }

    // Mirror onto custom folders
    var foldersTouched = false;
    _customFolders.forEach((_, songs) {
      for (var i = 0; i < songs.length; i++) {
        final s = songs[i];
        if (stale.contains(s.id) &&
            (s.isDownloaded || s.localFilePath != null)) {
          songs[i] = s.copyWith(
            isDownloaded: false,
            clearLocalFilePath: true,
          );
          foldersTouched = true;
        }
      }
    });

    NoctraLocalDatabase().saveDownloads(_downloads);
    if (favoritesTouched) {
      NoctraLocalDatabase().saveFavorites(_favorites);
    }
    if (foldersTouched) {
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
    }
    notifyListeners();
    return stale.length;
  }

  /// Bulk-adds songs to favorites with a SINGLE full-state write. Import
  /// flows (Spotify/Apple Music/YouTube Music exports) must not trigger one
  /// serialized write per matched track — that is O(N) full-list snapshots.
  /// Idempotent: songs already favorited (by ID) are skipped.
  void addSongsToFavorites(Iterable<Song> songs) {
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
      NoctraLocalDatabase().saveFavorites(_favorites);
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

  List<AIPlaylist> getSmartAIPlaylists() => getAIGeneratedPlaylists();
  List<AIPlaylist> getAIGeneratedPlaylists() => _buildAIPlaylists();

  // Build deduplicated seed track pool from all available sources.
  // Used as initial tracks for AI mix cards before live recommendations load.
  List<AIPlaylist> _buildAIPlaylists() {
    final v = _userTasteVector;
    final playlists = <AIPlaylist>[];

    // Each playlist independently curated via its own vibe/prompt target.
    List<Song> curatedTracks(String vibe, [String? prompt]) {
      return curateByVibe(vibeKey: vibe, naturalPrompt: prompt)
          .map((e) => e['song'] as Song)
          .toList();
    }

    playlists.add(AIPlaylist(
      id: 'ai_for_you',
      title: 'For You Today',
      subtitle: 'Personalized mix based on your taste',
      artworkUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      vibeKey: 'late_night',
      tracks: curatedTracks('late_night'),
    ));

    if (v.length > 10 && v[10] >= 0.60) {
      playlists.add(AIPlaylist(
          id: 'ai_late_night',
          title: 'Late Night Drive',
          subtitle: 'Dark atmosphere for the night hours',
          artworkUrl:
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
          vibeKey: 'noir_night',
          tracks: curatedTracks('noir_night')));
    }
    if (v.length > 9 && v[9] >= 0.60) {
      playlists.add(AIPlaylist(
          id: 'ai_retro',
          title: 'Retro Synth Session',
          subtitle: 'Analog warmth and synthwave energy',
          artworkUrl:
              'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500',
          vibeKey: 'retro_synth',
          tracks: curatedTracks('retro_synth')));
    }
    if (v.length > 2 && v[2] >= 0.65) {
      playlists.add(AIPlaylist(
          id: 'ai_energy',
          title: 'High Energy',
          subtitle: 'Kinetic tracks to keep you moving',
          artworkUrl:
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
          vibeKey: 'high_energy',
          tracks: curatedTracks('high_energy')));
    }
    if (v.length > 19 && v[19] >= 0.60) {
      playlists.add(AIPlaylist(
          id: 'ai_bollywood',
          title: 'Desi Vibes',
          subtitle: 'Bollywood and South Asian favorites',
          artworkUrl:
              'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500',
          vibeKey: 'bollywood',
          tracks: curatedTracks('bollywood')));
    }
    if (v.length > 3 && v[3] >= 0.65) {
      playlists.add(AIPlaylist(
          id: 'ai_chill',
          title: 'Chill & Unwind',
          subtitle: 'Calm tracks for easy listening',
          artworkUrl:
              'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500',
          vibeKey: 'ambient_chill',
          tracks: curatedTracks('ambient_chill')));
    }

    playlists.add(AIPlaylist(
      id: 'ai_discovery',
      title: 'New Discoveries',
      subtitle: 'Fresh tracks outside your usual rotation',
      artworkUrl:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500',
      vibeKey: 'discovery',
      tracks: curatedTracks('late_night', 'deep cut underground hidden gem'),
    ));

    return playlists;
  }

  // Dynamic AI curated folders based on user taste evidence
  List<AIFolder> getAICuratedFolders() {
    final v = _userTasteVector;
    final folders = <AIFolder>[];
    final recentCount = _recentlyPlayed.length;
    // Track counts are derived from actual library size, not hardcoded.
    final librarySize = _localLibrary.length;
    int trackCountFor(double fraction) =>
        (librarySize * fraction).round().clamp(5, 30);

    if (recentCount >= 10) {
      folders.add(AIFolder(
        id: 'folder_rotation',
        name: 'Heavy Rotation',
        description: 'Songs you keep coming back to',
        vibeKey: 'late_night',
        icon: Icons.repeat_rounded,
        trackCount: recentCount.clamp(5, 30),
      ));
    }
    if (v.length > 10 && v[10] >= 0.62) {
      folders.add(AIFolder(
        id: 'folder_night',
        name: 'Late Night',
        description: 'Dark and atmospheric for quiet hours',
        vibeKey: 'noir_night',
        icon: Icons.nightlight_round,
        trackCount: trackCountFor(0.15),
      ));
    }
    if (v.length > 19 && v[19] >= 0.62) {
      folders.add(AIFolder(
        id: 'folder_bollywood',
        name: 'Bollywood Favorites',
        description: 'Your top Bollywood and Desi picks',
        vibeKey: 'bollywood',
        icon: Icons.music_note_rounded,
        trackCount: trackCountFor(0.18),
      ));
    }
    if (v.length > 2 && v[2] >= 0.68) {
      folders.add(AIFolder(
        id: 'folder_energy',
        name: 'High Energy',
        description: 'Maximum energy, maximum output',
        vibeKey: 'high_energy',
        icon: Icons.bolt_rounded,
        trackCount: trackCountFor(0.12),
      ));
    }
    if (v.length > 9 && v[9] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_synth',
        name: 'Synthwave & Electronic',
        description: 'Retro analog and electronic sounds',
        vibeKey: 'retro_synth',
        icon: Icons.graphic_eq_rounded,
        trackCount: trackCountFor(0.14),
      ));
    }
    if (v.length > 3 && v[3] >= 0.68) {
      folders.add(AIFolder(
        id: 'folder_chill',
        name: 'Chill Sessions',
        description: 'Relaxed and ambient listening',
        vibeKey: 'ambient_chill',
        icon: Icons.spa_rounded,
        trackCount: trackCountFor(0.16),
      ));
    }
    if (v.length > 16 && v[16] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_sufi',
        name: 'Sufi & Spiritual',
        description: 'Devotional and soul-stirring music',
        vibeKey: 'late_night',
        icon: Icons.self_improvement_rounded,
        trackCount: trackCountFor(0.10),
      ));
    }
    if (v.length > 21 && v[21] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_rock',
        name: 'Rock Discoveries',
        description: 'Guitar-driven intensity',
        vibeKey: 'high_energy',
        icon: Icons.electric_bolt_rounded,
        trackCount: trackCountFor(0.12),
      ));
    }
    if (v.length > 5 && v[5] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_acoustic',
        name: 'Acoustic & Folk',
        description: 'Warm, intimate, and unplugged',
        vibeKey: 'acoustic_warm',
        icon: Icons.library_music_rounded,
        trackCount: trackCountFor(0.13),
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
        id: pl.id,
        title: pl.title,
        subtitle: pl.subtitle,
        artworkUrl: pl.artworkUrl,
        vibeKey: pl.vibeKey,
        sourceType: typeForKey(pl.vibeKey),
      ));
    }

    // Session-based mix: from recently played in this session
    if (_recentlyPlayed.length >= 3) {
      mixes.add(AIMix(
        id: 'ai_session_mix',
        title: 'Session Vibes',
        subtitle: 'Based on what you\'re feeling right now',
        artworkUrl:
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
        vibeKey: 'late_night',
        sourceType: MixSourceType.session,
      ));
    }

    // Artist-based mix: from top artists
    if (topArtists.isNotEmpty) {
      mixes.add(AIMix(
        id: 'ai_artist_mix',
        title: '${topArtists.first} & More',
        subtitle: 'Artists you love most',
        artworkUrl:
            'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500',
        vibeKey: 'high_energy',
        sourceType: MixSourceType.artist,
      ));
    }

    // Prompt-based mix: from favorite genres
    final topGenres = NoctraLocalDatabase().getTopGenres(limit: 2);
    if (topGenres.isNotEmpty) {
      mixes.add(AIMix(
        id: 'ai_prompt_mix',
        title: '${topGenres.first} Discovery',
        subtitle: 'Fresh picks in your favorite genres',
        artworkUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        vibeKey: 'deep_focus',
        sourceType: MixSourceType.prompt,
      ));
    }

    return mixes;
  }

  List<VibeChip> getDynamicVibeChips() {
    return const [
      VibeChip(
          keyName: 'noir_night',
          label: 'Noir Night',
          iconData: Icons.nightlight_round),
      VibeChip(
          keyName: 'retro_synth',
          label: 'Synthwave',
          iconData: Icons.grid_goldenratio_rounded),
      VibeChip(
          keyName: 'deep_focus',
          label: 'Deep Focus',
          iconData: Icons.psychology_rounded),
      VibeChip(
          keyName: 'high_energy',
          label: 'High Energy',
          iconData: Icons.bolt_rounded),
      VibeChip(
          keyName: 'ambient_chill',
          label: 'Ambient Chill',
          iconData: Icons.spa_rounded),
    ];
  }

  String getUserMusicalArchetype() =>
      TasteVectorEngine.calculateArchetype(_userTasteVector);

  List<Map<String, dynamic>> getDominantAxes() {
    final List<MapEntry<String, double>> pairs = [];
    for (int i = 0;
        i < TasteVectorEngine.axisNames.length && i < _userTasteVector.length;
        i++) {
      pairs.add(MapEntry(TasteVectorEngine.axisNames[i], _userTasteVector[i]));
    }
    pairs.sort((a, b) => b.value.compareTo(a.value));
    return pairs
        .take(4)
        .map((e) => {
              'name': e.key,
              'percentage': (e.value * 100).toInt(),
              'weight': e.value
            })
        .toList();
  }

  List<Map<String, dynamic>> curateByVibe(
      {String? vibeKey, String? naturalPrompt}) {
    final target = TasteVectorEngine.getTargetVector(
        vibeKey: vibeKey,
        prompt: naturalPrompt,
        defaultTaste: _userTasteVector);
    final candidates = {..._localLibrary, ..._downloads, ..._recentlyPlayed}
        .map((s) => s.copyWith())
        .toList();
    if (candidates.isEmpty) {
      candidates.addAll(_localLibrary.map((s) => s.copyWith()));
    }

    final scored = candidates.map((s) {
      final songEmbedding = s.hasUsableEmbedding
          ? s.featureVector
          : TasteVectorEngine.extractSongEmbedding(s);
      final sim = TasteVectorEngine.cosineSimilarity(songEmbedding, target);
      final score = ((sim * 85) + 14).round().clamp(10, 99);
      final exp = TasteVectorEngine.generateExplanation(
          s, score, vibeKey, naturalPrompt);
      return {
        'song': s,
        'score': score,
        'matchPercentage': score,
        'explanation': exp
      };
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.take(12).toList();
  }

  Future<List<Map<String, dynamic>>> curateWithAIAgent(
      {required String prompt, String? vibeKey}) async {
    final cleanPrompt = prompt.trim();
    var searched = await MusicService.search(cleanPrompt);
    if (searched.length < 5) {
      final expanded =
          await MusicService.search('$cleanPrompt chill acoustic vibes');
      searched = <Song>{...searched, ...expanded}.toList();
    }
    final target = TasteVectorEngine.getTargetVector(
        vibeKey: vibeKey, prompt: cleanPrompt, defaultTaste: _userTasteVector);
    final candidates = (searched.isNotEmpty
            ? searched
            : {..._localLibrary, ..._downloads, ..._recentlyPlayed})
        .map((s) => s.copyWith())
        .toList();

    final scored = candidates.map((s) {
      final songEmbedding = s.hasUsableEmbedding
          ? s.featureVector
          : TasteVectorEngine.extractSongEmbedding(s);
      final sim = TasteVectorEngine.cosineSimilarity(songEmbedding, target);
      final score = ((sim * 85) + 14).round().clamp(10, 99);
      final exp =
          TasteVectorEngine.generateExplanation(s, score, vibeKey, cleanPrompt);
      return {
        'song': s,
        'score': score,
        'matchPercentage': score,
        'explanation': exp
      };
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
      if (artistFeed.isNotEmpty) {
        return [seed, ...artistFeed.where((s) => s.id != seed.id)];
      }
    } catch (_) {}
    return [seed, ..._localLibrary.where((s) => s.id != seed.id)];
  }

  void createFolder(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty && !_customFolders.containsKey(clean)) {
      _customFolders[clean] = [];
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
      notifyListeners();
    }
  }

  void addSongToFolder(String folderName, Song song) {
    if (_customFolders.containsKey(folderName)) {
      final list = _customFolders[folderName]!;
      if (!list.any((s) => s.id == song.id)) {
        final dl = _downloads.where((d) => d.id == song.id).firstOrNull;
        final path = dl?.localFilePath;
        list.add(song.copyWith(
          isDownloaded: dl != null,
          localFilePath: path,
          clearLocalFilePath: path == null,
        ));
        NoctraLocalDatabase().saveCustomFolders(_customFolders);
        notifyListeners();
      }
    }
  }

  void removeSongFromFolder(String folderName, String songId) {
    if (_customFolders.containsKey(folderName)) {
      _customFolders[folderName]!.removeWhere((s) => s.id == songId);
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
      notifyListeners();
    }
  }

  void renameFolder(String oldName, String newName) {
    final cleanNew = newName.trim();
    if (oldName != cleanNew &&
        cleanNew.isNotEmpty &&
        _customFolders.containsKey(oldName) &&
        !_customFolders.containsKey(cleanNew)) {
      final songs = _customFolders.remove(oldName)!;
      _customFolders[cleanNew] = songs;
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
      notifyListeners();
    }
  }

  void deleteFolder(String folderName) {
    if (folderName != 'Favorites' && _customFolders.containsKey(folderName)) {
      _customFolders.remove(folderName);
      NoctraLocalDatabase().saveCustomFolders(_customFolders);
      notifyListeners();
    }
  }
}
