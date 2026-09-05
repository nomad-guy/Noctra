import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';

/// Track list shown when a folder (or Favorites) is opened from
/// [LibraryFoldersTab]. Owns its own back navigation via [onBack] and plays
/// a song through the audio player service on row tap.
class FolderDetailView extends ConsumerWidget {
  final bool isDark;
  final MusicRepository repo;
  final String folderName;
  final List<Song> songs;
  final VoidCallback onBack;

  const FolderDetailView({
    super.key,
    required this.isDark,
    required this.repo,
    required this.folderName,
    required this.songs,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.black),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(folderName,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black)),
              ),
            ],
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text('No tracks in this folder yet.',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white38 : Colors.black38)))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final s = songs[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(s.artworkUrl ?? '',
                            width: 44,
                            height: 44,
                            cacheWidth: 130,
                            cacheHeight: 130,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, st) => Container(
                                width: 44,
                                height: 44,
                                color:
                                    isDark ? Colors.white12 : Colors.black12)),
                      ),
                      title: Text(s.title,
                          maxLines: 1,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text(s.artist,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black54)),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white54
                                : Colors.black54),
                        onPressed: () =>
                            repo.removeSongFromFolder(folderName, s.id),
                      ),
                      onTap: () =>
                          ref.read(audioPlayerServiceProvider).playSong(s),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
