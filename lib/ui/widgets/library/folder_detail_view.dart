import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/metadata/song_artwork_resolver.dart';
import '../noir_mini_player_dock.dart';

/// Full-screen track list shown when a folder (or Favorites) is opened from
/// [LibraryFoldersTab]. Pushed over the tabbed shell, owns its own back
/// navigation via Navigator / [onBack], and docks the floating mini player.
class FolderDetailView extends ConsumerStatefulWidget {
  final bool isDark;
  final MusicRepository repo;
  final String folderName;
  final List<Song> songs;
  final VoidCallback? onBack;

  const FolderDetailView({
    super.key,
    required this.isDark,
    required this.repo,
    required this.folderName,
    required this.songs,
    this.onBack,
  });

  @override
  ConsumerState<FolderDetailView> createState() => _FolderDetailViewState();
}

class _FolderDetailViewState extends ConsumerState<FolderDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enrichMissingArtwork();
    });
  }

  void _enrichMissingArtwork() {
    final repo = ref.read(musicRepositoryProvider);
    final songs = widget.folderName == 'Favorites'
        ? repo.favorites
        : (repo.customFolders[widget.folderName] ?? widget.songs);
    final missing = songs
        .where((s) => s.artworkUrl == null || s.artworkUrl!.isEmpty)
        .toList();
    if (missing.isEmpty) return;

    for (final song in missing) {
      SongArtworkResolver.resolveArtwork(song).then((art) {
        if (art != null && art.isNotEmpty && mounted) {
          final updated = song.copyWith(artworkUrl: art);
          ref.read(musicRepositoryProvider).updateSongMetadata(updated);
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(musicRepositoryProvider);
    final currentSongs = widget.folderName == 'Favorites'
        ? repo.favorites
        : (repo.customFolders[widget.folderName] ?? widget.songs);
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF070709) : const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black),
                        onPressed: () {
                          if (widget.onBack != null) {
                            widget.onBack!();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          widget.folderName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentSongs.isEmpty
                      ? Center(
                          child: Text(
                            context.tr(L10nKeys.folderEmpty),
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
                          itemCount: currentSongs.length,
                          itemBuilder: (context, i) {
                            final s = currentSongs[i];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  s.artworkUrl ?? '',
                                  width: 44,
                                  height: 44,
                                  cacheWidth: 130,
                                  cacheHeight: 130,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, st) => Container(
                                    width: 44,
                                    height: 44,
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                s.artist,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                                onPressed: () {
                                  repo.removeSongFromFolder(
                                      widget.folderName, s.id);
                                  setState(() {});
                                },
                              ),
                              onTap: () => ref
                                  .read(audioPlayerServiceProvider)
                                  .playSong(
                                    s,
                                    newQueue: currentSongs,
                                    queueIndex: i,
                                  ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerDock(),
          ),
        ],
      ),
    );
  }
}
