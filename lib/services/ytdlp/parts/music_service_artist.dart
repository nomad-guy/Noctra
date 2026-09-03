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
    final clean = artistName.split(RegExp(r'[,&/]')).first.trim();
    final top = await MusicService.searchTracks(clean);
    final albums = [
      {
        'title': '$clean: Master Essentials',
        'year': '2024',
        'art': top.isNotEmpty
            ? top.first.artworkUrl
            : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        'tracks': top.take(8).toList()
      },
      {
        'title': 'Complete Discography Deluxe',
        'year': '2023',
        'art': top.length > 8
            ? top[8].artworkUrl
            : (top.length > 1
                ? top[1].artworkUrl
                : 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500'),
        'tracks': top.skip(8).take(8).toList()
      },
    ];
    final singles = [
      {
        'title': top.isNotEmpty ? top.first.title : 'Greatest Hit',
        'year': '2024',
        'art': top.isNotEmpty ? top.first.artworkUrl : null
      },
      {
        'title': top.length > 2 ? top[2].title : 'Radio Single',
        'year': '2023',
        'art': top.length > 2 ? top[2].artworkUrl : null
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
            (top.isNotEmpty
                ? top.first.artworkUrl
                : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500'),
      });
    }
    return ArtistDiscography(
        topTracks: top,
        albums: albums,
        singles: singles,
        similarArtists: similar);
  }
}
