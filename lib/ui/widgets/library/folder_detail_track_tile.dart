import 'package:flutter/material.dart';

import '../../../data/models/song_model.dart';

class FolderDetailTrackTile extends StatelessWidget {
  final Song song;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const FolderDetailTrackTile({
    super.key,
    required this.song,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.remove_circle_outline_rounded,
          size: 18,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
        onPressed: onRemove,
      ),
      onTap: onTap,
    );
  }
}
