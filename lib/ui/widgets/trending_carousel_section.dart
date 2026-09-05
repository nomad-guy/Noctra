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

class TrendingCarouselSection extends ConsumerStatefulWidget {
  final bool isDark;
  final Song? currentSong;
  final bool isPlaying;

  const TrendingCarouselSection({
    super.key,
    required this.isDark,
    required this.currentSong,
    required this.isPlaying,
  });

  @override
  ConsumerState<TrendingCarouselSection> createState() => _TrendingCarouselSectionState();
}

class _TrendingCarouselSectionState extends ConsumerState<TrendingCarouselSection> {
  int _retryCount = 0;
  static const _maxRetries = 2;

  void _retry() {
    if (_retryCount < _maxRetries) {
      setState(() => _retryCount++);
      ref.invalidate(dynamicTrendingFeedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(dynamicTrendingFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spotify-style section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(NoctraLocalization.tr('top_charts'), style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: widget.isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
              )),
              Text('320kbps CD', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white54 : Colors.black45,
              )),
            ],
          ),
        ),
        trendingAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return _emptyState();
            }
            // M-R5-08: Reset retry count via postFrameCallback, not inside build()
            if (_retryCount != 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _retryCount = 0);
              });
            }
            return SizedBox(
              height: 210,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemExtent: 160.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tracks.length,
                  itemBuilder: (context, i) => _buildCard(tracks, i),
                ),
              ),
            );
          },
          loading: () => SizedBox(
            height: 210,
            child: Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: widget.isDark ? Colors.white : Colors.black,
            )),
          ),
          error: (e, _) => _errorState(),
        ),
      ],
    );
  }

  Widget _buildCard(List<Song> tracks, int i) {
    final song = tracks[i];
    final isThisPlaying = widget.currentSong?.id == song.id && widget.isPlaying;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => ref.read(audioPlayerServiceProvider).playSong(song, newQueue: tracks),
        onLongPress: () => SongContextMenu.show(context, song),
        child: GlassCard(
          padding: const EdgeInsets.all(8),
          radius: 16,
          child: SizedBox(
            width: 148,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        song.artworkUrl ?? '', width: 148, height: 126, fit: BoxFit.cover,
                        cacheWidth: 300, cacheHeight: 300,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 148, height: 126,
                          color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                          child: Icon(Icons.music_note_outlined, color: widget.isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                    // Rank badge
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : Colors.black,
                        )),
                      ),
                    ),
                    if (isThisPlaying)
                      Positioned(
                        bottom: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6),
                          ),
                          child: LiveAudioWave(isPlaying: true, color: Colors.white, height: 10, barCount: 3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: widget.isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                )),
                const SizedBox(height: 2),
                Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                  fontSize: 11, color: widget.isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(
        'No trending tracks available', style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.black45),
      )),
    );
  }

  Widget _errorState() {
    return GestureDetector(
      onTap: _retry,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Column(
          children: [
            Icon(Icons.refresh_rounded, size: 28, color: widget.isDark ? Colors.white54 : Colors.black45),
            const SizedBox(height: 6),
            Text('Tap to retry', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.black45)),
          ],
        )),
      ),
    );
  }
}
