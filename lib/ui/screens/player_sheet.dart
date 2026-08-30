import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/ai_radio_sheet.dart';
import '../widgets/ambient_glow_art.dart';
import '../widgets/spectrum_bars_visualizer.dart';
import '../widgets/radial_circle_visualizer.dart';
import '../widgets/proper_synthwave_visualizer.dart';
import '../widgets/add_to_folder_sheet.dart';
import '../widgets/audio_output_cast_sheet.dart';
import '../widgets/player_controls_section.dart';
import '../widgets/player_visualizer_selector.dart';
import 'jam_studio_sheet.dart';

enum StudioMasterMode { lossless320, spatial3d, concertReverb }
enum PlayerDisplayMode { artwork, spectrumBars, radialCircle, synthwaveGrid, lyrics }

final studioMasterModeProvider = StateProvider<StudioMasterMode>((ref) => StudioMasterMode.lossless320);
final playerDisplayModeProvider = StateProvider<PlayerDisplayMode>((ref) => PlayerDisplayMode.artwork);

class PlayerSheet extends ConsumerWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == NoirThemeMode.noirBlack;
    final audioPlayerService = ref.watch(audioPlayerServiceProvider);
    final repo = ref.watch(musicRepositoryProvider);
    final song = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = audioPlayerService.player.duration ?? Duration.zero;
    final isShuffle = audioPlayerService.player.shuffleModeEnabled;
    final loopMode = audioPlayerService.player.loopMode;
    final volume = ref.watch(volumeStreamProvider).value ?? 1.0;
    final masterMode = ref.watch(studioMasterModeProvider);
    final displayMode = ref.watch(playerDisplayModeProvider);

    if (song == null) return const SizedBox.shrink();
    final isDownloaded = repo.downloads.any((d) => d.id == song.id);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF6070707) : const Color(0xF6FAFAFA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: isDark ? Colors.white : Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('NOW PLAYING', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 2.2, color: isDark ? Colors.white60 : Colors.black54)),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Audio Output Router',
                        icon: Icon(Icons.speaker_group_rounded, size: 21, color: isDark ? Colors.white : Colors.black),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => AudioOutputCastSheet(isDark: isDark),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Noctra Jam Room',
                        icon: Icon(Icons.podcasts_rounded, size: 21, color: isDark ? Colors.white : Colors.black),
                        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const JamStudioSheet()),
                      ),
                      IconButton(
                        tooltip: 'Equalizer',
                        icon: Icon(Icons.equalizer_rounded, size: 21, color: isDark ? Colors.white : Colors.black),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const EqualizerSheet(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Mode Switcher: Artwork | Spectrum | Circle | Synthwave | Lyrics
              PlayerVisualizerSelector(isDark: isDark, currentMode: displayMode),

              const SizedBox(height: 12),

              // Live Screen Container
              Container(
                height: displayMode == PlayerDisplayMode.lyrics ? 220 : 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFEBEBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildVisualizerContent(displayMode, song, isPlaying, isDark),
                ),
              ),

              const SizedBox(height: 14),

              // Track Title & Action Icons
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      song.artworkUrl ?? '',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) => Container(width: 52, height: 52, color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5), child: Icon(Icons.music_note_rounded, color: isDark ? Colors.white54 : Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(repo.isFavorite(song.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isDark ? Colors.white : Colors.black),
                    onPressed: () => repo.toggleFavorite(song),
                  ),
                  IconButton(
                    icon: Icon(Icons.playlist_add_rounded, color: isDark ? Colors.white : Colors.black),
                    onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AddToFolderSheet(song: song)),
                  ),
                  IconButton(
                    icon: Icon(isDownloaded ? Icons.download_done_rounded : Icons.download_rounded, color: isDownloaded ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black38)),
                    onPressed: isDownloaded ? null : () async => await MusicService.downloadTrack(song),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Studio Master Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _masterChip(ref, 'Lossless 320k', StudioMasterMode.lossless320, Icons.album_rounded, masterMode, isDark),
                  const SizedBox(width: 8),
                  _masterChip(ref, 'Spatial 3D', StudioMasterMode.spatial3d, Icons.surround_sound_rounded, masterMode, isDark),
                  const SizedBox(width: 8),
                  _masterChip(ref, 'Concert Reverb', StudioMasterMode.concertReverb, Icons.stadium_rounded, masterMode, isDark),
                ],
              ),

              const SizedBox(height: 14),

              // Scrubber and Playback Controls
              PlayerControlsSection(
                isDark: isDark,
                isPlaying: isPlaying,
                position: position,
                duration: duration,
                volume: volume,
                isShuffle: isShuffle,
                loopMode: loopMode,
                audioPlayerService: audioPlayerService,
                masterMode: masterMode,
              ),

              const SizedBox(height: 10),

              // AI Radio Pill
              InkWell(
                onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AIRadioSheet(seedSong: song)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: isDark ? Colors.white : Colors.black),
                      const SizedBox(width: 6),
                      Text('Start Infinite AI Radio from this track', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizerContent(PlayerDisplayMode mode, Song song, bool isPlaying, bool isDark) {
    switch (mode) {
      case PlayerDisplayMode.lyrics: return LyricsView(song: song);
      case PlayerDisplayMode.spectrumBars:
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: SpectrumBarsVisualizer(isPlaying: isPlaying, color: isDark ? Colors.white : Colors.black, height: 136));
      case PlayerDisplayMode.radialCircle:
        return Center(child: RadialCircleVisualizer(isPlaying: isPlaying, color: isDark ? Colors.white : Colors.black, imageUrl: song.artworkUrl, size: 130));
      case PlayerDisplayMode.synthwaveGrid:
        return ProperSynthwaveVisualizer(isPlaying: isPlaying, isDark: isDark, height: 160);
      case PlayerDisplayMode.artwork:
        return Center(child: AmbientGlowArt(imageUrl: song.artworkUrl, isPlaying: isPlaying, isDark: isDark, size: 140, radius: 20));
    }
  }

  Widget _masterChip(WidgetRef ref, String label, StudioMasterMode mode, IconData icon, StudioMasterMode current, bool isDark) {
    final isSelected = current == mode;
    return InkWell(
      onTap: () {
        ref.read(studioMasterModeProvider.notifier).state = mode;
        ref.read(audioPlayerServiceProvider).applyStudioMasterMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white12 : Colors.black12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
          ],
        ),
      ),
    );
  }
}
