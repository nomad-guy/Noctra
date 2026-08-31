import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../providers/app_providers.dart';
import '../../services/metadata/artist_metadata_service.dart';
import '../screens/artist_screen.dart';

class ArtistProfileEntry {
  final String name;
  final String imageUrl;
  final String genre;

  const ArtistProfileEntry({required this.name, required this.imageUrl, required this.genre});
}

class TopArtistsCarousel extends ConsumerWidget {
  final bool isDark;

  const TopArtistsCarousel({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = NoctraLocalDatabase();
    final onboarded = db.onboardedArtists;
    final topHistory = db.getTopArtists(limit: 8);
    final trendingSongs = ref.watch(dynamicTrendingFeedProvider).value ?? [];
    final chartSongs = ref.watch(dynamicSpotifyChartsProvider).value ?? [];

    final Set<String> uniqueArtistNames = {};
    for (final a in onboarded) { if (a.trim().isNotEmpty) uniqueArtistNames.add(a.trim()); }
    for (final a in topHistory) { if (a.trim().isNotEmpty) uniqueArtistNames.add(a.trim()); }
    for (final s in trendingSongs) { if (s.artist.trim().isNotEmpty) uniqueArtistNames.add(s.artist.trim()); }
    for (final s in chartSongs) { if (s.artist.trim().isNotEmpty) uniqueArtistNames.add(s.artist.trim()); }

    final displayList = uniqueArtistNames.take(12).map((name) => ArtistProfileEntry(
      name: name,
      imageUrl: '',
      genre: 'Lossless Discography',
    )).toList();

    if (displayList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPLORE ARTISTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                'Wikipedia Bios & Radio',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 124,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayList.length,
            itemBuilder: (context, i) {
              final artist = displayList[i];
              return _ArtistCardItem(artist: artist, isDark: isDark);
            },
          ),
        ),
      ],
    );
  }
}

class _ArtistCardItem extends StatefulWidget {
  final ArtistProfileEntry artist;
  final bool isDark;

  const _ArtistCardItem({required this.artist, required this.isDark});

  @override
  State<_ArtistCardItem> createState() => _ArtistCardItemState();
}

class _ArtistCardItemState extends State<_ArtistCardItem> {
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.artist.imageUrl.isEmpty) {
      _loadWikipediaPhoto();
    }
  }

  @override
  void didUpdateWidget(covariant _ArtistCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.name != widget.artist.name) {
      _resolvedImageUrl = null;
      if (widget.artist.imageUrl.isEmpty) {
        _loadWikipediaPhoto();
      }
    }
  }

  void _loadWikipediaPhoto() async {
    final meta = await ArtistMetadataService.fetchArtistInfo(widget.artist.name);
    if (mounted && meta.imageUrl != null && meta.imageUrl!.isNotEmpty) {
      setState(() => _resolvedImageUrl = meta.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = _resolvedImageUrl ?? widget.artist.imageUrl;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtistScreen(
                artistName: widget.artist.name,
                artistImageUrl: _resolvedImageUrl,
              ),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDark ? Colors.black45 : Colors.black12,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: imgUrl.isNotEmpty
                    ? Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        cacheHeight: 160,
                        errorBuilder: (_, __, ___) => _fallbackAvatar(),
                      )
                    : _fallbackAvatar(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 80,
              child: Text(
                widget.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
      child: Icon(
        Icons.person_rounded,
        size: 36,
        color: widget.isDark ? Colors.white54 : Colors.black54,
      ),
    );
  }
}
