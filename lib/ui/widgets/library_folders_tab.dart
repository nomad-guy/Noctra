import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../providers/app_providers.dart';
import 'glass_card.dart';

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
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xF40E0E0E) : const Color(0xF4FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: widget.isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Delete Folder', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text('Delete "$folderName"? Tracks will remain in your downloads and library.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: widget.isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.repo.deleteFolder(folderName);
                        });
                      },
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_openedFolder != null) {
      final folderSongs = widget.repo.customFolders[_openedFolder] ?? widget.customFolders[_openedFolder] ?? [];
      return _buildFolderDetailView(_openedFolder!, folderSongs);
    }

    final folderNames = (widget.repo.customFolders.isNotEmpty ? widget.repo.customFolders : widget.customFolders).keys.toList();
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isDark ? Colors.white : Colors.black),
                            child: Icon(Icons.create_new_folder_outlined, size: 20, color: widget.isDark ? Colors.black : Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('+ Create New Folder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                                Text('Organize tracks into custom playlists', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.isDark ? Colors.white38 : Colors.black38),
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
                        Text('Create New Folder', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _folderNameCtrl,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Folder name (e.g. Late Night, Sufi)',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                style: TextStyle(fontSize: 13.5, color: widget.isDark ? Colors.white : Colors.black),
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
                                backgroundColor: widget.isDark ? Colors.white : Colors.black,
                                foregroundColor: widget.isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _submitCreateFolder,
                              child: const Text('Create', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
                final folderSongs = widget.customFolders[folderName] ?? [];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    radius: 14,
                    padding: const EdgeInsets.all(12),
                    onTap: () => setState(() => _openedFolder = folderName),
                    onLongPress: folderName != 'Favorites' ? () => _confirmDeleteFolder(folderName) : null,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: widget.isDark ? const Color(0xFF161616) : const Color(0xFFE5E5E5),
                          ),
                          child: Icon(folderName == 'Favorites' ? Icons.favorite_rounded : Icons.folder_rounded, size: 24, color: widget.isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(folderName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                              Text('${folderSongs.length} tracks • Long-press to delete', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.isDark ? Colors.white38 : Colors.black38),
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

  Widget _buildFolderDetailView(String folderName, List<Song> folderSongs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: widget.isDark ? Colors.white : Colors.black),
                onPressed: () => setState(() => _openedFolder = null),
              ),
              Expanded(
                child: Text(folderName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
              ),
            ],
          ),
        ),
        Expanded(
          child: folderSongs.isEmpty
              ? Center(child: Text('No tracks in this folder yet.', style: TextStyle(fontSize: 12.5, color: widget.isDark ? Colors.white38 : Colors.black38)))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
                  itemCount: folderSongs.length,
                  itemBuilder: (context, i) {
                    final s = folderSongs[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(s.artworkUrl ?? '', width: 44, height: 44, cacheWidth: 130, cacheHeight: 130, fit: BoxFit.cover, errorBuilder: (c, e, st) => Container(width: 44, height: 44, color: widget.isDark ? Colors.white12 : Colors.black12)),
                      ),
                      title: Text(s.title, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black)),
                      subtitle: Text(s.artist, maxLines: 1, style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54)),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: widget.isDark ? Colors.white54 : Colors.black54),
                        onPressed: () => widget.repo.removeSongFromFolder(folderName, s.id),
                      ),
                      onTap: () => ref.read(audioPlayerServiceProvider).playSong(s),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
