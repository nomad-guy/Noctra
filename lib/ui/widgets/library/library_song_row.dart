import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
import '../add_to_folder_sheet.dart';
import '../../../shared/widgets/glass_card.dart';

/// One library row. Subscribes to playback state locally so play/pause
/// toggles and track changes only rebuild the visible rows — the tab's
/// sliver list and its (potentially large) displaySongs merge are untouched.
class LibrarySongRow extends ConsumerWidget {
  final Song song;
  final bool isDark;
  final MusicRepository repo;

  const LibrarySongRow({
    super.key,
    required this.song,
    required this.isDark,
    required this.repo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final s = song;
    final isCurrent = currentSong?.id == s.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 14,
        isHighlighted: isCurrent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () {
          ref.read(audioPlayerServiceProvider).playSong(s);
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                s.artworkUrl ?? '',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                cacheWidth: 150,
                cacheHeight: 150,
                errorBuilder: (c, e, st) => Container(
                  width: 44,
                  height: 44,
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFE0E0E0),
                  child: Icon(Icons.music_note_rounded,
                      color: isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NoirColors.blackTextSecondary
                          : NoirColors.whiteTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<Map<String, double>>(
              stream: MusicService.downloadProgressStream,
              builder: (context, snap) {
                final p = snap.data?[s.id];
                if (p != null && p < 1.0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: p,
                        strokeWidth: 2,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }
                if (s.isDownloaded || s.localFilePath != null) {
                  final isRealDownload =
                      repo.downloads.any((d) => d.id == s.id);
                  if (!isRealDownload) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.download_done_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.greenAccent.shade200
                              : Colors.green.shade700),
                    );
                  }
                  return IconButton(
                    icon: Icon(Icons.download_done_rounded,
                        size: 19,
                        color: isDark
                            ? Colors.greenAccent.shade200
                            : Colors.green.shade700),
                    tooltip: 'Remove download',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove download?'),
                          content: Text(
                              '"${s.title}" will be removed from offline playback.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await repo.removeDownloadedSong(s.id);
                      }
                    },
                  );
                }
                return IconButton(
                  icon: Icon(Icons.download_rounded,
                      size: 19,
                      color: isDark ? Colors.white60 : Colors.black54),
                  tooltip: 'Download Offline',
                  onPressed: () async {
                    ref
                        .read(downloadingSongsProvider.notifier)
                        .update((set) => {...set, s.id});
                    final dl = await MusicService.downloadTrack(s);
                    if (dl != null) {
                      ref
                          .read(musicRepositoryProvider)
                          .addDownloadedSong(dl);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloaded "${s.title}"'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                    ref
                        .read(downloadingSongsProvider.notifier)
                        .update((set) => {...set}..remove(s.id));
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.playlist_add_rounded,
                  size: 20, color: isDark ? Colors.white70 : Colors.black87),
              tooltip: 'Add to Folder',
              onPressed: () => showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddToFolderSheet(song: s),
              ),
            ),
            if (isCurrent && isPlaying)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
