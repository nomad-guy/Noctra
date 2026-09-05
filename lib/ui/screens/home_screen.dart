import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/vibe_chip_selector.dart';
import '../widgets/recently_played_section.dart';
import '../widgets/ai_generated_playlists_section.dart';
import '../widgets/trending_carousel_section.dart';
import '../widgets/spotify_charts_section.dart';
import '../widgets/dynamic_vibe_stream_section.dart';
import '../widgets/top_artists_carousel.dart';
import '../widgets/home/home_screen_app_bar.dart';
import '../widgets/home/home_greeting_section.dart';

/// Home feed screen: floating glass header, greeting, and the dynamic
/// section carousels. The header and greeting are extracted into
/// widgets/home/ files; this file only assembles the slivers.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await refreshHomeFeeds(ref);
            await Future.delayed(const Duration(milliseconds: 650));
            HapticFeedback.lightImpact();
          },
          color: isDark ? Colors.white : Colors.black,
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // Collapsing / Expanding Floating Glass Top Header
              HomeScreenAppBar(isDark: isDark, themeMode: themeMode),

              // Greeting -- Spotify-style bold greeting
              HomeGreetingSection(isDark: isDark, isPlaying: isPlaying),

              // Recently Played
              SliverToBoxAdapter(
                child: RecentlyPlayedSection(
                    isDark: isDark,
                    currentSong: currentSong,
                    isPlaying: isPlaying),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 6)),

              // Top Trending Hits Carousel
              SliverToBoxAdapter(
                child: TrendingCarouselSection(
                    isDark: isDark,
                    currentSong: currentSong,
                    isPlaying: isPlaying),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Explore Top & Featured Artists
              SliverToBoxAdapter(
                child: TopArtistsCarousel(isDark: isDark),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Dynamic global charts
              SliverToBoxAdapter(
                child: SpotifyChartsSection(
                    isDark: isDark,
                    currentSong: currentSong,
                    isPlaying: isPlaying),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 6)),

              // AI Generated Mixes
              SliverToBoxAdapter(
                  child: AIGeneratedPlaylistsSection(isDark: isDark)),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // Dynamic Vibe Selector Chips
              const SliverToBoxAdapter(child: VibeChipSelector()),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // Made For You (Dynamic Vibe Stream)
              SliverToBoxAdapter(
                child: DynamicVibeStreamSection(
                    isDark: isDark,
                    currentSong: currentSong,
                    isPlaying: isPlaying),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
        ),
      ),
    );
  }
}
