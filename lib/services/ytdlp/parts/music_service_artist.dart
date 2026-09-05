part of '../music_service.dart';

class ArtistDiscography {
  final List<Song> topTracks;
  final List<Map<String, dynamic>> albums, singles, similarArtists;
  ArtistDiscography({
    required this.topTracks,
    required this.albums,
    required this.singles,
    required this.similarArtists,
  });
}

extension MusicServiceArtist on MusicService {
  static Future<ArtistDiscography> fetchArtistCatalog(String artistName) async {
    final clean = ArtistMetadataNormalizer.fromLegacyText(artistName);
    final top = await MusicService.searchTracks(clean);
    // Artist profiles lead with the artist's own recordings, not "feat."
    // rows or lyrics re-uploads that echo the name in their titles.
    var artistTracks =
        SearchResultRanker.orderForArtistProfile(top, clean);
    // Niche/indie artists (e.g. non-Bollywood catalogs) can be thin or
    // absent on JioSaavn/YT song shelves; iTunes' artist-term lookup adds
    // their real releases, which resolve through the normal YT chain.
    if (artistTracks.length < 10) {
      try {
        final itunesOnly = await MusicService.searchTracks(clean,
                source: 'itunes')
            .timeout(const Duration(seconds: 4));
        if (itunesOnly.isNotEmpty) {
          artistTracks = SearchResultRanker.orderForArtistProfile(
              [...itunesOnly, ...top], clean);
        }
      } catch (_) {}
    }
    final albums = [
      {
        'title': '$clean: Master Essentials',
        'year': '2024',
        'art': artistTracks.isNotEmpty
            ? artistTracks.first.artworkUrl
            : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        'tracks': artistTracks.take(8).toList()
      },
      {
        'title': 'Complete Discography Deluxe',
        'year': '2023',
        'art': artistTracks.length > 8
            ? artistTracks[8].artworkUrl
            : (artistTracks.length > 1
                ? artistTracks[1].artworkUrl
                : 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500'),
        'tracks': artistTracks.skip(8).take(8).toList()
      },
    ];
    final singles = [
      {
        'title':
            artistTracks.isNotEmpty ? artistTracks.first.title : 'Greatest Hit',
        'year': '2024',
        'art': artistTracks.isNotEmpty ? artistTracks.first.artworkUrl : null
      },
      {
        'title': artistTracks.length > 2
            ? artistTracks[2].title
            : 'Radio Single',
        'year': '2023',
        'art': artistTracks.length > 2 ? artistTracks[2].artworkUrl : null
      },
    ];
    final dynamicSimilarNames =
        await ArtistMetadataService.fetchDynamicSimilarArtists(clean);
    final similar = <Map<String, dynamic>>[];
    for (final name in dynamicSimilarNames.take(4)) {
      final info = await ArtistMetadataService.fetchArtistInfo(name);
      similar.add({
        'name': name,
        'art': info.imageUrl ??
            (artistTracks.isNotEmpty
                ? artistTracks.first.artworkUrl
                : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500'),
      });
    }
    return ArtistDiscography(
        topTracks: artistTracks,
        albums: albums,
        singles: singles,
        similarArtists: similar);
  }
}
