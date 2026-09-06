import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ai_folder_model.dart';
import '../../data/repositories/music_repository.dart';
import 'library/ai_collection_detail_view.dart';
import 'library/library_ai_mixes_content.dart';

class LibraryAIMixesTab extends ConsumerStatefulWidget {
  final bool isDark;
  final MusicRepository repo;
  const LibraryAIMixesTab(
      {super.key, required this.isDark, required this.repo});
  @override
  ConsumerState<LibraryAIMixesTab> createState() => _LibraryAIMixesTabState();
}

class _LibraryAIMixesTabState extends ConsumerState<LibraryAIMixesTab>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastOpenTime;

  @override
  bool get wantKeepAlive => true;

  Future<void> _openMix(AIPlaylist playlist) => _open(
        title: playlist.title,
        subtitle: playlist.subtitle,
        artworkUrl: playlist.artworkUrl,
        vibeKey: playlist.vibeKey,
        initialTracks: playlist.tracks,
      );

  Future<void> _openFolder(AIFolder folder) => _open(
        title: folder.name,
        subtitle: folder.description,
        icon: folder.icon,
        vibeKey: folder.vibeKey,
      );

  Future<void> _open({
    required String title,
    required String subtitle,
    required String vibeKey,
    String? artworkUrl,
    IconData? icon,
    List<dynamic>? initialTracks,
  }) async {
    final now = DateTime.now();
    if (_lastOpenTime != null &&
        now.difference(_lastOpenTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastOpenTime = now;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiCollectionDetailView(
        isDark: widget.isDark,
        repo: widget.repo,
        title: title,
        subtitle: subtitle,
        artworkUrl: artworkUrl,
        icon: icon,
        vibeKey: vibeKey,
        initialTracks: initialTracks?.cast() ?? const [],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LibraryAiMixesContent(
      isDark: widget.isDark,
      mixes: widget.repo.getAIGeneratedPlaylists(),
      folders: widget.repo.getAICuratedFolders(),
      topArtists: widget.repo.getTopArtists(limit: 5),
      archetype: widget.repo.getUserMusicalArchetype(),
      onOpenMix: _openMix,
      onOpenFolder: _openFolder,
    );
  }
}
