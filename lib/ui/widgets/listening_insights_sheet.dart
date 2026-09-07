import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';

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
    final db = NoctraLocalDatabase();
    final manifests = db.manifests.values.toList();

    int totalListenSec = 0;
    int totalPlays = 0;
    final artistPlays = <String, int>{};
    final genrePlays = <String, int>{};

    for (final m in manifests) {
      totalListenSec += m.totalListenSeconds;
      totalPlays += m.playCount;
      artistPlays[m.artist] = (artistPlays[m.artist] ?? 0) + m.playCount;
      if (m.genre.isNotEmpty) {
        genrePlays[m.genre] = (genrePlays[m.genre] ?? 0) + m.playCount;
      }
    }

    final sortedSongs = List.of(manifests)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final topSongs = sortedSongs.take(5).toList();

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
                // Stat counters
                Row(
                  children: [
                    _metricCard('Time Listened', formattedTime, isDark),
                    const SizedBox(width: 8),
                    _metricCard('Tracks Played', totalPlays.toString(), isDark),
                    const SizedBox(width: 8),
                    _metricCard('Top Artist', topArtists.isNotEmpty ? topArtists.first.key : 'None', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Artists
                        _sectionTitle('TOP ARTISTS', isDark),
                        const SizedBox(height: 8),
                        if (topArtists.isEmpty)
                          _emptyState('Listen to music to generate your artist rankings', isDark)
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
                        // Top Songs
                        _sectionTitle('TOP SONGS', isDark),
                        const SizedBox(height: 8),
                        if (topSongs.isEmpty)
                          _emptyState('No tracks completed yet', isDark)
                        else
                          GlassCard(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              children: List.generate(topSongs.length, (i) {
                                final s = topSongs[i];
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              s.artist,
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
                                      Text(
                                        '${s.playCount} plays',
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
                        // Genres
                        if (topGenres.isNotEmpty) ...[
                          _sectionTitle('GENRE DIVERSITY', isDark),
                          const SizedBox(height: 8),
                          GlassCard(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Column(
                              children: topGenres.map((g) {
                                final maxVal = topGenres.first.value;
                                final ratio = maxVal > 0 ? (g.value / maxVal) : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            g.key,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                          Text(
                                            '${g.value} plays',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white54 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ratio.clamp(0.05, 1.0),
                                          minHeight: 5,
                                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
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

  Widget _metricCard(String label, String value, bool isDark) {
    return Expanded(
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  Widget _emptyState(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
        ),
      ),
    );
  }
}
