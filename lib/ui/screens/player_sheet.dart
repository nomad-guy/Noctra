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
import '../widgets/queue_sheet.dart';
import '../widgets/song_context_menu.dart';
import '../widgets/audio_output_cast_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/player_controls_section.dart';
import '../widgets/player_visualizer_selector.dart';
import '../widgets/stem_separation_sheet.dart';
import '../widgets/stream_quality_sheet.dart';
import 'jam_studio_sheet.dart';
import 'artist_screen.dart';

enum StudioMasterMode { lossless320, spatial3d, concertReverb }

enum PlayerDisplayMode {
  artwork,
  spectrumBars,
  radialCircle,
  synthwaveGrid,
  lyrics
}

final studioMasterModeProvider =
    StateProvider<StudioMasterMode>((ref) => StudioMasterMode.lossless320);
final playerDisplayModeProvider =
    StateProvider<PlayerDisplayMode>((ref) => PlayerDisplayMode.artwork);

class PlayerSheet extends ConsumerWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;
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
            color: themeMode.isLiquidGlass
                ? null
                : tokens.surface.withValues(alpha: 0.96),
            gradient: themeMode.isLiquidGlass
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.surfaceVariant.withValues(alpha: 0.94),
                      tokens.canvas.withValues(alpha: 0.88),
                      tokens.secondaryAccent.withValues(alpha: 0.18),
                    ],
                  )
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: tokens.subtleBorder),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                            color: tokens.secondaryText.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final foreground = tokens.primaryText;
                  return Row(children: [
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 28, color: foreground),
                        onPressed: () => Navigator.of(context).pop()),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('NOW PLAYING',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                                color: tokens.secondaryText))),
                    _iconBtn(
                        Icons.queue_music_rounded,
                        foreground,
                        'Queue',
                        () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (c) => const QueueSheet())),
                    _iconBtn(
                        audioPlayerService.sleepTimerRemainingMinutes != null
                            ? Icons.bedtime_rounded
                            : Icons.bedtime_outlined,
                        audioPlayerService.sleepTimerRemainingMinutes != null
                            ? Colors.cyanAccent
                            : foreground,
                        'Sleep Timer',
                        () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (c) => const SleepTimerSheet())),
                    if (compact)
                      _playerMoreMenu(context, ref, isDark)
                    else ...[
                      _iconBtn(
                          Icons.speaker_group_rounded,
                          foreground,
                          'Audio Output',
                          () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (c) =>
                                  AudioOutputCastSheet(isDark: isDark))),
                      _iconBtn(
                          Icons.podcasts_rounded,
                          foreground,
                          'Jam Room',
                          () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (c) => const JamStudioSheet())),
                      _iconBtn(
                          Icons.equalizer_rounded,
                          foreground,
                          'Equalizer',
                          () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (c) => const EqualizerSheet())),
                    ],
                  ]);
                }),
                const SizedBox(height: 14),
                PlayerVisualizerSelector(
                    isDark: isDark, currentMode: displayMode),
                const SizedBox(height: 14),
                Container(
                  height: heroH,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: tokens.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: tokens.subtleBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildVisualizerContent(
                        displayMode, song, isPlaying, isDark, heroH),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(song.artworkUrl ?? '',
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                            cacheHeight: 180,
                            errorBuilder: (c, e, st) => Container(
                                width: 58,
                                height: 58,
                                color: tokens.elevatedSurface,
                                child: Icon(Icons.music_note_rounded,
                                    color: tokens.secondaryText)))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.primaryText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (c) => ArtistScreen(
                                          artistName: song.artist,
                                          artistImageUrl: song.artworkUrl)));
                                },
                                child: Text(song.artist,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: tokens.secondaryText),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ]),
                    ),
                    IconButton(
                        icon: Icon(
                            repo.isFavorite(song.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: tokens.primaryText),
                        onPressed: () => repo.toggleFavorite(song)),
                    IconButton(
                        icon: Icon(Icons.playlist_add_rounded,
                            size: 22, color: tokens.primaryText),
                        onPressed: () => SongContextMenu.show(context, song)),
                    IconButton(
                        icon: Icon(
                            isDownloaded
                                ? Icons.download_done_rounded
                                : Icons.download_rounded,
                            size: 22,
                            color: isDownloaded
                                ? tokens.tertiaryAccent
                                : tokens.tertiaryText),
                        onPressed: () =>
                            _handleDownload(context, song, isDownloaded)),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(children: [
                    _masterChip(
                        context,
                        ref,
                        'Master 320k',
                        StudioMasterMode.lossless320,
                        Icons.album_rounded,
                        masterMode),
                    const SizedBox(width: 8),
                    _masterChip(
                        context,
                        ref,
                        'Spatial 3D',
                        StudioMasterMode.spatial3d,
                        Icons.surround_sound_rounded,
                        masterMode),
                    const SizedBox(width: 8),
                    _masterChip(
                        context,
                        ref,
                        'Concert Reverb',
                        StudioMasterMode.concertReverb,
                        Icons.stadium_rounded,
                        masterMode),
                  ]),
                ),
                const SizedBox(height: 20),
                PlayerControlsSection(
                  isDark: isDark,
                  isPlaying: isPlaying,
                  position: position,
                  duration: duration,
                  volume: ref.watch(volumeStreamProvider).value ?? 1.0,
                  isShuffle: audioPlayerService.player.shuffleModeEnabled,
                  loopMode: audioPlayerService.player.loopMode,
                  audioPlayerService: audioPlayerService,
                  masterMode: masterMode,
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (c) => AIRadioSheet(seedSong: song)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: tokens.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: tokens.subtleBorder)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 14, color: tokens.secondaryAccent),
                              const SizedBox(width: 6),
                              Text('AI Radio',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.secondaryText))
                            ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (c) => ArtistScreen(
                                artistName: song.artist,
                                artistImageUrl: song.artworkUrl)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: tokens.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: tokens.subtleBorder)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                  radius: 12,
                                  backgroundColor: tokens.elevatedSurface,
                                  backgroundImage: song.artworkUrl != null
                                      ? NetworkImage(song.artworkUrl!)
                                      : null),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.secondaryText))),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 11, color: tokens.tertiaryText),
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

  Widget _iconBtn(
          IconData icon, Color color, String tooltip, VoidCallback onTap) =>
      IconButton(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          tooltip: tooltip,
          icon: Icon(icon, size: 19, color: color),
          onPressed: onTap);

  Widget _playerMoreMenu(BuildContext context, WidgetRef ref, bool isDark) {
    final song = ref.watch(currentSongStreamProvider).value;
    return PopupMenuButton<String>(
      tooltip: 'More player actions',
      icon: Icon(Icons.more_horiz_rounded,
          color: isDark ? Colors.white : Colors.black),
      onSelected: (value) {
        switch (value) {
          case 'output':
            showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => AudioOutputCastSheet(isDark: isDark));
          case 'jam':
            showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const JamStudioSheet());
          case 'equalizer':
            showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const EqualizerSheet());
          case 'stems':
            if (song != null) {
              showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => StemSeparationSheet(song: song));
            }
          case 'quality':
            showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const StreamQualitySheet());
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'output', child: Text('Audio output')),
        const PopupMenuItem(value: 'jam', child: Text('Jam room')),
        const PopupMenuItem(value: 'equalizer', child: Text('Equalizer')),
        const PopupMenuItem(value: 'quality', child: Text('CODEC & Resolution')),
        const PopupMenuItem(value: 'stems', child: Text('Audio Stems')),      
      ],
    );
  }

  Widget _buildVisualizerContent(PlayerDisplayMode mode, Song song,
      bool isPlaying, bool isDark, double height) {
    switch (mode) {
      case PlayerDisplayMode.lyrics:
        return LyricsView(song: song);
      case PlayerDisplayMode.spectrumBars:
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SpectrumBarsVisualizer(
                isPlaying: isPlaying,
                color: isDark ? Colors.white : Colors.black,
                height: height - 24));
      case PlayerDisplayMode.radialCircle:
        return Center(
            child: RadialCircleVisualizer(
                isPlaying: isPlaying,
                color: isDark ? Colors.white : Colors.black,
                imageUrl: song.artworkUrl,
                size: height * 0.7));
      case PlayerDisplayMode.synthwaveGrid:
        return ProperSynthwaveVisualizer(
            isPlaying: isPlaying, isDark: isDark, height: height);
      case PlayerDisplayMode.artwork:
        return Center(
            child: AmbientGlowArt(
                imageUrl: song.artworkUrl,
                isPlaying: isPlaying,
                isDark: isDark,
                size: height * 0.75,
                radius: 20));
    }
  }

  Widget _masterChip(BuildContext context, WidgetRef ref, String label,
      StudioMasterMode mode, IconData icon, StudioMasterMode current) {
    final isSel = current == mode;
    final tokens = context.noctraTokens;
    return InkWell(
      onTap: () async {
        final applied = await ref
            .read(audioPlayerServiceProvider)
            .applyStudioMasterMode(mode.name);
        if (applied) {
          ref.read(studioMasterModeProvider.notifier).state = mode;
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This audio effect is unavailable for the current output.'),
            duration: Duration(seconds: 2),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: isSel ? tokens.accent : tokens.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: isSel ? tokens.accent : tokens.subtleBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13, color: isSel ? tokens.canvas : tokens.secondaryText),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? tokens.canvas : tokens.secondaryText))
        ]),
      ),
    );
  }

  void _handleDownload(
      BuildContext context, Song song, bool isDownloaded) async {
    final sm = ScaffoldMessenger.of(context);
    if (isDownloaded) {
      sm.showSnackBar(const SnackBar(
          content: Text('Song already downloaded for offline playback.'),
          duration: Duration(seconds: 2)));
      return;
    }
    sm.showSnackBar(SnackBar(
        content:
            Text('Downloading "${song.title}" in 320kbps High-Fidelity...'),
        duration: const Duration(seconds: 2)));
    final res = await MusicService.downloadTrack(song);
    if (res != null) {
      MusicRepository().addDownloadedSong(res);
    }
    if (context.mounted) {
      sm.showSnackBar(SnackBar(
          content: Text(res != null
              ? 'Downloaded "${song.title}" for offline playback'
              : 'Download failed. Check connection.'),
          duration: const Duration(seconds: 3)));
    }
  }
}
