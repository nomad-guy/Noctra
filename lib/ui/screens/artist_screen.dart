import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/ai_radio_sheet.dart';
import '../widgets/add_to_folder_sheet.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  final String artistName;
  final String? artistImageUrl;

  const ArtistScreen({
    super.key,
    required this.artistName,
    this.artistImageUrl,
  });

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _isLoading = true;
  List<Song> _artistTracks = [];

  @override
  void initState() {
    super.initState();
    _fetchArtistTracks();
  }

  Future<void> _fetchArtistTracks() async {
    try {
      final results = await MusicService.search(widget.artistName);
      if (mounted) {
        setState(() {
          _artistTracks = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final audioPlayer = ref.watch(audioPlayerServiceProvider);

    final avatarUrl = widget.artistImageUrl ?? (_artistTracks.isNotEmpty ? _artistTracks.first.artworkUrl : null);

    return Scaffold(
      backgroundColor: isDark ? (themeMode.isAmoled ? const Color(0xFF000000) : const Color(0xFF070709)) : const Color(0xFFFFFFFF),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'ARTIST PROFILE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Artist Hero Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            avatarUrl ?? '',
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            cacheHeight: 300,
                            errorBuilder: (c, e, st) => Container(
                              color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE0E0E0),
                              child: Icon(Icons.person_rounded, size: 48, color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.artistName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_artistTracks.length} Master Releases • Lossless 320k',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: _artistTracks.isEmpty ? null : () => audioPlayer.playSong(_artistTracks.first, newQueue: _artistTracks),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('AI Radio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            onPressed: _artistTracks.isEmpty ? null : () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AIRadioSheet(seedSong: _artistTracks.first)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Tracks Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Top Hit Releases',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                ),
              ),
            ),

            // Tracks List
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else if (_artistTracks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No tracks found for this artist.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38))),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final song = _artistTracks[i];
                      final isCurrent = currentSong?.id == song.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          radius: 14,
                          isHighlighted: isCurrent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          onTap: () => audioPlayer.playSong(song, newQueue: _artistTracks),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  song.artworkUrl ?? '',
                                  width: 44,
                                  height: 44,
                                  cacheWidth: 150,
                                  cacheHeight: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, st) => Container(width: 44, height: 44, color: Colors.grey),
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
                                      style: TextStyle(fontSize: 14, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      song.album,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.playlist_add_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AddToFolderSheet(song: song)),
                              ),
                              IconButton(
                                icon: Icon(Icons.download_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading "${song.title}"...'), duration: const Duration(seconds: 2)));
                                  final res = await MusicService.downloadTrack(song);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res != null ? 'Downloaded "${song.title}"' : 'Download failed.'), duration: const Duration(seconds: 2)));
                                  }
                                },
                              ),
                              if (isCurrent && isPlaying)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white : Colors.black),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _artistTracks.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }
}
