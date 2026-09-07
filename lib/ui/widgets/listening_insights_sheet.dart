import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/repositories/music_repository.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';
import 'listening_insights_components.dart';

class ListeningInsightsSheet extends ConsumerWidget {
  const ListeningInsightsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ListeningInsightsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = MusicRepository.instance;
    final stats = repo.getListeningInsightsStats();

    final int totalListenSec = stats['totalListenSec'] as int? ?? 0;
    final int totalPlays = stats['totalPlays'] as int? ?? 0;
    final artistPlays = (stats['artistPlays'] as Map<String, int>?) ?? {};
    final genrePlays = (stats['genrePlays'] as Map<String, int>?) ?? {};

    final sortedArtists = artistPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(5).toList();

    final sortedGenres = genrePlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(4).toList();

    final hours = totalListenSec ~/ 3600;
    final minutes = (totalListenSec % 3600) ~/ 60;
    final formattedTime = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0C0F) : const Color(0xFFFAFAFD),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          child: Icon(Icons.analytics_outlined,
                              size: 20, color: isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Listening Insights',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Your real-time musical footprint',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    insightsMetricCard('Time Listened', formattedTime, isDark),
                    const SizedBox(width: 8),
                    insightsMetricCard('Tracks Played', totalPlays.toString(), isDark),
                    const SizedBox(width: 8),
                    insightsMetricCard('Top Artist', topArtists.isNotEmpty ? topArtists.first.key : 'None', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        insightsSectionTitle('TOP ARTISTS', isDark),
                        const SizedBox(height: 8),
                        if (topArtists.isEmpty)
                          insightsEmptyState('Listen to music to generate your artist rankings', isDark)
                        else
                          GlassCard(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              children: List.generate(topArtists.length, (i) {
                                final a = topArtists[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '#${i + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          a.key,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${a.value} plays',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        const SizedBox(height: 16),
                        insightsSectionTitle('TOP GENRES', isDark),
                        const SizedBox(height: 8),
                        if (topGenres.isEmpty)
                          insightsEmptyState('Explore more genres to discover your patterns', isDark)
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: topGenres.map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEEEEF2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      g.key,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${g.value}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
