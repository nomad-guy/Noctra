part of '../music_repository.dart';

/// Mixin containing AI playlist generation, vibe curation,
/// mood matching, and musical archetype computation.
///
/// All vibes are ranked from ONE shared embedding pool per data state (see
/// [AICurationScorer]); the nine preset vibes never re-score the library
/// independently.
mixin MusicRepositoryAICurationMixin on ChangeNotifier {
  List<double> get _userTasteVector;
  List<Song> get _favorites;
  List<Song> get _downloads;
  List<Song> get _localLibrary;
  List<Song> get _recentlyPlayed;

  // Cached results: `build()` calls these getters on every repository
  // notify (play, favorite, download, …), and re-running the full pool
  // embedding + 9-vibe ranking each time froze the UI. Cards are memoized on
  // a cheap content signature and rebuilt only when the underlying data
  // actually moved.
  List<AIPlaylist>? _memoPlaylists;
  List<AIFolder>? _memoFolders;
  String? _memoPlaylistSignature;
  String? _memoFolderSignature;

  String get _contentSignature {
    final tv = _userTasteVector;
    final quant = List<int>.generate(tv.length, (i) => (tv[i] * 100).round());
    return Object.hashAll([
      quant,
      _localLibrary.length,
      _favorites.length,
      _downloads.length,
      _recentlyPlayed.length,
      _favorites.firstOrNull?.id,
      _downloads.firstOrNull?.id,
      _recentlyPlayed.firstOrNull?.id,
    ]).toRadixString(16);
  }

  List<AIPlaylist> getSmartAIPlaylists() => getAIGeneratedPlaylists();
  List<AIPlaylist> getAIGeneratedPlaylists() {
    final sig = _contentSignature;
    final cached = _memoPlaylists;
    if (cached != null && sig == _memoPlaylistSignature) return cached;
    final built = _buildAIPlaylists();
    _memoPlaylists = built;
    _memoPlaylistSignature = sig;
    return built;
  }

  List<AIPlaylist> _buildAIPlaylists() {
    return MusicRepositoryAIPresets.buildAIPlaylists(
      userTasteVector: _userTasteVector,
      curatedTracks: (vibe, [prompt]) => _curateVibeKeys(
        vibeKey: vibe,
        naturalPrompt: prompt,
      ),
    );
  }

  List<AIFolder> getAICuratedFolders() => getCuratedAIFolders();

  List<AIFolder> getCuratedAIFolders() {
    final sig = _contentSignature;
    final cached = _memoFolders;
    if (cached != null && sig == _memoFolderSignature) return cached;
    final built = MusicRepositoryAIPresets.buildCuratedFolders(
      userTasteVector: _userTasteVector,
      favoritesCount: _favorites.length,
      downloadsCount: _downloads.length,
      totalLibraryCount:
          _favorites.length + _downloads.length + _localLibrary.length,
    );
    _memoFolders = built;
    _memoFolderSignature = sig;
    return built;
  }

  List<AIMix> getPersonalizedMixes() {
    final mixes = <AIMix>[];
    final topArtists = NoctraLocalDatabase().getTopArtists(limit: 3);

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

    if (_recentlyPlayed.length >= 3) {
      mixes.add(AIMix(
        id: 'ai_session_mix',
        title: 'Session Flow',
        subtitle: 'Blending tracks from your current session',
        artworkUrl: _recentlyPlayed.first.artworkUrl ??
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
        vibeKey: 'session',
        sourceType: MixSourceType.session,
      ));
    }

    if (topArtists.isNotEmpty) {
      final topArtist = topArtists.first;
      mixes.add(AIMix(
        id:
            'ai_artist_${topArtist.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
        title: '$topArtist & Similar',
        subtitle: 'Curated around your most listened artist',
        artworkUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
        vibeKey: 'artist_affinity',
        sourceType: MixSourceType.artist,
      ));
    }

    return mixes;
  }

  List<VibeChip> getDynamicVibeChips() =>
      MusicRepositoryAIPresets.dynamicVibeChips;

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

  /// Public vibe curation (AI Studio prompt chips etc.). Kept on the old
  /// per-call semantics so behaviour is unchanged for direct callers.
  List<Map<String, dynamic>> curateByVibe(
      {String? vibeKey, String? naturalPrompt}) {
    final (pool, embeddings) = AICurationScorer.poolAndEmbeddings(
      tasteVector: _userTasteVector,
      library: _localLibrary,
      downloads: _downloads,
      recent: _recentlyPlayed,
    );
    return _rankPool(pool, embeddings,
        vibeKey: vibeKey, naturalPrompt: naturalPrompt);
  }

  /// Rank the shared pool once per vibe (no re-embedding).
  List<Song> _curateVibeKeys({String? vibeKey, String? naturalPrompt}) {
    final (pool, embeddings) = AICurationScorer.poolAndEmbeddings(
      tasteVector: _userTasteVector,
      library: _localLibrary,
      downloads: _downloads,
      recent: _recentlyPlayed,
    );
    final ranked = _rankPool(pool, embeddings,
        vibeKey: vibeKey, naturalPrompt: naturalPrompt);
    return ranked
        .map((e) => e['song'] as Song)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _rankPool(
    List<Song> pool,
    Map<String, List<double>> embeddings, {
    String? vibeKey,
    String? naturalPrompt,
  }) {
    if (pool.isEmpty) return [];
    final target = TasteVectorEngine.getTargetVector(
        vibeKey: vibeKey,
        prompt: naturalPrompt,
        defaultTaste: _userTasteVector);

    final scored = pool.map((s) {
      final songEmbedding = embeddings[s.id] ??
          TasteVectorEngine.extractSongEmbedding(s);
      final sim =
          TasteVectorEngine.cosineSimilarity(songEmbedding, target);
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
}
