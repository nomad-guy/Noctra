import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/catalog_topic.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import 'search/search_artist_card.dart';
import 'search/search_catalog_grid.dart';
import 'search/search_track_tile.dart';

class SearchResultsList extends ConsumerWidget {
  final bool isDark;
  final List<Song> searchResults;
  final bool isSearching;
  final ValueChanged<String>? onGenreTap;
  final List<CatalogTopic>? catalogTopics;
  final bool isLoadingCatalogTopics;

  const SearchResultsList({
    super.key,
    required this.isDark,
    required this.searchResults,
    required this.isSearching,
    this.onGenreTap,
    this.catalogTopics,
    this.isLoadingCatalogTopics = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongStreamProvider).value;

    if (isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: isDark ? Colors.white : Colors.black,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Building your music catalog...',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return SearchCatalogGrid(
        isDark: isDark,
        catalogTopics: catalogTopics,
        isLoadingCatalogTopics: isLoadingCatalogTopics,
        onGenreTap: onGenreTap,
      );
    }

    final topArtist = searchResults.first.artist;
    final topArtistImg = searchResults.first.artworkUrl;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: searchResults.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return SearchArtistCard(
            artistName: topArtist,
            artistImageUrl: topArtistImg,
            isDark: isDark,
          );
        }

        final song = searchResults[i - 1];
        return SearchTrackTile(
          song: song,
          isCurrent: currentSong?.id == song.id,
          isDark: isDark,
        );
      },
    );
  }
}
