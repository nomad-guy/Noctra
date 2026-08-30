import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/sources/noctra_local_database.dart';
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

  static const List<ArtistProfileEntry> defaultArtists = [
    ArtistProfileEntry(
      name: 'Arijit Singh',
      imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      genre: 'Bollywood / Soul',
    ),
    ArtistProfileEntry(
      name: 'Sidhu Moose Wala',
      imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
      genre: 'Punjabi Hip-Hop',
    ),
    ArtistProfileEntry(
      name: 'Diljit Dosanjh',
      imageUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500',
      genre: 'Punjabi Pop',
    ),
    ArtistProfileEntry(
      name: 'Fly By Midnight',
      imageUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500',
      genre: 'Indie Pop / Chill',
    ),
    ArtistProfileEntry(
      name: 'The Weeknd',
      imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500',
      genre: 'Synthpop / RnB',
    ),
    ArtistProfileEntry(
      name: 'Pritam',
      imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
      genre: 'Bollywood Hitmaker',
    ),
    ArtistProfileEntry(
      name: 'Karan Aujla',
      imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
      genre: 'Modern Punjabi',
    ),
    ArtistProfileEntry(
      name: 'AP Dhillon',
      imageUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500',
      genre: 'Indo-Canadian Urban',
    ),
    ArtistProfileEntry(
      name: 'Taylor Swift',
      imageUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500',
      genre: 'Pop Master',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topHistoryArtists = NoctraLocalDatabase().getTopArtists(limit: 5);
    final combinedArtists = <ArtistProfileEntry>[];

    for (final name in topHistoryArtists) {
      final existing = defaultArtists.where((a) => a.name.toLowerCase() == name.toLowerCase()).firstOrNull;
      if (existing != null) {
        combinedArtists.add(existing);
      } else {
        combinedArtists.add(ArtistProfileEntry(
          name: name,
          imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
          genre: 'Your Top Artist',
        ));
      }
    }

    for (final a in defaultArtists) {
      if (!combinedArtists.any((c) => c.name.toLowerCase() == a.name.toLowerCase())) {
        combinedArtists.add(a);
      }
    }

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
                'Discography & Radio',
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
            itemCount: combinedArtists.length,
            itemBuilder: (context, i) {
              final artist = combinedArtists[i];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtistScreen(
                          artistName: artist.name,
                          artistImageUrl: artist.imageUrl,
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
                            color: isDark ? Colors.white24 : Colors.black12,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black45 : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            artist.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            cacheHeight: 160,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5E5),
                              child: Icon(Icons.person_rounded, size: 36, color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                          ),
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
