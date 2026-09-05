import 'package:flutter/material.dart';
import '../../../data/models/ai_folder_model.dart';
import '../../../data/models/ai_playlist_model.dart';

class LibraryAiMixesContent extends StatelessWidget {
  final bool isDark;
  final List<AIPlaylist> mixes;
  final List<AIFolder> folders;
  final List<String> topArtists;
  final String archetype;
  final ValueChanged<AIPlaylist> onOpenMix;
  final ValueChanged<AIFolder> onOpenFolder;

  const LibraryAiMixesContent({
    super.key,
    required this.isDark,
    required this.mixes,
    required this.folders,
    required this.topArtists,
    required this.archetype,
    required this.onOpenMix,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) => ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 160),
        children: [
          Text('Your sound: $archetype',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 18),
          if (mixes.isNotEmpty) ...[
            _heading('Your Mixes'),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mixes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) => _MixCard(
                    isDark: isDark,
                    mix: mixes[index],
                    onTap: () => onOpenMix(mixes[index])),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (folders.isNotEmpty) ...[
            _heading('AI Folders'),
            ...folders.map((folder) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FolderRow(
                      isDark: isDark,
                      folder: folder,
                      onTap: () => onOpenFolder(folder)),
                )),
            const SizedBox(height: 14),
          ],
          if (topArtists.isNotEmpty) ...[
            _heading('In Your Rotation'),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topArtists
                    .map((artist) => Chip(label: Text(artist)))
                    .toList()),
          ],
          if (mixes.isEmpty && folders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                  child: Text(
                      'Keep listening\nYour AI mixes and folders will appear as you build your listening history.',
                      textAlign: TextAlign.center)),
            ),
        ],
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black)),
      );
}

class _MixCard extends StatelessWidget {
  final bool isDark;
  final AIPlaylist mix;
  final VoidCallback onTap;
  const _MixCard(
      {required this.isDark, required this.mix, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 130,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(mix.artworkUrl,
                  width: 130,
                  height: 108,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 130,
                      height: 108,
                      color: isDark
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFE5E5E5),
                      child: const Icon(Icons.album_rounded))),
            ),
            const SizedBox(height: 6),
            Text(mix.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(mix.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}

class _FolderRow extends StatelessWidget {
  final bool isDark;
  final AIFolder folder;
  final VoidCallback onTap;
  const _FolderRow(
      {required this.isDark, required this.folder, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04),
        leading: Icon(folder.icon),
        title: Text(folder.name),
        subtitle: Text(folder.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('${folder.trackCount} tracks'),
      );
}
