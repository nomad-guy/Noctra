import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/metadata/artist_metadata_service.dart';
import '../../services/ytdlp/music_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/ai_radio_sheet.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  final String artistName;
  final String? artistImageUrl;

  const ArtistScreen({super.key, required this.artistName, this.artistImageUrl});

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _isLoading = true;
  ArtistDiscography? _discography;
  ArtistMetadata? _artistMetadata;

  @override
  void initState() {
    super.initState();
    _fetchDiscography();
  }

  Future<void> _fetchDiscography() async {
    try {
      final discoFuture = MusicService.fetchArtistCatalog(widget.artistName);
      final metaFuture = ArtistMetadataService.fetchArtistInfo(widget.artistName);
      final results = await Future.wait([discoFuture, metaFuture]);
      if (mounted) {
        setState(() {
          _discography = results[0] as ArtistDiscography?;
          _artistMetadata = results[1] as ArtistMetadata?;
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
    final audioPlayer = ref.watch(audioPlayerServiceProvider);
    final tracks = _discography?.topTracks ?? [];
    final avatarUrl = _artistMetadata?.imageUrl ?? widget.artistImageUrl ?? (tracks.isNotEmpty ? tracks.first.artworkUrl : null);

    return Scaffold(
      backgroundColor: isDark ? (themeMode.isAmoled ? const Color(0xFF000000) : const Color(0xFF070709)) : const Color(0xFFFFFFFF),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.of(context).pop()),
                    Text('ARTIST PROFILE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: isDark ? Colors.white60 : Colors.black54)),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 2)),
                        child: ClipOval(
                          child: Image.network(avatarUrl ?? '', fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200, errorBuilder: (c, e, st) => Container(color: Colors.grey.shade900, child: const Icon(Icons.person, color: Colors.white54))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.artistName, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text(_artistMetadata?.shortDescription ?? '${tracks.length} Master Releases • 320 kbps High-Fidelity', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      if (_artistMetadata?.bio != null && _artistMetadata!.bio!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _artistMetadata!.bio!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: tracks.isEmpty ? null : () => audioPlayer.playSong(tracks.first, newQueue: tracks),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white : Colors.black, side: BorderSide(color: isDark ? Colors.white24 : Colors.black26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('AI Radio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            onPressed: tracks.isEmpty ? null : () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => AIRadioSheet(seedSong: tracks.first)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_discography != null && _discography!.albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Studio Albums & EPs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _discography!.albums.length,
                    itemBuilder: (ctx, i) {
                      final alb = _discography!.albums[i];
                      final albTracks = (alb['tracks'] as List?)?.cast<Song>() ?? [];
                      return GestureDetector(
                        onTap: () { if (albTracks.isNotEmpty) audioPlayer.playSong(albTracks.first, newQueue: albTracks); },
                        child: Container(
                          width: 110, margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(alb['art']?.toString() ?? '', width: 110, height: 95, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey.shade900))),
                              const SizedBox(height: 6),
                              Text(alb['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                              Text(alb['year']?.toString() ?? 'Album', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Top Hit Releases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
            else if (tracks.isEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No tracks found for this artist.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final song = tracks[i];
                      final isCurrent = currentSong?.id == song.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          radius: 14, isHighlighted: isCurrent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          onTap: () => audioPlayer.playSong(song, newQueue: tracks),
                          child: Row(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(song.artworkUrl ?? '', width: 42, height: 42, cacheWidth: 100, cacheHeight: 100, fit: BoxFit.cover, errorBuilder: (c, e, st) => Container(width: 42, height: 42, color: Colors.grey))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCurrent ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87))),
                                    Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                                  ],
                                ),
                              ),
                              IconButton(icon: Icon(Icons.download_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45), onPressed: () => MusicService.downloadTrack(song)),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
              ),
            if (_discography != null && _discography!.similarArtists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Fans Also Like', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _discography!.similarArtists.length,
                    itemBuilder: (ctx, i) {
                      final sim = _discography!.similarArtists[i];
                      final simName = sim['name']?.toString() ?? 'Artist';
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ArtistScreen(artistName: simName, artistImageUrl: sim['art']?.toString()))),
                        child: Container(
                          width: 80, margin: const EdgeInsets.only(right: 14),
                          child: Column(
                            children: [
                              CircleAvatar(radius: 32, backgroundImage: NetworkImage(sim['art']?.toString() ?? '')),
                              const SizedBox(height: 6),
                              Text(simName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
