import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
import '../ai_radio_sheet.dart';
import '../../../shared/widgets/glass_card.dart';
import '../song_context_menu.dart';

class SearchTrackTile extends ConsumerWidget {
  final Song song;
  final bool isCurrent;
  final bool isDark;

  const SearchTrackTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloading = ref.watch(downloadingSongsProvider);
    final repo = ref.watch(musicRepositoryProvider);
    final isDownloaded =
        song.isDownloaded || repo.downloads.any((d) => d.id == song.id);
    final isDownloadingThis = downloading.contains(song.id);

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
                errorBuilder: (c, e, st) => Container(
                  width: 46,
                  height: 46,
                  color:
                      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${song.artist} • ${song.album.isNotEmpty ? song.album : "Lossless"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? NoirColors.blackTextSecondary
                                : NoirColors.whiteTextSecondary,
                          ),
                        ),
                      ),
                      if (song.id.startsWith('jio_') ||
                          (song.genre?.contains('320k') ?? false)) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '320k',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 21,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              tooltip: 'More Options',
              onPressed: () => SongContextMenu.show(context, song),
            ),
            IconButton(
              icon: Icon(
                Icons.radar_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              tooltip: 'AI Similarity Radio',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AIRadioSheet(seedSong: song),
              ),
            ),
            IconButton(
              icon: isDownloadingThis
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  : Icon(
                      isDownloaded
                          ? Icons.check_circle_outline_rounded
                          : Icons.download_rounded,
                      size: 21,
                      color: isDownloaded
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
              onPressed: (isDownloaded || isDownloadingThis)
                  ? null
                  : () async {
                      ref
                          .read(downloadingSongsProvider.notifier)
                          .update((s) => {...s, song.id});
                      try {
                        final downloaded =
                            await MusicService.downloadTrack(song);
                        if (downloaded != null) {
                          repo.addDownloadedSong(downloaded);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Saved "${song.title}" to Downloads'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: isDark
                                    ? const Color(0xFF222222)
                                    : const Color(0xFF333333),
                              ),
                            );
                          }
                        }
                      } finally {
                        ref
                            .read(downloadingSongsProvider.notifier)
                            .update((s) => {...s}..remove(song.id));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
