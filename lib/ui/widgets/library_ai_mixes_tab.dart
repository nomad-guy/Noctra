import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import 'glass_card.dart';

class LibraryAIMixesTab extends ConsumerWidget {
  final bool isDark;
  final MusicRepository repo;

  const LibraryAIMixesTab({super.key, required this.isDark, required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = repo.getAIGeneratedPlaylists();
    final topArtists = NoctraLocalDatabase().getTopArtists(limit: 5);
    final archetype = repo.getUserMusicalArchetype();
    final dominant = repo.getDominantAxes();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. On-Device Neural Profile Card
        GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        child: Icon(Icons.psychology_rounded, size: 16, color: isDark ? Colors.black : Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'On-Device Taste Profile',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '100% Private',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                archetype,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Dominant Dimensions
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: dominant.map((d) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Text(
                      '${d['name']}: ${d['percentage']}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Top Artists Section
        if (topArtists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Top Artists in Rotation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: topArtists.length,
              itemBuilder: (context, i) {
                final artist = topArtists[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161616) : const Color(0xFFEBEBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          artist,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 3. AI Generated Mixes List
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Personalized AI Mixes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
            ),
          ),
        ),

        ...playlists.map((pl) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              radius: 14,
              padding: const EdgeInsets.all(10),
              onTap: () async {
                final tracks = await MusicService.fetchVibeFeed(pl.vibeKey);
                if (tracks.isNotEmpty) {
                  ref.read(audioPlayerServiceProvider).playSong(tracks.first, newQueue: tracks);
                }
              },
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      pl.artworkUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 52,
                        height: 52,
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5),
                        child: Icon(Icons.album_rounded, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pl.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
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
                            fontSize: 12,
                            color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    child: Icon(Icons.play_arrow_rounded, size: 18, color: isDark ? Colors.black : Colors.white),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 80),
      ],
    );
  }
}
