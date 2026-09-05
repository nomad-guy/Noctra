import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';

class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({super.key});

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  // Stay live while the sheet is open: the queue can be mutated by autoplay
  // insertion, Jam sync, crossfade advance, or the sheet's own actions. The
  // service streams are broadcast (no replay), so the current snapshot is
  // read in build and these subscriptions only trigger rebuilds on later
  // changes. Subscriptions are cancelled on dispose.
  StreamSubscription<List<Song>>? _queueSub;
  StreamSubscription<Song?>? _songSub;
  StreamSubscription<void>? _swapSub;

  @override
  void initState() {
    super.initState();
    final player = ref.read(audioPlayerServiceProvider);
    _queueSub = player.queueStream.listen((_) {
      if (mounted) setState(() {});
    });
    _songSub = player.currentSongStream.listen((_) {
      if (mounted) setState(() {});
    });
    _swapSub = player.playerSwapStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _songSub?.cancel();
    _swapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode != NoirThemeMode.noirWhite;
    final player = ref.watch(audioPlayerServiceProvider);

    final queue = player.queue;
    final currentSong = player.currentSong;
    final currentIndex = player.currentIndex;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Material(
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(NoctraLocalization.tr('queue'),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black)),
                    Row(
                      children: [
                        if (queue.length > 1)
                          TextButton(
                            onPressed: () {
                              player.clearQueue();
                              setState(() {});
                            },
                            child: Text(NoctraLocalization.tr('clear'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54)),
                          ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Now Playing
              if (currentSong != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(NoctraLocalization.tr('now_playing'),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                ),
              if (currentSong != null)
                _buildSongTile(context, currentSong, isDark,
                    isPlaying: true, onTap: () => Navigator.pop(context)),

              if (queue.length > 1) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(NoctraLocalization.tr('up_next'),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white38 : Colors.black38)),
                      const Spacer(),
                      Text(NoctraLocalization.tr('songs_count', args: {'count': queue.length - 1}),
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                ),
              ],

              // Queue list
              Expanded(
                child: queue.length <= 1
                    ? Center(
                        child: Text(NoctraLocalization.tr('queue_empty'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    isDark ? Colors.white38 : Colors.black38)),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: queue.length,
                        onReorderItem: (oldIndex, newIndex) {
                          player.reorderQueue(oldIndex, newIndex);
                          setState(() {});
                        },
                        itemBuilder: (context, i) {
                          if (i == currentIndex && currentSong != null) {
                            return const SizedBox(
                                key: ValueKey('current_playing_spacer'));
                          }
                          final song = queue[i];
                          return KeyedSubtree(
                            key: ValueKey('queue_${song.id}_$i'),
                            child: _buildSongTile(
                              context,
                              song,
                              isDark,
                              onTap: () {
                                player.playSong(song, queueIndex: i);
                                setState(() {});
                              },
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54),
                                onPressed: () {
                                  player.removeFromQueue(i);
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile(
    BuildContext context,
    Song song,
    bool isDark, {
    bool isPlaying = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Image.network(
              song.artworkUrl ?? '',
              width: 44,
              height: 44,
              cacheWidth: 130,
              cacheHeight: 130,
              fit: BoxFit.cover,
              errorBuilder: (c, e, st) => Container(
                  width: 44,
                  height: 44,
                  color: isDark ? Colors.white12 : Colors.black12,
                  child: Icon(Icons.music_note_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ),
            if (isPlaying)
              Positioned.fill(
                child: Container(
                  decoration:
                      BoxDecoration(color: Colors.black.withValues(alpha: 0.5)),
                  child: Icon(Icons.equalizer_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
          ],
        ),
      ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13.5,
              fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
              color: isPlaying
                  ? (isDark ? Colors.cyanAccent : Colors.blue)
                  : (isDark ? Colors.white : Colors.black))),
      subtitle: Text(song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54)),
      trailing: trailing ?? const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}
