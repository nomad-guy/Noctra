import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
import '../../../shared/widgets/glass_card.dart';

class ArtistTrackTile extends ConsumerWidget {
  final Song song;
  final List<Song> allTracks;
  final bool isCurrent;
  final bool isDark;

  const ArtistTrackTile({
    super.key,
    required this.song,
    required this.allTracks,
    required this.isCurrent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlayer = ref.watch(audioPlayerServiceProvider);
    final repo = ref.watch(musicRepositoryProvider);
    final isDownloaded =
        repo.downloads.any((s) => s.id == song.id) || song.isDownloaded;
    final downloadingSet = ref.watch(downloadingSongsProvider);
    final isDownloading = downloadingSet.contains(song.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 14,
        isHighlighted: isCurrent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => audioPlayer.playSong(song, newQueue: allTracks),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                song.artworkUrl ?? '',
                width: 42,
                height: 42,
                cacheWidth: 100,
                cacheHeight: 100,
                fit: BoxFit.cover,
                errorBuilder: (c, e, st) => Container(
                  width: 42,
                  height: 42,
                  color: Colors.grey,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black87),
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: isDownloaded
                  ? const Icon(Icons.check_circle_rounded,
                      size: 18, color: Colors.greenAccent)
                  : isDownloading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        )
                      : Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
              onPressed: isDownloaded || isDownloading
                  ? null
                  : () async {
                      final res = await MusicService.downloadTrack(song);
                      if (res != null) {
                        repo.addDownloadedSong(res);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloaded "${song.title}"'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
