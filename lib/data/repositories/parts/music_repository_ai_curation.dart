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
      subtitle: 'Based on your recent listening affinity',
      artworkUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
      vibeKey: 'discovery',
      tracks: curatedTracks('discovery'),
    ));

    if (v.length > 8 && v[8] >= 0.65) {
      playlists.add(AIPlaylist(
        id: 'ai_late_night',
        title: 'Late Night Noir',
        subtitle: 'Dark, slow, and atmospheric sounds',
        artworkUrl:
            'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=500',
        vibeKey: 'late_night',
        tracks: curatedTracks('late_night'),
      ));
    }
    if (v.length > 4 && v[4] >= 0.65) {
      playlists.add(AIPlaylist(
        id: 'ai_deep_focus',
        title: 'Deep Focus Flow',
        subtitle: 'Instrumental and low-tempo clarity',
        artworkUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
        vibeKey: 'deep_focus',
        tracks: curatedTracks('deep_focus'),
      ));
    }
    if (v.isNotEmpty && v[0] >= 0.65) {
      playlists.add(AIPlaylist(
          id: 'ai_noir_night',
          title: 'Midnight Drive',
          subtitle: 'Moody synth and night-sky melodies',
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
          id: 'ai_ambient',
          title: 'Atmospheric Waves',
          subtitle: 'Space to breathe and unwind',
          artworkUrl:
              'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500',
          vibeKey: 'ambient_chill',
          tracks: curatedTracks('ambient_chill')));
    }

    if (playlists.length < 2) {
      playlists.add(AIPlaylist(
          id: 'ai_noir_default',
          title: 'Noir Essentials',
          subtitle: 'Signature dark aesthetic selections',
          artworkUrl:
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
          vibeKey: 'noir_night',
          tracks: curatedTracks('noir_night')));
    }

    return playlists;
  }

  // Dynamic AI folders based on user taste vector.
  // Real dynamic counts derived from the user's actual library weights.
  List<AIFolder> getAICuratedFolders() => getCuratedAIFolders();

  List<AIFolder> getCuratedAIFolders() {
    final v = _userTasteVector;
    final folders = <AIFolder>[];

    // Calculate approximate track counts based on total library size and vector weight.
    final totalSongs =
        _favorites.length + _downloads.length + _localLibrary.length;
    int trackCountFor(double weight) =>
        totalSongs > 0 ? (totalSongs * weight).clamp(1, 99).toInt() : 8;

    folders.add(AIFolder(
      id: 'folder_favorites',
      name: 'Favorites',
      description: 'Your saved tracks',
      vibeKey: 'favorites',
      icon: Icons.favorite_rounded,
      trackCount: _favorites.length,
    ));

    folders.add(AIFolder(
      id: 'folder_downloads',
      name: 'Downloads',
      description: 'Available offline',
      vibeKey: 'downloads',
      icon: Icons.download_done_rounded,
      trackCount: _downloads.length,
    ));

    // Dynamic AI folders based on taste vector thresholds
    if (v.length > 8 && v[8] >= 0.60) {
      folders.add(AIFolder(
        id: 'folder_late_night',
        name: 'Late Night Moods',
        description: 'Slow-burning night selections',
        vibeKey: 'late_night',
        icon: Icons.nights_stay_rounded,
        trackCount: trackCountFor(v[8] * 0.2),
      ));
    }
    if (v.length > 4 && v[4] >= 0.60) {
      folders.add(AIFolder(
        id: 'folder_focus',
        name: 'Focus Archive',
        description: 'Instrumental and ambient clarity',
        vibeKey: 'deep_focus',
        icon: Icons.center_focus_strong_rounded,
        trackCount: trackCountFor(v[4] * 0.2),
      ));
    }
    if (v.isNotEmpty && v[0] >= 0.60) {
      folders.add(AIFolder(
        id: 'folder_synth',
        name: 'Synth & Noir',
        description: 'Electronic warmth and retro pulses',
        vibeKey: 'retro_synth',
        icon: Icons.graphic_eq_rounded,
        trackCount: trackCountFor(v[0] * 0.2),
      ));
    }
    if (v.length > 19 && v[19] >= 0.55) {
      folders.add(AIFolder(
        id: 'folder_desi',
        name: 'Desi Vault',
        description: 'Bollywood and South Asian picks',
        vibeKey: 'bollywood',
        icon: Icons.music_note_rounded,
        trackCount: trackCountFor(v[19] * 0.2),
      ));
    }
    if (v.length > 1 && v[1] >= 0.65) {
      folders.add(AIFolder(
        id: 'folder_hiphop',
        name: 'Hip-Hop & Beats',
        description: 'Rhythm, flow, and heavy bass',
        vibeKey: 'hiphop_urban',
        icon: Icons.album_rounded,
        trackCount: trackCountFor(0.15),
      ));
    }
    if (v.length > 6 && v[6] >= 0.65) {
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
        title: 'Session Flow',
        subtitle: 'Blending tracks from your current session',
        artworkUrl: _recentlyPlayed.first.artworkUrl ??
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
        vibeKey: 'session',
        sourceType: MixSourceType.session,
      ));
    }

    // Artist-affinity mix: top listened artist
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
}
