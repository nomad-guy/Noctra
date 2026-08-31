import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import '../screens/artist_screen.dart';
import 'glass_card.dart';
import 'add_to_folder_sheet.dart';
import 'ai_radio_sheet.dart';

class SearchResultsList extends ConsumerWidget {
  final bool isDark;
  final List<Song> searchResults;
  final bool isSearching;
  final ValueChanged<String>? onGenreTap;

  const SearchResultsList({
    super.key,
    required this.isDark,
    required this.searchResults,
    required this.isSearching,
    this.onGenreTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloading = ref.watch(downloadingSongsProvider);
    final repo = ref.watch(musicRepositoryProvider);
    final currentSong = ref.watch(currentSongStreamProvider).value;

    if (isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: isDark ? Colors.white : Colors.black, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Aggregating Spotify, Apple, JioSaavn & Lyric Catalogs...', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      final globalGenres = [
        {'title': 'Trending Global Hits', 'category': 'Vibes', 'query': 'Today Top Hits Billboard Hot 100', 'icon': Icons.trending_up_rounded},
        {'title': 'Bollywood & Desi Top Hits', 'category': 'Regional', 'query': 'Bollywood Butter Arijit Singh Pritam', 'icon': Icons.music_video_rounded},
        {'title': 'Synthwave & Retrowave', 'category': 'Electronic', 'query': 'Synthwave Retrowave 80s Cyberpunk Night Drive', 'icon': Icons.grid_goldenratio_rounded},
        {'title': 'Sufi & Qawwali Mysticism', 'category': 'Regional', 'query': 'Nusrat Fateh Ali Khan Rahat Sufi Coke Studio', 'icon': Icons.flare_rounded},
        {'title': 'Punjabi & Desi Hip-Hop', 'category': 'Regional', 'query': 'Sidhu Moosewala Karan Aujla AP Dhillon', 'icon': Icons.flash_on_rounded},
        {'title': 'Late Night Lo-Fi Chill', 'category': 'Vibes', 'query': 'Lofi Chill Study Beats Night Relax', 'icon': Icons.nightlight_round},
        {'title': 'Acoustic & Unplugged', 'category': 'Acoustic', 'query': 'Acoustic Guitar Warmth Folk Singer Songwriter', 'icon': Icons.music_note_rounded},
        {'title': 'Drift Phonk & Velocity', 'category': 'Electronic', 'query': 'Drift Phonk Wave Memphis Slowed Reverb', 'icon': Icons.speed_rounded},
        {'title': 'Global Pop & R&B Anthems', 'category': 'Vibes', 'query': 'The Weeknd Starboy Drake Pop Hits', 'icon': Icons.bolt_rounded},
        {'title': 'Smooth Midnight Jazz', 'category': 'Acoustic', 'query': 'Smooth Jazz Midnight Saxophone Coffeehouse Blues', 'icon': Icons.local_bar_rounded},
        {'title': 'Latin Reggaeton Fiesta', 'category': 'Regional', 'query': 'Bad Bunny Latin Pop Reggaeton Hits', 'icon': Icons.celebration_rounded},
        {'title': 'K-Pop & Asian Pop Wave', 'category': 'Regional', 'query': 'BTS Blackpink NewJeans KPop Top Hits', 'icon': Icons.favorite_rounded},
        {'title': 'Deep House & Club EDM', 'category': 'Electronic', 'query': 'Deep House Electronic Dance Sunset Club', 'icon': Icons.speaker_group_rounded},
        {'title': 'Cinematic Epic Soundtracks', 'category': 'Acoustic', 'query': 'Hans Zimmer Epic Cinematic Orchestral Score', 'icon': Icons.movie_filter_rounded},
        {'title': 'Ambient Zen & Meditation', 'category': 'Vibes', 'query': 'Ambient Atmospheric Space Meditation Sleep', 'icon': Icons.spa_rounded},
        {'title': 'French Chanson & Café', 'category': 'Regional', 'query': 'French Cafe Accordion Chanson Vintage Paris', 'icon': Icons.coffee_rounded},
      ];

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Explore Global Catalogs & Genres',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${globalGenres.length} Catalogs',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: globalGenres.length,
            itemBuilder: (context, idx) {
              final g = globalGenres[idx];
              return GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                onTap: () => onGenreTap?.call(g['query'] as String),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(g['icon'] as IconData, size: 20, color: isDark ? Colors.white : Colors.black),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            g['category'] as String,
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      g['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    }

    final topArtist = searchResults.first.artist;
    final topArtistImg = searchResults.first.artworkUrl;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: searchResults.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => ArtistScreen(artistName: topArtist, artistImageUrl: topArtistImg))),
              child: Row(
                children: [
                  CircleAvatar(radius: 22, backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFDCDCDC), backgroundImage: topArtistImg != null ? NetworkImage(topArtistImg) : null, child: topArtistImg == null ? Icon(Icons.person_rounded, color: isDark ? Colors.white70 : Colors.black87) : null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Flexible(child: Text(topArtist, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 4), Icon(Icons.verified_rounded, size: 14, color: isDark ? Colors.white70 : Colors.black87)]),
                        const SizedBox(height: 2),
                        Text('Official Artist Profile • Explore discography & creations', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                ],
              ),
            ),
          );
        }

        final song = searchResults[i - 1];
        final isDownloaded = song.isDownloaded || repo.downloads.any((d) => d.id == song.id);
        final isDownloadingThis = downloading.contains(song.id);
        final isCurrent = currentSong?.id == song.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: 14,
            isHighlighted: isCurrent,
            padding: const EdgeInsets.all(10),
            onTap: () => ref.read(audioPlayerServiceProvider).playSong(song),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    song.artworkUrl ?? '',
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    cacheWidth: 150,
                    cacheHeight: 150,
                    errorBuilder: (c, e, st) => Container(width: 46, height: 46, color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5), child: Icon(Icons.music_note_rounded, color: isDark ? Colors.white54 : Colors.black54)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(child: Text('${song.artist} • ${song.album.isNotEmpty ? song.album : "Lossless"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary))),
                          if (song.id.startsWith('jio_') || (song.genre?.contains('320k') ?? false)) ...[
                            const SizedBox(width: 4),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(4)), child: Text('320k', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87))),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.playlist_add_rounded, size: 21, color: isDark ? Colors.white70 : Colors.black87),
                  tooltip: 'Add to Folder',
                  onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AddToFolderSheet(song: song)),
                ),
                IconButton(
                  icon: Icon(Icons.radar_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                  tooltip: 'AI Similarity Radio',
                  onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AIRadioSheet(seedSong: song)),
                ),
                IconButton(
                  icon: isDownloadingThis
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black))
                      : Icon(isDownloaded ? Icons.check_circle_outline_rounded : Icons.download_rounded, size: 21, color: isDownloaded ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white60 : Colors.black54)),
                  onPressed: (isDownloaded || isDownloadingThis)
                      ? null
                      : () async {
                          ref.read(downloadingSongsProvider.notifier).update((s) => {...s, song.id});
                          try {
                            final downloaded = await MusicService.downloadTrack(song);
                            if (downloaded != null) {
                              repo.addDownloadedSong(downloaded);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved "${song.title}" to Downloads'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFF333333),
                                  ),
                                );
                              }
                            }
                          } finally {
                            ref.read(downloadingSongsProvider.notifier).update((s) => {...s}..remove(song.id));
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
