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
import 'folder_detail_header.dart';
import 'folder_detail_track_tile.dart';
import 'folder_recommendations_footer.dart';

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
  FolderSortOption _sortOption = FolderSortOption.defaultOrder;
  int _remixEpoch = 0;

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
      case FolderSortOption.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case FolderSortOption.artistAZ:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case FolderSortOption.durationLongest:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case FolderSortOption.durationShortest:
        list.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case FolderSortOption.defaultOrder:
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
                FolderDetailHeader(
                  folderName: widget.folderName,
                  isDark: isDark,
                  showSearch: _showSearch,
                  sortOption: _sortOption,
                  searchCtrl: _searchCtrl,
                  searchQuery: _searchQuery,
                  onBack: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  onToggleSearch: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchCtrl.clear();
                        _searchQuery = '';
                      }
                    });
                  },
                  onSortSelected: (opt) => setState(() => _sortOption = opt),
                  onClearSearch: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
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
                            return FolderDetailTrackTile(
                              song: s,
                              isDark: isDark,
                              onRemove: () {
                                repo.removeSongFromFolder(
                                    widget.folderName, s.id);
                                setState(() {});
                              },
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
