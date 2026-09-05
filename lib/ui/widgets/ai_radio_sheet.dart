import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';


class AIRadioSheet extends ConsumerStatefulWidget {
  final Song seedSong;

  const AIRadioSheet({super.key, required this.seedSong});

  @override
  ConsumerState<AIRadioSheet> createState() => _AIRadioSheetState();
}

class _AIRadioSheetState extends ConsumerState<AIRadioSheet> {
  Future<List<Song>>? _radioFuture;

  @override
  void initState() {
    super.initState();
    _radioFuture = ref.read(musicRepositoryProvider).generateAIRadioForSong(widget.seedSong);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF2080808) : const Color(0xF2FFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white : Colors.black,
                ),
                child: Icon(
                  Icons.radar_rounded,
                  size: 22,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Similarity Radio Station',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Seeded by "${widget.seedSong.title}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Station Tracks List
          Expanded(
            child: FutureBuilder<List<Song>>(
              future: _radioFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Computing 16-axis acoustic nearest neighbors...',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  );
                }

                final tracks = snapshot.data ?? [];
                if (tracks.isEmpty) {
                  return Center(
                    child: Text('No candidate tracks found', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final song = tracks[i];
                    final isSeed = i == 0;
                    final matchScore = repo.computeMatchScore(song);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GlassCard(
                        radius: 14,
                        padding: const EdgeInsets.all(10),
                        isHighlighted: isSeed,
                        onTap: () {
                          ref.read(audioPlayerServiceProvider).playSong(song, newQueue: tracks);
                          Navigator.of(context).pop();
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
                                cacheWidth: 100,
                                cacheHeight: 100,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 44,
                                  height: 44,
                                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                                  child: Icon(Icons.music_note_outlined, color: isDark ? Colors.white54 : Colors.black54),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isSeed) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white : Colors.black,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'SEED',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.black : Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist,
                                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSeed ? '100%' : '$matchScore%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
