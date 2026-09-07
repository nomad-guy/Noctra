import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';

class FolderRecommendationsFooter extends ConsumerStatefulWidget {
  final String folderName;
  final List<Song> playlistSongs;
  final bool isDark;

  const FolderRecommendationsFooter({
    super.key,
    required this.folderName,
    required this.playlistSongs,
    required this.isDark,
  });

  @override
  ConsumerState<FolderRecommendationsFooter> createState() =>
      _FolderRecommendationsFooterState();
}

class _FolderRecommendationsFooterState
    extends ConsumerState<FolderRecommendationsFooter> {
  List<Song> _recommendations = [];
  bool _isLoading = true;
  final Set<String> _addedSongIds = {};

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void didUpdateWidget(FolderRecommendationsFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistSongs.length != widget.playlistSongs.length &&
        _recommendations.isEmpty) {
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    final existingIds = widget.playlistSongs.map((s) => s.id).toSet();
    final results = <Song>[];

    try {
      if (widget.playlistSongs.isNotEmpty) {
        final seed = widget.playlistSongs.first;
        final radio = await MusicServiceCharts.fetchSimilarRadioQueue(seed,
            excludeIds: existingIds);
        for (final s in radio) {
          if (!existingIds.contains(s.id) && !_addedSongIds.contains(s.id)) {
            results.add(s);
            if (results.length >= 6) break;
          }
        }
        if (results.length < 4) {
          final query = '${seed.artist} top songs';
          final more = await MusicService.search(query).catchError((_) => <Song>[]);
          for (final s in more) {
            if (!existingIds.contains(s.id) &&
                !_addedSongIds.contains(s.id) &&
                !results.any((r) => r.id == s.id)) {
              results.add(s);
              if (results.length >= 6) break;
            }
          }
        }
      } else {
        final trending = await MusicService.fetchTrendingFeed().catchError((_) => <Song>[]);
        results.addAll(trending.take(6));
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _recommendations = results;
        _isLoading = false;
      });
    }
  }

  void _addSong(Song song) {
    setState(() {
      _addedSongIds.add(song.id);
      _recommendations.removeWhere((s) => s.id == song.id);
    });
    if (widget.folderName == 'Favorites') {
      ref.read(musicRepositoryProvider).toggleFavorite(song);
    } else {
      ref.read(musicRepositoryProvider).addSongToFolder(widget.folderName, song);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${song.title}" to ${widget.folderName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101014) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended for this Playlist',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Based on songs in this collection',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black54),
                tooltip: 'Refresh recommendations',
                onPressed: _isLoading ? null : _loadRecommendations,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_recommendations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No more recommendations right now',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final song = _recommendations[i];
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.artworkUrl ?? '',
                        width: 40,
                        height: 40,
                        cacheWidth: 120,
                        cacheHeight: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: isDark ? Colors.white12 : Colors.black12,
                          child: Icon(Icons.music_note_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 22,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () => _addSong(song),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
