import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';
import 'live_audio_wave.dart';
import 'song_context_menu.dart';

class SpotifyChartsSection extends ConsumerWidget {
  final bool isDark;
  final Song? currentSong;
  final bool isPlaying;

  const SpotifyChartsSection({
    super.key,
    required this.isDark,
    required this.currentSong,
    required this.isPlaying,
  });

  static const List<Map<String, String>> _charts = [
    {'key': 'top_hits', 'label': "Today's Top Hits"},
    {'key': 'global_50', 'label': 'Global Top 50'},
    {'key': 'viral_50', 'label': 'Viral Hits'},
    {'key': 'pop_rising', 'label': 'Pop Rising'},
    {'key': 'rap_caviar', 'label': 'RapCaviar'},
    {'key': 'bollywood', 'label': 'Bollywood Butter'},
    {'key': 'chill_hits', 'label': 'Chill Hits'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChart = ref.watch(selectedSpotifyChartKeyProvider);
    final chartTracksAsync = ref.watch(dynamicSpotifyChartsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                NoctraLocalization.tr('top_charts'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? NoirColors.blackTextPrimary
                      : NoirColors.whiteTextPrimary,
                ),
              ),
              Text(
                'Live Dynamic',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),

        // Chart Filter Chips
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad
            },
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _charts.map((c) {
                final isSelected = selectedChart == c['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c['label']!),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(selectedSpotifyChartKeyProvider.notifier).state =
                          c['key']!;
                    },
                    backgroundColor: isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFEBEBEB),
                    selectedColor: isDark ? Colors.white : Colors.black,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark
                              ? NoirColors.blackTextPrimary
                              : NoirColors.whiteTextPrimary),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Horizontal Track Carousel
        chartTracksAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 200,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad
                  },
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemExtent: 160.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final song = tracks[i];
                    final isThisPlaying =
                        currentSong?.id == song.id && isPlaying;

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(audioPlayerServiceProvider)
                              .playSong(song, newQueue: tracks);
                        },
                        onLongPress: () => SongContextMenu.show(context, song),
                        child: GlassCard(
                          padding: const EdgeInsets.all(8),
                          radius: 16,
                          child: SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        song.artworkUrl ?? '',
                                        width: 140,
                                        height: 116,
                                        fit: BoxFit.cover,
                                        cacheWidth: 300,
                                        cacheHeight: 300,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          width: 140,
                                          height: 116,
                                          color: isDark
                                              ? const Color(0xFF1E1E1E)
                                              : const Color(0xFFE5E5E5),
                                          child: Icon(Icons.music_note_outlined,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? Colors.black
                                                  .withValues(alpha: 0.8)
                                              : Colors.white
                                                  .withValues(alpha: 0.9),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isThisPlaying)
                                      Positioned(
                                        bottom: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.8),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: LiveAudioWave(
                                              isPlaying: true,
                                              color: Colors.white,
                                              height: 10,
                                              barCount: 3),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? NoirColors.blackTextPrimary
                                        : NoirColors.whiteTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? NoirColors.blackTextSecondary
                                        : NoirColors.whiteTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
          loading: () => SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
