import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ytdlp/music_service.dart';
export 'artist_similar_section.dart';

class ArtistAlbumsSection extends ConsumerStatefulWidget {
  final ArtistDiscography discography;
  final bool isDark;

  const ArtistAlbumsSection({
    super.key,
    required this.discography,
    required this.isDark,
  });

  @override
  ConsumerState<ArtistAlbumsSection> createState() => _ArtistAlbumsSectionState();
}

class _ArtistAlbumsSectionState extends ConsumerState<ArtistAlbumsSection> {
  int _selectedTab = 0; // 0: All, 1: Albums, 2: Singles & EPs, 3: Features

  @override
  Widget build(BuildContext context) {
    if (widget.discography.albums.isEmpty) return const SizedBox.shrink();
    final audioPlayer = ref.watch(audioPlayerServiceProvider);
    final isDark = widget.isDark;

    final allAlbums = widget.discography.albums;
    final studioAlbums = allAlbums.where((a) {
      final t = (a['title']?.toString() ?? '').toLowerCase();
      final count = (a['trackCount'] as num?)?.toInt() ?? 0;
      return !t.contains('single') && !t.contains(' - ep') && count != 1;
    }).toList();

    final singlesAndEps = allAlbums.where((a) {
      final t = (a['title']?.toString() ?? '').toLowerCase();
      final count = (a['trackCount'] as num?)?.toInt() ?? 0;
      return t.contains('single') || t.contains(' - ep') || count == 1;
    }).toList();

    // Features from top tracks
    final features = widget.discography.topTracks.where((s) {
      final t = s.title.toLowerCase();
      final a = s.artist.toLowerCase();
      return t.contains('feat') || t.contains('ft.') || a.contains('feat') || a.contains('&') || a.contains(',');
    }).toList();

    List<Map<String, dynamic>> displayItems = allAlbums;
    if (_selectedTab == 1) {
      displayItems = studioAlbums.isNotEmpty ? studioAlbums : allAlbums;
    } else if (_selectedTab == 2) {
      displayItems = singlesAndEps.isNotEmpty ? singlesAndEps : allAlbums;
    }

    final tabNames = ['All', 'Albums', 'Singles & EPs', 'Features'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discography',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '${allAlbums.length} releases',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        // Segmented filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(tabNames.length, (idx) {
              final isSel = _selectedTab == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = idx),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white10 : Colors.black12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tabNames[idx],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        if (_selectedTab == 3)
          features.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    'No featured appearances found',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                )
              : SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: features.length,
                    itemBuilder: (ctx, i) {
                      final song = features[i];
                      return GestureDetector(
                        onTap: () => audioPlayer.playSong(song, newQueue: features, queueIndex: i),
                        child: Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  song.artworkUrl ?? '',
                                  width: 110,
                                  height: 95,
                                  fit: BoxFit.cover,
                                  cacheWidth: 220,
                                  cacheHeight: 190,
                                  errorBuilder: (c, e, s) => Container(color: Colors.grey.shade900),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayItems.length,
              itemBuilder: (ctx, i) {
                final alb = displayItems[i];
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
                          alb['year']?.toString() ?? 'Release',
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
