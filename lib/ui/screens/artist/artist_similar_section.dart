import 'package:flutter/material.dart';
import '../../../services/ytdlp/music_service.dart';
import '../artist_screen.dart';

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
