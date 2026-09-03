part of '../music_repository.dart';

class MusicRepositoryAIPresets {
  static List<AIPlaylist> buildAIPlaylists({
    required List<double> userTasteVector,
    required List<Song> Function(String vibe, [String? prompt]) curatedTracks,
  }) {
    final v = userTasteVector;
    final playlists = <AIPlaylist>[];

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
        tracks: curatedTracks('noir_night'),
      ));
    }
    if (v.length > 9 && v[9] >= 0.60) {
      playlists.add(AIPlaylist(
        id: 'ai_retro',
        title: 'Retro Synth Session',
        subtitle: 'Analog warmth and synthwave energy',
        artworkUrl:
            'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500',
        vibeKey: 'retro_synth',
        tracks: curatedTracks('retro_synth'),
      ));
    }
    if (v.length > 2 && v[2] >= 0.65) {
      playlists.add(AIPlaylist(
        id: 'ai_energy',
        title: 'High Energy',
        subtitle: 'Kinetic tracks to keep you moving',
        artworkUrl:
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
        vibeKey: 'high_energy',
        tracks: curatedTracks('high_energy'),
      ));
    }
    if (v.length > 19 && v[19] >= 0.60) {
      playlists.add(AIPlaylist(
        id: 'ai_bollywood',
        title: 'Desi Vibes',
        subtitle: 'Bollywood and South Asian favorites',
        artworkUrl:
            'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500',
        vibeKey: 'bollywood',
        tracks: curatedTracks('bollywood'),
      ));
    }
    if (v.length > 3 && v[3] >= 0.65) {
      playlists.add(AIPlaylist(
        id: 'ai_ambient',
        title: 'Atmospheric Waves',
        subtitle: 'Space to breathe and unwind',
        artworkUrl:
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500',
        vibeKey: 'ambient_chill',
        tracks: curatedTracks('ambient_chill'),
      ));
    }

    if (playlists.length < 2) {
      playlists.add(AIPlaylist(
        id: 'ai_noir_default',
        title: 'Noir Essentials',
        subtitle: 'Signature dark aesthetic selections',
        artworkUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        vibeKey: 'noir_night',
        tracks: curatedTracks('noir_night'),
      ));
    }

    return playlists;
  }

  static List<AIFolder> buildCuratedFolders({
    required List<double> userTasteVector,
    required int favoritesCount,
    required int downloadsCount,
    required int totalLibraryCount,
  }) {
    final v = userTasteVector;
    final folders = <AIFolder>[];

    int trackCountFor(double weight) => totalLibraryCount > 0
        ? (totalLibraryCount * weight).clamp(1, 99).toInt()
        : 8;

    folders.add(AIFolder(
      id: 'folder_favorites',
      name: 'Favorites',
      description: 'Your saved tracks',
      vibeKey: 'favorites',
      icon: Icons.favorite_rounded,
      trackCount: favoritesCount,
    ));

    folders.add(AIFolder(
      id: 'folder_downloads',
      name: 'Downloads',
      description: 'Available offline',
      vibeKey: 'downloads',
      icon: Icons.download_done_rounded,
      trackCount: downloadsCount,
    ));

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

  static const List<VibeChip> dynamicVibeChips = [
    VibeChip(
      keyName: 'noir_night',
      label: 'Noir Night',
      iconData: Icons.nightlight_round,
    ),
    VibeChip(
      keyName: 'retro_synth',
      label: 'Synthwave',
      iconData: Icons.grid_goldenratio_rounded,
    ),
    VibeChip(
      keyName: 'deep_focus',
      label: 'Deep Focus',
      iconData: Icons.psychology_rounded,
    ),
    VibeChip(
      keyName: 'high_energy',
      label: 'High Energy',
      iconData: Icons.bolt_rounded,
    ),
    VibeChip(
      keyName: 'ambient_chill',
      label: 'Ambient Chill',
      iconData: Icons.spa_rounded,
    ),
  ];
}
