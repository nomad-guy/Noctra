import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import 'glass_card.dart';
import 'add_to_folder_sheet.dart';
import 'ai_radio_sheet.dart';

class SearchResultsList extends ConsumerWidget {
  final bool isDark;
  final List<Song> searchResults;
  final bool isSearching;

  const SearchResultsList({
    super.key,
    required this.isDark,
    required this.searchResults,
    required this.isSearching,
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
            Text(
              'Searching 320kbps CD & Lossless Catalogs...',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 40, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 12),
              Text(
                'Search for songs, artists, albums, or vibes above.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: searchResults.length,
      itemBuilder: (context, i) {
        final song = searchResults[i];
        final isDownloaded = song.isDownloaded || repo.downloads.any((d) => d.id == song.id);
        final isDownloadingThis = downloading.contains(song.id);
        final isCurrent = currentSong?.id == song.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: 14,
            isHighlighted: isCurrent,
            padding: const EdgeInsets.all(10),
            onTap: () {
              ref.read(audioPlayerServiceProvider).playSong(song);
            },
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
                    errorBuilder: (c, e, st) => Container(
                      width: 46,
                      height: 46,
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                      child: Icon(Icons.music_note_rounded, color: isDark ? Colors.white54 : Colors.black54),
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
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${song.artist} • ${song.album.isNotEmpty ? song.album : "320k Lossless"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.playlist_add_rounded, size: 21, color: isDark ? Colors.white70 : Colors.black87),
                  tooltip: 'Add to Folder',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddToFolderSheet(song: song),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.radar_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                  tooltip: 'AI Similarity Radio',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AIRadioSheet(seedSong: song),
                    );
                  },
                ),
                IconButton(
                  icon: isDownloadingThis
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black))
                      : Icon(
                          isDownloaded ? Icons.check_circle_outline_rounded : Icons.download_rounded,
                          size: 21,
                          color: isDownloaded ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white60 : Colors.black54),
                        ),
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
