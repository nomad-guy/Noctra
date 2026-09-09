import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
import '../../../services/resolvers/stream_resolver.dart';
import '../../widgets/song_context_menu.dart';
import '../../widgets/stream_quality_sheet.dart';
import '../artist_screen.dart';

class PlayerTrackInfoBar extends ConsumerStatefulWidget {
  final Song song;
  final bool isDownloaded;

  const PlayerTrackInfoBar({
    super.key,
    required this.song,
    required this.isDownloaded,
  });

  @override
  ConsumerState<PlayerTrackInfoBar> createState() =>
      _PlayerTrackInfoBarState();
}

class _PlayerTrackInfoBarState extends ConsumerState<PlayerTrackInfoBar> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;
    final repo = ref.watch(musicRepositoryProvider);
    final streamInfo =
        CompositeStreamResolver.getAudioStreamInfo(widget.song.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            widget.song.artworkUrl ?? '',
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
                widget.song.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: tokens.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (c) => ArtistScreen(
                            artistName: widget.song.artist,
                            artistImageUrl: widget.song.artworkUrl,
                          ),
                        ));
                      },
                      child: Text(
                        widget.song.artist,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: tokens.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildQualityBadge(context, streamInfo, tokens),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            repo.isFavorite(widget.song.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 22,
            color: tokens.primaryText,
          ),
          onPressed: () => repo.toggleFavorite(widget.song),
        ),
        IconButton(
          icon: Icon(Icons.playlist_add_rounded,
              size: 22, color: tokens.primaryText),
          onPressed: () => SongContextMenu.show(context, widget.song),
        ),
        // Download button: shows a spinning CircularProgressIndicator while
        // downloading, download_done_rounded when done, download_rounded otherwise.
        IconButton(
          icon: _isDownloading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.secondaryText,
                  ),
                )
              : Icon(
                  widget.isDownloaded
                      ? Icons.download_done_rounded
                      : Icons.download_rounded,
                  size: 22,
                  color: widget.isDownloaded
                      ? tokens.tertiaryAccent
                      : tokens.tertiaryText,
                ),
          onPressed: _isDownloading
              ? null
              : () => _handleDownload(context, repo, widget.song,
                  widget.isDownloaded),
        ),
      ],
    );
  }

  Widget _buildQualityBadge(
    BuildContext context,
    AudioStreamInfo? info,
    NoctraThemeTokens tokens,
  ) {
    final isLocal = widget.song.localFilePath != null &&
        widget.song.localFilePath!.isNotEmpty;
    final label = info?.shortLabel ?? (isLocal ? 'LOCAL' : '320K');
    final isHiRes = info?.tier == AudioQualityTier.hiResLossless;
    final isLossless = info?.tier == AudioQualityTier.lossless;
    final isAtmos = info?.tier == AudioQualityTier.dolbyAtmos;

    final Color badgeColor = isHiRes
        ? const Color(0xFFFFD700)
        : isLossless
            ? const Color(0xFF00E5FF)
            : isAtmos
                ? const Color(0xFFB388FF)
                : tokens.secondaryText.withValues(alpha: 0.8);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const StreamQualitySheet(),
        );
      },
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.5),
            width: 0.8,
          ),
          color: badgeColor.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: badgeColor,
          ),
        ),
      ),
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
          content: Text(context.tr(L10nKeys.removeDownload)),
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

    final downloadingMsg =
        context.tr(L10nKeys.downloadingSong, {'title': song.title});
    final successMsg =
        context.tr(L10nKeys.downloadedSong, {'title': song.title});
    final errorMsg = context.tr(L10nKeys.error);

    setState(() => _isDownloading = true);
    sm.showSnackBar(SnackBar(
      content: Text(downloadingMsg),
      duration: const Duration(seconds: 2),
    ));
    final res = await MusicService.downloadTrack(song);
    if (mounted) {
      setState(() => _isDownloading = false);
      if (res != null) {
        repo.addDownloadedSong(res);
      }
      sm.showSnackBar(SnackBar(
        content: Text(res != null ? successMsg : errorMsg),
        duration: const Duration(seconds: 3),
      ));
    }
  }
}
