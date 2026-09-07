import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/metadata/song_artwork_resolver.dart';
import '../../../services/ai/ai_mix_track_source.dart';
import '../noir_mini_player_dock.dart';
import 'ai_collection_action_bar.dart';
import 'export_playlist_sheet.dart';
import 'folder_recommendations_footer.dart';

enum _FolderSortOption {
  defaultOrder,
  titleAZ,
  artistAZ,
  durationLongest,
  durationShortest,
}

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
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _FolderSortOption _sortOption = _FolderSortOption.defaultOrder;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enrichMissingArtwork();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Song> _getDisplaySongs(List<Song> source) {
    var list = List<Song>.of(source);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) => s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
    }
    switch (_sortOption) {
      case _FolderSortOption.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _FolderSortOption.artistAZ:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case _FolderSortOption.durationLongest:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case _FolderSortOption.durationShortest:
        list.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case _FolderSortOption.defaultOrder:
        break;
    }
    return list;
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

  int _remixEpoch = 0;

  void _playAll(List<Song> songs) {
    if (songs.isEmpty) return;
    ref
        .read(audioPlayerServiceProvider)
        .playSong(songs.first, newQueue: List<Song>.of(songs));
  }

  void _shuffle(List<Song> songs) {
    if (songs.isEmpty) return;
    final shuffled = List<Song>.of(songs)..shuffle();
    ref
        .read(audioPlayerServiceProvider)
        .playSong(shuffled.first, newQueue: shuffled);
  }

  void _remix(List<Song> songs) {
    if (songs.length < 2) return;
    _remixEpoch++;
    final remixed = AiMixTrackSource.applyRemixOrder(
      songs,
      epoch: _remixEpoch,
      vibeKey: widget.folderName,
    );
    if (widget.folderName != 'Favorites') {
      widget.repo.reorderFolderSongs(widget.folderName, remixed);
    }
    _playAll(remixed);
  }

  void _export(List<Song> songs) {
    if (songs.isEmpty) return;
    ExportPlaylistSheet.show(
      context,
      title: widget.folderName,
      tracks: songs,
      isDark: widget.isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(musicRepositoryProvider);
    final currentSongs = widget.folderName == 'Favorites'
        ? repo.favorites
        : (repo.customFolders[widget.folderName] ?? widget.songs);
    final isDark = widget.isDark;

    final displaySongs = _getDisplaySongs(currentSongs);

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
                      IconButton(
                        icon: Icon(
                          _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                          color: isDark ? Colors.white70 : Colors.black87,
                          size: 20,
                        ),
                        tooltip: 'Search tracks in playlist',
                        onPressed: () {
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchCtrl.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),
                      PopupMenuButton<_FolderSortOption>(
                        icon: Icon(
                          Icons.sort_rounded,
                          color: isDark ? Colors.white70 : Colors.black87,
                          size: 20,
                        ),
                        tooltip: 'Sort playlist',
                        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                        onSelected: (opt) => setState(() => _sortOption = opt),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _FolderSortOption.defaultOrder,
                            child: Text('Default (Added Order)'),
                          ),
                          const PopupMenuItem(
                            value: _FolderSortOption.titleAZ,
                            child: Text('Title (A to Z)'),
                          ),
                          const PopupMenuItem(
                            value: _FolderSortOption.artistAZ,
                            child: Text('Artist (A to Z)'),
                          ),
                          const PopupMenuItem(
                            value: _FolderSortOption.durationLongest,
                            child: Text('Duration (Longest first)'),
                          ),
                          const PopupMenuItem(
                            value: _FolderSortOption.durationShortest,
                            child: Text('Duration (Shortest first)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Filter in "${widget.folderName}"...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                AiCollectionActionBar(
                  isDark: isDark,
                  canRemix: currentSongs.length >= 2,
                  busy: false,
                  hasTracks: currentSongs.isNotEmpty,
                  onPlayAll: () => _playAll(displaySongs),
                  onShuffle: () => _shuffle(displaySongs),
                  onRemix: () => _remix(currentSongs),
                  onExport: () => _export(currentSongs),
                ),
                const SizedBox(height: 8),
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
                          itemCount: displaySongs.length + 1,
                          itemBuilder: (context, i) {
                            if (i == displaySongs.length) {
                              return FolderRecommendationsFooter(
                                folderName: widget.folderName,
                                playlistSongs: currentSongs,
                                isDark: isDark,
                              );
                            }
                            final s = displaySongs[i];
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
                                    newQueue: displaySongs,
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
