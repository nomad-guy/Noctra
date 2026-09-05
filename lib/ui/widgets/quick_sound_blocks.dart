import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';


class QuickSoundBlocks extends ConsumerWidget {
  final bool isDark;

  const QuickSoundBlocks({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(musicRepositoryProvider);
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    // Pick top 6 sound block candidates from recently played & local library
    final allCandidates = [...repo.recentlyPlayed, ...repo.localLibrary];
    final items = allCandidates.take(6).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 550;
          final crossAxisCount = isWide ? 3 : 2;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: isWide ? 3.4 : 2.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final song = items[index];
              final isCurrent = currentSong?.id == song.id;

              return GlassCard(
                radius: 12,
                isHighlighted: isCurrent,
                padding: EdgeInsets.zero,
                onTap: () {
                  if (isCurrent) {
                    ref.read(audioPlayerServiceProvider).togglePlayPause();
                  } else {
                    ref.read(audioPlayerServiceProvider).playSong(song, newQueue: items);
                  }
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      child: Image.network(
                        song.artworkUrl ?? '',
                        width: 54,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        cacheHeight: 160,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 54,
                          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                          child: Icon(Icons.music_note_rounded, size: 22, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      child: Icon(
                        isCurrent && isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
