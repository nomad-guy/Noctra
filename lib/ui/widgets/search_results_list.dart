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
      final genres = [
        {'title': 'Sufi & Qawwali', 'query': 'Nusrat Fateh Ali Khan Sufi Coke Studio', 'icon': Icons.flare_rounded, 'color': const Color(0xFF1E140A)},
        {'title': 'Synthwave & Outrun', 'query': 'Synthwave Retrowave 80s Cyberpunk', 'icon': Icons.grid_goldenratio_rounded, 'color': const Color(0xFF140A1E)},
        {'title': 'Pakistani & Indian Indie', 'query': 'Hassan & Roshaan Pakistani Indie Pop', 'icon': Icons.mic_rounded, 'color': const Color(0xFF0A141E)},
        {'title': 'Late Night Lo-Fi', 'query': 'Lofi Chill Study Beats Night', 'icon': Icons.nightlight_round, 'color': const Color(0xFF0A1E14)},
        {'title': 'Global Pop & R&B', 'query': 'The Weeknd Starboy Pop Top Hits', 'icon': Icons.bolt_rounded, 'color': const Color(0xFF1E0A14)},
        {'title': 'Acoustic & Unplugged', 'query': 'Acoustic Guitar Warmth Folk', 'icon': Icons.music_note_rounded, 'color': const Color(0xFF1E1E0A)},
      ];

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text('Explore Global Catalogs & Genres', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: genres.length,
            itemBuilder: (context, idx) {
              final g = genres[idx];
              return GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                onTap: () => onGenreTap?.call(g['query'] as String),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(g['icon'] as IconData, size: 22, color: isDark ? Colors.white : Colors.black),
                    Text(g['title'] as String, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
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
                          if (song.id.startsWith('jio_') || song.genre.contains('320k')) ...[
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
                          final downloaded = await MusicService.downloadTrack(song);
                          repo.addDownloadedSong(downloaded ?? song);
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
