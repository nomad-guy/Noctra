import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';

import 'live_audio_wave.dart';

class RecentlyPlayedSheet extends ConsumerWidget {
  const RecentlyPlayedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);
    final recentlyPlayed = repo.recentlyPlayed;
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recently Played History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recentlyPlayed.length} Tracks • Autonomous taste learning active',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (recentlyPlayed.isNotEmpty)
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                    label: Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      repo.clearRecentlyPlayed();
                    },
                  ),
              ],
            ),
          ),

          // Action buttons (Play All / Shuffle)
          if (recentlyPlayed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.play_arrow_rounded, size: 18, color: isDark ? Colors.black : Colors.white),
                      label: Text(
                        'Play All',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.black : Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ref.read(audioPlayerServiceProvider).playSong(recentlyPlayed.first, newQueue: recentlyPlayed);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.shuffle_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                      label: Text(
                        'Shuffle',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final shuffled = List.of(recentlyPlayed)..shuffle();
                        ref.read(audioPlayerServiceProvider).playSong(shuffled.first, newQueue: shuffled);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Scrollable List
          Expanded(
            child: recentlyPlayed.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          'No recently played tracks',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: recentlyPlayed.length,
                    itemBuilder: (context, i) {
                      final song = recentlyPlayed[i];
                      final isCurrent = currentSong?.id == song.id;
                      final score = repo.computeMatchScore(song);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          radius: 14,
                          isHighlighted: isCurrent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          onTap: () {
                            ref.read(audioPlayerServiceProvider).playSong(song, newQueue: recentlyPlayed);
                          },
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  song.artworkUrl ?? '',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 44,
                                    height: 44,
                                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                                    child: Icon(Icons.music_note_outlined, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${song.artist} • $score% Match',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent && isPlaying) ...[
                                LiveAudioWave(isPlaying: isPlaying, color: isDark ? Colors.white : Colors.black, barCount: 3, height: 14),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                                tooltip: 'Remove from history',
                                onPressed: () {
                                  repo.removeRecentlyPlayed(song.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
