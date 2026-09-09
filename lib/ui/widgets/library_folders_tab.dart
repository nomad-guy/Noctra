import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../shared/widgets/glass_card.dart';

import 'library/folder_delete_sheet.dart';
import 'library/folder_detail_view.dart';
import 'library/local_scan_card.dart';
import 'listening_insights_sheet.dart';

class LibraryFoldersTab extends ConsumerStatefulWidget {
  final bool isDark;
  final MusicRepository repo;
  final Map<String, List<Song>> customFolders;
  final List<Song> allSongs;

  @visibleForTesting
  static bool debugDisableDebounce = false;

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

class _LibraryFoldersTabState extends ConsumerState<LibraryFoldersTab>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastOpenTime;
  bool _isCreatingFolder = false;
  final TextEditingController _folderNameCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _folderNameCtrl.dispose();
    super.dispose();
  }

  void _openFolder(String folderName, List<Song> folderSongs) {
    final now = DateTime.now();
    if (!LibraryFoldersTab.debugDisableDebounce &&
        _lastOpenTime != null &&
        now.difference(_lastOpenTime!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastOpenTime = now;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderDetailView(
          isDark: widget.isDark,
          repo: widget.repo,
          folderName: folderName,
          songs: folderSongs,
        ),
      ),
    );
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
    super.build(context);

    final customFolderNames = widget.repo.customFolders.keys.toList();
    final folderNames = <String>['Favorites', ...customFolderNames];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: !_isCreatingFolder
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isCreatingFolder = true),
                              child: GlassCard(
                                radius: 16,
                                isHighlighted: true,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: widget.isDark ? Colors.white : Colors.black,
                                      ),
                                      child: Icon(Icons.create_new_folder_outlined,
                                          size: 18, color: widget.isDark ? Colors.black : Colors.white),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text('+ ${context.tr(L10nKeys.createFolder)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => ListeningInsightsSheet.show(context),
                            child: GlassCard(
                              radius: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.isDark ? Colors.white12 : Colors.black12,
                                    ),
                                    child: Icon(Icons.analytics_outlined,
                                        size: 18, color: widget.isDark ? Colors.white : Colors.black),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Insights',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LocalScanCard(isDark: widget.isDark, repo: widget.repo),
                    ],
                  )
                : GlassCard(
                    radius: 16,
                    isHighlighted: true,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr(L10nKeys.createFolder),
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _folderNameCtrl,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: context.tr(L10nKeys.folderNameHint),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                style: TextStyle(fontSize: 13.5, color: widget.isDark ? Colors.white : Colors.black),
                                onSubmitted: (_) => _submitCreateFolder(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: context.tr(L10nKeys.cancel),
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
                              child: Text(context.tr(L10nKeys.create),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final folderName = folderNames[i];
                final folderSongs = folderName == 'Favorites'
                    ? widget.repo.favorites
                    : (widget.repo.customFolders[folderName] ?? []);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    radius: 14,
                    padding: const EdgeInsets.all(12),
                    onTap: () => _openFolder(folderName, folderSongs),
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
                            color: widget.isDark ? const Color(0xFF161616) : const Color(0xFFE5E5E5),
                          ),
                          child: Icon(
                            folderName == 'Favorites' ? Icons.favorite_rounded : Icons.folder_rounded,
                            size: 24,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(folderName == 'Favorites' ? context.tr(L10nKeys.favorites) : folderName,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : Colors.black)),
                              Text(
                                context.tr(L10nKeys.tracksLongPressDelete, {'count': folderSongs.length.toString()}),
                                style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: widget.isDark ? Colors.white38 : Colors.black38),
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
