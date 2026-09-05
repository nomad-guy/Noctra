import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';


class AIGeneratedPlaylistsSection extends ConsumerWidget {
  final bool isDark;

  const AIGeneratedPlaylistsSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(musicRepositoryProvider);
    final playlists = repo.getAIGeneratedPlaylists();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                NoctraLocalization.tr('ai_mixes'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                ),
              ),
              Text(
                '16-Axis Neural',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemExtent: 148.0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final pl = playlists[index];

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      final tracks = pl.tracks;
                      if (tracks.isNotEmpty) {
                        ref.read(audioPlayerServiceProvider).playSong(tracks.first, newQueue: tracks);
                      }
                    },
                    child: GlassCard(
                      radius: 16,
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: 136,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    pl.artworkUrl,
                                    width: 136,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    cacheWidth: 280,
                                    cacheHeight: 220,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 136,
                                      height: 110,
                                      color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5),
                                      child: Icon(Icons.album_rounded, color: isDark ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(6),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                                  ),
                                  child: Icon(Icons.play_arrow_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pl.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pl.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
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
        ),
      ],
    );
  }
}
