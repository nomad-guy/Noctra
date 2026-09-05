import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';

class AddToFolderSheet extends ConsumerStatefulWidget {
  final Song song;
  const AddToFolderSheet({super.key, required this.song});

  @override
  ConsumerState<AddToFolderSheet> createState() => _AddToFolderSheetState();
}

class _AddToFolderSheetState extends ConsumerState<AddToFolderSheet> {
  final TextEditingController _folderNameCtrl = TextEditingController();
  bool _isCreatingNew = false;

  @override
  void dispose() {
    _folderNameCtrl.dispose();
    super.dispose();
  }

  void _submitNewFolder() {
    final name = _folderNameCtrl.text.trim();
    if (name.isNotEmpty) {
      final repo = ref.read(musicRepositoryProvider);
      _folderNameCtrl.clear();
      setState(() => _isCreatingNew = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repo.createFolder(name);
        repo.addSongToFolder(name, widget.song);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);
    final folders = repo.customFolders;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF40A0A0A) : const Color(0xF4FFFFFF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),

            // Track Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.song.artworkUrl ?? '',
                    width: 48,
                    height: 48,
                    cacheWidth: 140,
                    cacheHeight: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, st) => Container(width: 48, height: 48, color: isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 2),
                      Text(NoctraLocalization.tr('save_custom_folder'), style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Inline Create Action
            if (!_isCreatingNew)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _isCreatingNew = true),
                child: GlassCard(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                      const SizedBox(width: 10),
                      Text(NoctraLocalization.tr('new_folder_ellipsis'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _folderNameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(hintText: NoctraLocalization.tr('folder_name_hint')),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      onSubmitted: (_) => _submitNewFolder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    onPressed: _submitNewFolder,
                  ),
                ],
              ),

            const SizedBox(height: 14),

            // Folder List
            Flexible(
              child: folders.isEmpty
                  ? Center(child: Text(NoctraLocalization.tr('no_custom_folders'), style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38)))
                  : Builder(
                      builder: (context) {
                        final folderNames = folders.keys.toList();
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: folderNames.length,
                          itemBuilder: (context, i) {
                            final folderName = folderNames[i];
                            final songsInFolder = folders[folderName] ?? [];
                            final containsSong = songsInFolder.any((s) => s.id == widget.song.id);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                radius: 14,
                                isHighlighted: containsSong,
                                onTap: () {
                                  if (containsSong) {
                                    repo.removeSongFromFolder(folderName, widget.song.id);
                                  } else {
                                    repo.addSongToFolder(folderName, widget.song);
                                  }
                                  setState(() {});
                                },
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_rounded, size: 22, color: isDark ? Colors.white : Colors.black),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(folderName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                                          Text(NoctraLocalization.tr('tracks_count', args: {'count': songsInFolder.length}), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: containsSong ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                                        border: Border.all(color: containsSong ? Colors.transparent : (isDark ? Colors.white30 : Colors.black26), width: 1.5),
                                      ),
                                      child: containsSong ? Icon(Icons.check_rounded, size: 16, color: isDark ? Colors.black : Colors.white) : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
