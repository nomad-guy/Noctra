import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // Riverpod 3.x: StateProvider
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
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
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/player_controls_section.dart';
import '../widgets/player_visualizer_selector.dart';
import 'jam_studio_sheet.dart';
import 'artist_screen.dart';

enum StudioMasterMode { lossless320, spatial3d, concertReverb }
enum PlayerDisplayMode { artwork, spectrumBars, radialCircle, synthwaveGrid, lyrics }

final studioMasterModeProvider = StateProvider<StudioMasterMode>((ref) => StudioMasterMode.lossless320);
final playerDisplayModeProvider = StateProvider<PlayerDisplayMode>((ref) => PlayerDisplayMode.artwork);

class PlayerSheet extends ConsumerWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final audioPlayerService = ref.watch(audioPlayerServiceProvider);
    final repo = ref.watch(musicRepositoryProvider);
    final song = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = audioPlayerService.player.duration ?? Duration.zero;
    final masterMode = ref.watch(studioMasterModeProvider);
    final displayMode = ref.watch(playerDisplayModeProvider);

    if (song == null) return const SizedBox.shrink();
    final isDownloaded = repo.downloads.any((d) => d.id == song.id);
    final screenH = MediaQuery.of(context).size.height;
    final heroH = displayMode == PlayerDisplayMode.lyrics
        ? (screenH * 0.38).clamp(260.0, 340.0)
        : (screenH * 0.30).clamp(200.0, 280.0);

    // Track drag start Y to dismiss only when gesture begins in the handle zone
    double dragStartY = 0;
    return GestureDetector(
      onVerticalDragStart: (d) => dragStartY = d.localPosition.dy,
      onVerticalDragEnd: (d) {
        final velocity = d.primaryVelocity ?? 0;
        if (velocity > 400 && dragStartY < 80) Navigator.of(context).pop();
      },
      child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.96),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF6070707) : const Color(0xF6FAFAFA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4.5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.of(context).pop()),
                  Text('NOW PLAYING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: isDark ? Colors.white60 : Colors.black54)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _iconBtn(audioPlayerService.sleepTimerRemainingMinutes != null ? Icons.bedtime_rounded : Icons.bedtime_outlined, audioPlayerService.sleepTimerRemainingMinutes != null ? Colors.cyanAccent : (isDark ? Colors.white : Colors.black), 'Sleep Timer', () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const SleepTimerSheet())),
                    _iconBtn(Icons.speaker_group_rounded, isDark ? Colors.white : Colors.black, 'Audio Output', () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => AudioOutputCastSheet(isDark: isDark))),
                    _iconBtn(Icons.podcasts_rounded, isDark ? Colors.white : Colors.black, 'Jam Room', () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const JamStudioSheet())),
                    _iconBtn(Icons.equalizer_rounded, isDark ? Colors.white : Colors.black, 'Equalizer', () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const EqualizerSheet())),
                  ]),
                ],
              ),
              const SizedBox(height: 14),
              PlayerVisualizerSelector(isDark: isDark, currentMode: displayMode),
              const SizedBox(height: 14),
              Container(
                height: heroH,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFEBEBEB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildVisualizerContent(displayMode, song, isPlaying, isDark, heroH),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(song.artworkUrl ?? '', width: 58, height: 58, fit: BoxFit.cover, cacheWidth: 180, cacheHeight: 180, errorBuilder: (c, e, st) => Container(width: 58, height: 58, color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5), child: Icon(Icons.music_note_rounded, color: isDark ? Colors.white54 : Colors.black54)))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(song.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      InkWell(onTap: () { Navigator.of(context).pop(); Navigator.of(context).push(MaterialPageRoute(builder: (c) => ArtistScreen(artistName: song.artist, artistImageUrl: song.artworkUrl))); }, child: Text(song.artist, style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white54 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  IconButton(icon: Icon(repo.isFavorite(song.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 22, color: isDark ? Colors.white : Colors.black), onPressed: () => repo.toggleFavorite(song)),
                  IconButton(icon: Icon(Icons.playlist_add_rounded, size: 22, color: isDark ? Colors.white : Colors.black), onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AddToFolderSheet(song: song))),
                  IconButton(icon: Icon(isDownloaded ? Icons.download_done_rounded : Icons.download_rounded, size: 22, color: isDownloaded ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black38)), onPressed: () => _handleDownload(context, song, isDownloaded)),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(children: [
                  _masterChip(ref, 'Master 320k', StudioMasterMode.lossless320, Icons.album_rounded, masterMode, isDark),
                  const SizedBox(width: 8),
                  _masterChip(ref, 'Spatial 3D', StudioMasterMode.spatial3d, Icons.surround_sound_rounded, masterMode, isDark),
                  const SizedBox(width: 8),
                  _masterChip(ref, 'Concert Reverb', StudioMasterMode.concertReverb, Icons.stadium_rounded, masterMode, isDark),
                ]),
              ),
              const SizedBox(height: 20),
              PlayerControlsSection(
                isDark: isDark, isPlaying: isPlaying, position: position, duration: duration,
                volume: ref.watch(volumeStreamProvider).value ?? 1.0,
                isShuffle: audioPlayerService.player.shuffleModeEnabled,
                loopMode: audioPlayerService.player.loopMode,
                audioPlayerService: audioPlayerService, masterMode: masterMode,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AIRadioSheet(seedSong: song)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome, size: 14, color: isDark ? Colors.white70 : Colors.black87), const SizedBox(width: 6), Text('AI Radio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () { Navigator.of(context).pop(); Navigator.of(context).push(MaterialPageRoute(builder: (c) => ArtistScreen(artistName: song.artist, artistImageUrl: song.artworkUrl))); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        CircleAvatar(radius: 12, backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC), backgroundImage: song.artworkUrl != null ? NetworkImage(song.artworkUrl!) : null),
                        const SizedBox(width: 8),
                        Expanded(child: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))),
                        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) =>
      IconButton(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 2), tooltip: tooltip, icon: Icon(icon, size: 19, color: color), onPressed: onTap);

  Widget _buildVisualizerContent(PlayerDisplayMode mode, Song song, bool isPlaying, bool isDark, double height) {
    switch (mode) {
      case PlayerDisplayMode.lyrics: return LyricsView(song: song);
      case PlayerDisplayMode.spectrumBars: return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: SpectrumBarsVisualizer(isPlaying: isPlaying, color: isDark ? Colors.white : Colors.black, height: height - 24));
      case PlayerDisplayMode.radialCircle: return Center(child: RadialCircleVisualizer(isPlaying: isPlaying, color: isDark ? Colors.white : Colors.black, imageUrl: song.artworkUrl, size: height * 0.7));
      case PlayerDisplayMode.synthwaveGrid: return ProperSynthwaveVisualizer(isPlaying: isPlaying, isDark: isDark, height: height);
      case PlayerDisplayMode.artwork: return Center(child: AmbientGlowArt(imageUrl: song.artworkUrl, isPlaying: isPlaying, isDark: isDark, size: height * 0.75, radius: 20));
    }
  }

  Widget _masterChip(WidgetRef ref, String label, StudioMasterMode mode, IconData icon, StudioMasterMode current, bool isDark) {
    final isSel = current == mode;
    return InkWell(
      onTap: () { ref.read(studioMasterModeProvider.notifier).state = mode; ref.read(audioPlayerServiceProvider).applyStudioMasterMode(mode.name); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: isSel ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB)), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSel ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white12 : Colors.black12))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: isSel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87)), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87)))]),
      ),
    );
  }

  void _handleDownload(BuildContext context, Song song, bool isDownloaded) async {
    final sm = ScaffoldMessenger.of(context);
    if (isDownloaded) { sm.showSnackBar(const SnackBar(content: Text('Song already downloaded for offline playback.'), duration: Duration(seconds: 2))); return; }
    sm.showSnackBar(SnackBar(content: Text('Downloading "${song.title}" in 320kbps High-Fidelity...'), duration: const Duration(seconds: 2)));
    final res = await MusicService.downloadTrack(song);
    if (res != null) {
      MusicRepository().addDownloadedSong(res);
    }
    if (context.mounted) sm.showSnackBar(SnackBar(content: Text(res != null ? 'Downloaded "${song.title}" for offline playback' : 'Download failed. Check connection.'), duration: const Duration(seconds: 3)));
  }
}
