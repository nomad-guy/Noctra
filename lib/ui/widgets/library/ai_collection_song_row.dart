import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';

/// One song row in an AI folder/mix detail list: artwork, title, artist, and
/// an add-to-queue action. Tapping the row plays from that index.
class AiCollectionSongRow extends ConsumerWidget {
  final bool isDark;
  final Song song;
  final VoidCallback onTap;

  const AiCollectionSongRow({
    super.key,
    required this.isDark,
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textSecondary = isDark ? Colors.white54 : Colors.black54;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          song.artworkUrl ?? '',
          width: 44,
          height: 44,
          cacheWidth: 130,
          cacheHeight: 130,
          fit: BoxFit.cover,
          errorBuilder: (c, e, st) => Container(
            width: 44,
            height: 44,
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
            child: Icon(Icons.music_note_rounded,
                size: 18, color: textSecondary),
          ),
        ),
      ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: textSecondary)),
      trailing: IconButton(
        icon: Icon(Icons.playlist_add_rounded, size: 20, color: textSecondary),
        tooltip: 'Add to queue',
        onPressed: () {
          ref.read(audioPlayerServiceProvider).addToQueue(song);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
                content: Text('Added "${song.title}" to queue'),
                duration: const Duration(seconds: 2)));
        },
      ),
      onTap: onTap,
    );
  }
}
