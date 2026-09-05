import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../providers/app_providers.dart';
import '../../services/metadata/artist_metadata_service.dart';
import '../../services/ytdlp/music_service.dart';
import '../widgets/noir_mini_player_dock.dart';
import 'artist/artist_discography_sections.dart';
import 'artist/artist_profile_header.dart';
import 'artist/artist_track_tile.dart';

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
      final metaFuture =
          ArtistMetadataService.fetchArtistInfo(widget.artistName);
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
    final tracks = _discography?.topTracks ?? [];
    final avatarUrl = _artistMetadata?.imageUrl ??
        widget.artistImageUrl ??
        (tracks.isNotEmpty ? tracks.first.artworkUrl : null);

    return Scaffold(
      backgroundColor: themeMode.isLiquidGlass
          ? Colors.transparent
          : (isDark ? const Color(0xFF070709) : const Color(0xFFFFFFFF)),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: context.tr(L10nKeys.back),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : Colors.black,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          context.tr(L10nKeys.officialArtistProfile).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ArtistProfileHeader(
                    artistName: widget.artistName,
                    avatarUrl: avatarUrl,
                    artistMetadata: _artistMetadata,
                    tracks: tracks,
                    isDark: isDark,
                  ),
                ),
                if (_discography != null)
                  SliverToBoxAdapter(
                    child: ArtistAlbumsSection(
                      discography: _discography!,
                      isDark: isDark,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      context.tr(L10nKeys.topHits),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (tracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          context.tr(L10nKeys.noTracksArtist),
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final song = tracks[i];
                          return ArtistTrackTile(
                            song: song,
                            allTracks: tracks,
                            isCurrent: currentSong?.id == song.id,
                            isDark: isDark,
                          );
                        },
                        childCount: tracks.length,
                      ),
                    ),
                  ),
                if (_discography != null)
                  SliverToBoxAdapter(
                    child: ArtistSimilarSection(
                      discography: _discography!,
                      isDark: isDark,
                    ),
                  ),
                // Clearance for the floating mini-player dock.
                const SliverToBoxAdapter(child: SizedBox(height: 200)),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerDock(),
          ),
        ],
      ),
    );
  }
}
