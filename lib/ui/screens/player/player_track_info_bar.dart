import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
import '../../widgets/song_context_menu.dart';
import '../artist_screen.dart';

class PlayerTrackInfoBar extends ConsumerWidget {
  final Song song;
  final bool isDownloaded;

  const PlayerTrackInfoBar({
    super.key,
    required this.song,
    required this.isDownloaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.noctraTokens;
    final repo = ref.watch(musicRepositoryProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            song.artworkUrl ?? '',
            width: 58,
            height: 58,
            fit: BoxFit.cover,
            cacheWidth: 180,
            cacheHeight: 180,
            errorBuilder: (c, e, st) => Container(
              width: 58,
              height: 58,
              color: tokens.elevatedSurface,
              child: Icon(Icons.music_note_rounded,
                  color: tokens.secondaryText),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: tokens.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (c) => ArtistScreen(
                      artistName: song.artist,
                      artistImageUrl: song.artworkUrl,
                    ),
                  ));
                },
                child: Text(
                  song.artist,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: tokens.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            repo.isFavorite(song.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 22,
            color: tokens.primaryText,
          ),
          onPressed: () => repo.toggleFavorite(song),
        ),
        IconButton(
          icon: Icon(Icons.playlist_add_rounded,
              size: 22, color: tokens.primaryText),
          onPressed: () => SongContextMenu.show(context, song),
        ),
        IconButton(
          icon: Icon(
            isDownloaded
                ? Icons.download_done_rounded
                : Icons.download_rounded,
            size: 22,
            color: isDownloaded
                ? tokens.tertiaryAccent
                : tokens.tertiaryText,
          ),
          onPressed: () => _handleDownload(context, repo, song, isDownloaded),
        ),
      ],
    );
  }

  void _handleDownload(BuildContext context, MusicRepository repo, Song song,
      bool isDownloaded) async {
    final sm = ScaffoldMessenger.of(context);
    if (isDownloaded) {
      final shouldRemove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr(L10nKeys.removeDownloadQ)),
          content:
              Text(context.tr(L10nKeys.removeDownload)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.tr(L10nKeys.cancel)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.tr(L10nKeys.remove)),
            ),
          ],
        ),
      );
      if (shouldRemove == true) {
        await repo.removeDownloadedSong(song.id);
      }
      return;
    }
    sm.showSnackBar(SnackBar(
      content: Text(context.tr(L10nKeys.downloadingSong, {'title': song.title})),
      duration: const Duration(seconds: 2),
    ));
    final res = await MusicService.downloadTrack(song);
    if (res != null) {
      repo.addDownloadedSong(res);
    }
    if (context.mounted) {
      sm.showSnackBar(SnackBar(
        content: Text(res != null
            ? context.tr(L10nKeys.downloadedSong, {'title': song.title})
            : context.tr(L10nKeys.error)),
        duration: const Duration(seconds: 3),
      ));
    }
  }
}
