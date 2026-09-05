import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import 'add_to_folder_sheet.dart';
import '../../shared/widgets/glass_card.dart';

import 'live_audio_wave.dart';

class DynamicVibeStreamSection extends ConsumerStatefulWidget {
  final bool isDark;
  final Song? currentSong;
  final bool isPlaying;

  const DynamicVibeStreamSection({
    super.key,
    required this.isDark,
    required this.currentSong,
    required this.isPlaying,
  });

  @override
  ConsumerState<DynamicVibeStreamSection> createState() => _DynamicVibeStreamSectionState();
}

class _DynamicVibeStreamSectionState extends ConsumerState<DynamicVibeStreamSection> {
  int _retryCount = 0;
  static const _maxRetries = 2;

  void _retry() {
    if (_retryCount < _maxRetries) {
      setState(() => _retryCount++);
      ref.invalidate(dynamicVibeTracksProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibeTracksAsync = ref.watch(dynamicVibeTracksProvider);
    final downloading = ref.watch(downloadingSongsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spotify-style section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Made For You', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: widget.isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
              )),
              Text('Live Catalog', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white54 : Colors.black45,
              )),
            ],
          ),
        ),
        vibeTracksAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) return _emptyRetry();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _retryCount = 0;
            });
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (context, i) => _buildRow(tracks, i, downloading),
            );
          },
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2, color: widget.isDark ? Colors.white : Colors.black),
            ),
          ),
          error: (e, _) => _errorState(),
        ),
      ],
    );
  }

  Widget _buildRow(List<Song> tracks, int i, Set<String> downloading) {
    final song = tracks[i];
    final isDownloaded = song.isDownloaded || downloading.contains(song.id);
    final isThisPlaying = widget.currentSong?.id == song.id && widget.isPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        radius: 14,
        onTap: () => ref.read(audioPlayerServiceProvider).playSong(song, newQueue: tracks),
        child: Row(
          children: [
            // Compact artwork -- Spotify-style 48x48
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    song.artworkUrl ?? '', width: 48, height: 48, fit: BoxFit.cover,
                    cacheWidth: 150, cacheHeight: 150,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48, height: 48,
                      color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                      child: Icon(Icons.music_note_outlined, size: 20, color: widget.isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),
                if (isThisPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: LiveAudioWave(isPlaying: true, color: Colors.white, height: 10, barCount: 3)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: widget.isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                  )),
                  const SizedBox(height: 2),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                    fontSize: 12, color: widget.isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                  )),
                ],
              ),
            ),
            // Duration or genre tag
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                song.duration.inSeconds > 0
                    ? '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}'
                    : song.genre ?? '',
                style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            // Action buttons -- compact
            _actionIcon(Icons.playlist_add_rounded, () {
              showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => AddToFolderSheet(song: song),
              );
            }),
            _actionIcon(
              isDownloaded ? Icons.check_circle_outline_rounded : Icons.download_rounded,
              isDownloaded ? null : () async {
                ref.read(downloadingSongsProvider.notifier).update((s) => {...s, song.id});
                final dl = await MusicService.downloadTrack(song);
                if (dl != null) ref.read(musicRepositoryProvider).addDownloadedSong(dl);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 32, height: 32,
      child: IconButton(
        padding: EdgeInsets.zero, iconSize: 18,
        icon: Icon(icon, color: widget.isDark ? Colors.white54 : Colors.black54),
        onPressed: onTap,
      ),
    );
  }

  Widget _emptyRetry() {
    return GestureDetector(
      onTap: _retry,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(
          'No tracks available -- tap to retry',
          style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.black45),
        )),
      ),
    );
  }

  Widget _errorState() {
    return GestureDetector(
      onTap: _retry,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Column(
          children: [
            Icon(Icons.refresh_rounded, size: 28, color: widget.isDark ? Colors.white54 : Colors.black45),
            const SizedBox(height: 6),
            Text('Tap to retry', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.black45)),
          ],
        )),
      ),
    );
  }
}
