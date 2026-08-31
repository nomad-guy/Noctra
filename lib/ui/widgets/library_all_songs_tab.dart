import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import 'glass_card.dart';
import 'add_to_folder_sheet.dart';

class LibraryAllSongsTab extends ConsumerWidget {
  final bool isDark;
  final MusicRepository repo;
  final List<Song> allSongs;
  final List<Song> downloads;
  final Map<String, List<Song>> customFolders;

  const LibraryAllSongsTab({
    super.key,
    required this.isDark,
    required this.repo,
    required this.allSongs,
    required this.downloads,
    required this.customFolders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    final List<Song> displaySongs;
    if (downloads.isEmpty) {
      displaySongs = allSongs;
    } else if (allSongs.isEmpty) {
      displaySongs = downloads;
    } else {
      final seen = <String>{};
      final list = <Song>[];
      for (final s in downloads) {
        if (seen.add(s.id)) list.add(s);
      }
      for (final s in allSongs) {
        if (seen.add(s.id)) list.add(s);
      }
      displaySongs = list;
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Storage & Status Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassCard(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    child: Icon(Icons.download_done_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${displaySongs.length} Tracks in Master Library',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                        ),
                        Text(
                          '${downloads.length} Downloaded Offline • High-Fidelity 320k Ready',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        if (displaySongs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_for_offline_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 14),
                    Text('No Offline Tracks Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 6),
                    Text('Songs you download will appear here for instant offline 320kbps playback.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = displaySongs[i];
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
                              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
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
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
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
                                  color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
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
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(value: p, strokeWidth: 2, color: isDark ? Colors.white70 : Colors.black87)),
                              );
                            }
                            if (s.isDownloaded || s.localFilePath != null) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.download_done_rounded, size: 18, color: isDark ? Colors.greenAccent.shade200 : Colors.green.shade700),
                              );
                            }
                            return IconButton(
                              icon: Icon(Icons.download_rounded, size: 19, color: isDark ? Colors.white60 : Colors.black54),
                              tooltip: 'Download Offline',
                              onPressed: () async {
                                ref.read(downloadingSongsProvider.notifier).update((set) => {...set, s.id});
                                final dl = await MusicService.downloadTrack(s);
                                if (dl != null) {
                                  ref.read(musicRepositoryProvider).addDownloadedSong(dl);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Downloaded "${s.title}"'), duration: const Duration(seconds: 2)),
                                    );
                                  }
                                }
                                ref.read(downloadingSongsProvider.notifier).update((set) => {...set}..remove(s.id));
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.playlist_add_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                          tooltip: 'Add to Folder',
                          onPressed: () => showModalBottomSheet(context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AddToFolderSheet(song: s)),
                        ),
                        if (isCurrent && isPlaying)
                          Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                );
              },
              childCount: displaySongs.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 160)),
      ],
    );
  }
}
