import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';

class SwipeableSongTile extends ConsumerWidget {
  final Song song;
  final Widget child;

  const SwipeableSongTile({
    super.key,
    required this.song,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey('swipe_tile_${song.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFF00B4D8).withValues(alpha: isDark ? 0.25 : 0.15),
        child: const Row(
          children: [
            Icon(Icons.playlist_play_rounded,
                color: Color(0xFF00E5FF), size: 24),
            SizedBox(width: 8),
            Text(
              'Play Next',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFFFFB300).withValues(alpha: isDark ? 0.25 : 0.15),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Add to Queue',
              style: TextStyle(
                color: Color(0xFFFFB300),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.queue_music_rounded,
                color: Color(0xFFFFB300), size: 24),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        final player = ref.read(audioPlayerServiceProvider);
        HapticFeedback.mediumImpact();

        if (direction == DismissDirection.startToEnd) {
          player.playNext(song);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Playing next: ${song.title}'),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (direction == DismissDirection.endToStart) {
          player.addToQueue(song);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to queue: ${song.title}'),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      },
      child: child,
    );
  }
}
