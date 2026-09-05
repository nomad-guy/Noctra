import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
import '../artist_screen.dart';

class ArtistAlbumsSection extends ConsumerWidget {
  final ArtistDiscography discography;
  final bool isDark;

  const ArtistAlbumsSection({
    super.key,
    required this.discography,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (discography.albums.isEmpty) return const SizedBox.shrink();
    final audioPlayer = ref.watch(audioPlayerServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Studio Albums & EPs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: discography.albums.length,
            itemBuilder: (ctx, i) {
              final alb = discography.albums[i];
              final albTracks = (alb['tracks'] as List?)?.cast<Song>() ?? [];
              return GestureDetector(
                onTap: () {
                  if (albTracks.isNotEmpty) {
                    audioPlayer.playSong(albTracks.first, newQueue: albTracks);
                  }
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          alb['art']?.toString() ?? '',
                          width: 110,
                          height: 95,
                          fit: BoxFit.cover,
                          cacheWidth: 220,
                          cacheHeight: 190,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alb['title']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        alb['year']?.toString() ?? 'Album',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ArtistSimilarSection extends StatelessWidget {
  final ArtistDiscography discography;
  final bool isDark;

  const ArtistSimilarSection({
    super.key,
    required this.discography,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (discography.similarArtists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Fans Also Like',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: discography.similarArtists.length,
            itemBuilder: (ctx, i) {
              final sim = discography.similarArtists[i];
              final simName = sim['name']?.toString() ?? 'Artist';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => ArtistScreen(
                      artistName: simName,
                      artistImageUrl: sim['art']?.toString(),
                    ),
                  ),
                ),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(
                          sim['art']?.toString() ?? '',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        simName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
