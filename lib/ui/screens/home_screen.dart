import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/synccast_sheet.dart';
import '../widgets/vibe_chip_selector.dart';
import '../widgets/live_audio_wave.dart';
import '../widgets/recently_played_section.dart';
import '../widgets/ai_generated_playlists_section.dart';
import '../widgets/trending_carousel_section.dart';
import '../widgets/spotify_charts_section.dart';
import '../widgets/dynamic_vibe_stream_section.dart';
import '../widgets/top_artists_carousel.dart';
import '../widgets/noctra_app_logo.dart';
import 'settings_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);
    final syncService = ref.watch(p2pSyncServiceProvider);
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Collapsing / Expanding Floating Glass Top Header
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              backgroundColor: isDark ? const Color(0xDD0A0A0A) : const Color(0xDDFAFAFA),
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 54,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : Colors.black, size: 22),
                          tooltip: 'Open Sidebar',
                          onPressed: () => ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
                        ),
                        NoctraAppLogo(size: 24, radius: 6, isDark: isDark),
                        const SizedBox(width: 6),
                        Text(
                          'NOCTRA',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _topBarIcon(
                          Icons.podcasts_rounded,
                          'SyncCast',
                          isDark,
                          active: syncService.isHost || syncService.isClient,
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const SyncCastSheet(),
                          ),
                        ),
                        _topBarIcon(
                          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          isDark ? 'Light' : 'Dark',
                          isDark,
                          onPressed: () => ref.read(themeModeProvider.notifier).state =
                              isDark ? NoirThemeMode.noirWhite : NoirThemeMode.noirBlack,
                        ),
                        _topBarIcon(
                          Icons.tune_rounded,
                          'Settings',
                          isDark,
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const SettingsSheet(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Greeting -- Spotify-style bold greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      repo.getTimeOfDayGreeting(),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LiveAudioWave(isPlaying: isPlaying, color: isDark ? Colors.white : Colors.black, height: 11, barCount: 3),
                          const SizedBox(width: 5),
                          Text(
                            isPlaying ? 'PLAYING' : 'READY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recently Played
            SliverToBoxAdapter(
              child: RecentlyPlayedSection(isDark: isDark, currentSong: currentSong, isPlaying: isPlaying),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // Top Trending Hits Carousel
            SliverToBoxAdapter(
              child: TrendingCarouselSection(isDark: isDark, currentSong: currentSong, isPlaying: isPlaying),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Explore Top & Featured Artists
            SliverToBoxAdapter(
              child: TopArtistsCarousel(isDark: isDark),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Dynamic Spotify Global Charts
            SliverToBoxAdapter(
              child: SpotifyChartsSection(isDark: isDark, currentSong: currentSong, isPlaying: isPlaying),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // AI Generated Mixes
            SliverToBoxAdapter(child: AIGeneratedPlaylistsSection(isDark: isDark)),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Dynamic Vibe Selector Chips
            const SliverToBoxAdapter(child: VibeChipSelector()),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Made For You (Dynamic Vibe Stream)
            SliverToBoxAdapter(
              child: DynamicVibeStreamSection(isDark: isDark, currentSong: currentSong, isPlaying: isPlaying),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }

  Widget _topBarIcon(IconData icon, String tooltip, bool isDark, {bool active = false, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon, color: active ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white60 : Colors.black54)),
      onPressed: onPressed,
    );
  }
}
