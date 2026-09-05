import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../shared/widgets/glass_card.dart';

import 'library/library_song_row.dart';
import 'swipeable_song_tile.dart';

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
                    child: Icon(Icons.download_done_rounded,
                        size: 20, color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(L10nKeys.tracksCount, {'count': displaySongs.length.toString()}),
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                        Text(
                          context.tr(L10nKeys.downloadedOffline, {'count': downloads.length.toString()}),
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54),
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
                    Icon(Icons.download_for_offline_outlined,
                        size: 48,
                        color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 14),
                    Text(context.tr(L10nKeys.noOfflineTracks),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(L10nKeys.offlineTracksHint),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ),
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
                  return SwipeableSongTile(
                    song: s,
                    child: LibrarySongRow(
                      song: s,
                      isDark: isDark,
                      repo: repo,
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
