import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import 'add_to_folder_sheet.dart';
import 'ai_radio_sheet.dart';
import 'share_story_card_sheet.dart';

/// Reusable song context menu bottom sheet.
/// Shows song info + actions: Play Next, Add to Queue, Add to Folder, AI Radio.
class SongContextMenu extends ConsumerWidget {
  final Song song;
  const SongContextMenu({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SongContextMenu(song: song),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final audioPlayer = ref.watch(audioPlayerServiceProvider);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
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
            // Handle
            Center(
              child: Container(
                width: 44, height: 4.5,
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
                    song.artworkUrl ?? '',
                    width: 48, height: 48, cacheWidth: 140, cacheHeight: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, st) => Container(
                       width: 48, height: 48,
                       color: isDark ? Colors.white12 : Colors.black12,
                       child: Icon(Icons.music_note_rounded, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 2),
                      Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
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
            const SizedBox(height: 8),

            // Actions
            _menuTile(
              context, isDark,
              icon: Icons.skip_next_rounded,
              title: NoctraLocalization.tr('play_next'),
              subtitle: NoctraLocalization.tr('adds_top_queue'),
              onTap: () {
                audioPlayer.playNext(song);
                Navigator.of(context).pop();
                _showSnack(context, isDark, NoctraLocalization.tr('added_song', args: {'title': song.title}));
              },
            ),
            _menuTile(
              context, isDark,
              icon: Icons.queue_rounded,
              title: NoctraLocalization.tr('add_to_queue'),
              subtitle: NoctraLocalization.tr('adds_end_queue'),
              onTap: () {
                audioPlayer.addToQueue(song);
                Navigator.of(context).pop();
                _showSnack(context, isDark, NoctraLocalization.tr('added_song', args: {'title': song.title}));
              },
            ),
            _menuTile(
              context, isDark,
              icon: Icons.folder_rounded,
              title: NoctraLocalization.tr('folders'),
              subtitle: NoctraLocalization.tr('save_custom_folder'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddToFolderSheet(song: song),
                );
              },
            ),
            _menuTile(
              context, isDark,
              icon: Icons.auto_awesome_rounded,
              title: NoctraLocalization.tr('ai_radio'),
              subtitle: NoctraLocalization.tr('ai_radio_title'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AIRadioSheet(seedSong: song),
                );
              },
            ),
            _menuTile(
              context, isDark,
              icon: Icons.share_rounded,
              title: 'Share Story Card',
              subtitle: 'Export visual story card to Instagram or chats',
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ShareStoryCardSheet(song: song),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext context, bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
      ),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
      onTap: onTap,
    );
  }

  void _showSnack(BuildContext context, bool isDark, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
