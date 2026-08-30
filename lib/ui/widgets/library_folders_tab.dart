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

  @override
  Widget build(BuildContext context) {
    if (_openedFolder != null) {
      final folderSongs = widget.customFolders[_openedFolder] ?? [];
      return _buildFolderDetailView(_openedFolder!, folderSongs);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Create Action
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GestureDetector(
              onTap: _showCreateFolderDialog,
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
                final folderName = widget.customFolders.keys.elementAt(i);
                final folderSongs = widget.customFolders[folderName] ?? [];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    radius: 14,
                    padding: const EdgeInsets.all(12),
                    onTap: () => setState(() => _openedFolder = folderName),
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
                              Text('${folderSongs.length} tracks in collection', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.isDark ? Colors.white38 : Colors.black38),
                      ],
                    ),
                  ),
                );
              },
              childCount: widget.customFolders.keys.length,
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
                  itemCount: folderSongs.length,
                  itemBuilder: (context, i) {
                    final s = folderSongs[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(s.artworkUrl ?? '', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (c, e, st) => Container(width: 44, height: 44, color: Colors.grey)),
                      ),
                      title: Text(s.title, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black)),
                      subtitle: Text(s.artist, maxLines: 1, style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54)),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: widget.isDark ? Colors.white54 : Colors.black54),
                        onPressed: () {
                          widget.repo.removeSongFromFolder(folderName, s.id);
                          setState(() {});
                        },
                      ),
                      onTap: () => ref.read(audioPlayerServiceProvider).playSong(s),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF141414) : Colors.white,
        title: Text('Create Folder', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Folder Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                widget.repo.createFolder(val);
                setState(() {});
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
