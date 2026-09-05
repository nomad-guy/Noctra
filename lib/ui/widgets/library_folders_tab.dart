import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../shared/widgets/glass_card.dart';

import 'library/folder_delete_sheet.dart';
import 'library/folder_detail_view.dart';

class LibraryFoldersTab extends ConsumerStatefulWidget {
  final bool isDark;
  final MusicRepository repo;
  final Map<String, List<Song>> customFolders;
  final List<Song> allSongs;

  const LibraryFoldersTab({
    super.key,
    required this.isDark,
    required this.repo,
    required this.customFolders,
    required this.allSongs,
  });

  @override
  ConsumerState<LibraryFoldersTab> createState() => _LibraryFoldersTabState();
}

class _LibraryFoldersTabState extends ConsumerState<LibraryFoldersTab> {
  String? _openedFolder;
  bool _isCreatingFolder = false;
  final TextEditingController _folderNameCtrl = TextEditingController();

  @override
  void dispose() {
    _folderNameCtrl.dispose();
    super.dispose();
  }

  void _submitCreateFolder() {
    final name = _folderNameCtrl.text.trim();
    if (name.isNotEmpty) {
      widget.repo.createFolder(name);
      _folderNameCtrl.clear();
      setState(() => _isCreatingFolder = false);
    }
  }

  void _confirmDeleteFolder(String folderName) {
    if (folderName == 'Favorites') return;
    showFolderDeleteSheet(
      context,
      isDark: widget.isDark,
      folderName: folderName,
      onDelete: () => widget.repo.deleteFolder(folderName),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_openedFolder != null) {
      final folderSongs = _openedFolder == 'Favorites'
          ? widget.repo.favorites
          : (widget.repo.customFolders[_openedFolder] ??
              widget.customFolders[_openedFolder] ??
              []);
      return FolderDetailView(
        isDark: widget.isDark,
        repo: widget.repo,
        folderName: _openedFolder!,
        songs: folderSongs,
        onBack: () => setState(() => _openedFolder = null),
      );
    }

    // Build folder list: Favorites first (if has songs), then custom folders
    final customFolderNames = (widget.repo.customFolders.isNotEmpty
            ? widget.repo.customFolders
            : widget.customFolders)
        .keys
        .toList();
    final folderNames = <String>['Favorites', ...customFolderNames];
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Create Action
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: !_isCreatingFolder
                ? GestureDetector(
                    onTap: () => setState(() => _isCreatingFolder = true),
                    child: GlassCard(
                      radius: 16,
                      isHighlighted: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black),
                            child: Icon(Icons.create_new_folder_outlined,
                                size: 20,
                                color: widget.isDark
                                    ? Colors.black
                                    : Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('+ Create New Folder',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: widget.isDark
                                            ? Colors.white
                                            : Colors.black)),
                                Text('Organize tracks into custom playlists',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: widget.isDark
                                            ? Colors.white54
                                            : Colors.black54)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.black38),
                        ],
                      ),
                    ),
                  )
                : GlassCard(
                    radius: 16,
                    isHighlighted: true,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create New Folder',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _folderNameCtrl,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Folder name (e.g. Late Night, Sufi)',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black),
                                onSubmitted: (_) => _submitCreateFolder(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Cancel',
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => setState(() {
                                _folderNameCtrl.clear();
                                _isCreatingFolder = false;
                              }),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    widget.isDark ? Colors.white : Colors.black,
                                foregroundColor:
                                    widget.isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _submitCreateFolder,
                              child: const Text('Create',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // Folder List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final folderName = folderNames[i];
                final folderSongs = folderName == 'Favorites'
                    ? widget.repo.favorites
                    : (widget.customFolders[folderName] ?? []);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    radius: 14,
                    padding: const EdgeInsets.all(12),
                    onTap: () => setState(() => _openedFolder = folderName),
                    onLongPress: folderName != 'Favorites'
                        ? () => _confirmDeleteFolder(folderName)
                        : null,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: widget.isDark
                                ? const Color(0xFF161616)
                                : const Color(0xFFE5E5E5),
                          ),
                          child: Icon(
                              folderName == 'Favorites'
                                  ? Icons.favorite_rounded
                                  : Icons.folder_rounded,
                              size: 24,
                              color:
                                  widget.isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(folderName,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isDark
                                          ? Colors.white
                                          : Colors.black)),
                              Text(
                                  '${folderSongs.length} tracks • Long-press to delete',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: widget.isDark
                                          ? Colors.white54
                                          : Colors.black54)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: widget.isDark
                                ? Colors.white38
                                : Colors.black38),
                      ],
                    ),
                  ),
                );
              },
              childCount: folderNames.length,
            ),
          ),
        ),
      ],
    );
  }

}
