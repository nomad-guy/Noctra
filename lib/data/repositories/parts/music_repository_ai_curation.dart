part of '../music_repository.dart';

/// Mixin containing AI playlist generation, vibe curation,
/// mood matching, and musical archetype computation.
mixin MusicRepositoryAICurationMixin on ChangeNotifier {
  List<double> get _userTasteVector;
  List<Song> get _favorites;
  List<Song> get _downloads;
  List<Song> get _localLibrary;
  List<Song> get _recentlyPlayed;

  List<AIPlaylist> getSmartAIPlaylists() => getAIGeneratedPlaylists();
  List<AIPlaylist> getAIGeneratedPlaylists() => _buildAIPlaylists();

  List<AIPlaylist> _buildAIPlaylists() {
    return MusicRepositoryAIPresets.buildAIPlaylists(
      userTasteVector: _userTasteVector,
      curatedTracks: (vibe, [prompt]) => curateByVibe(
        vibeKey: vibe,
        naturalPrompt: prompt,
      ).map((e) => e['song'] as Song).toList(),
    );
  }

  List<AIFolder> getAICuratedFolders() => getCuratedAIFolders();

  List<AIFolder> getCuratedAIFolders() {
    return MusicRepositoryAIPresets.buildCuratedFolders(
      userTasteVector: _userTasteVector,
      favoritesCount: _favorites.length,
      downloadsCount: _downloads.length,
      totalLibraryCount:
          _favorites.length + _downloads.length + _localLibrary.length,
    );
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
        id: 'ai_artist_${topArtist.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
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
}
