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

    // Filter and rank tracks for artist profile
    var artistTracks = SearchResultRanker.orderForArtistProfile(top, clean);

    // Fallback for indie or niche artists
    if (artistTracks.length < 10) {
      try {
        final itunesOnly = await MusicService.searchTracks(clean, source: 'itunes')
            .timeout(const Duration(seconds: 4));
        if (itunesOnly.isNotEmpty) {
          artistTracks = SearchResultRanker.orderForArtistProfile(
              [...itunesOnly, ...top], clean);
        }
      } catch (_) {}
    }

    // 1. Fetch real albums & EPs from iTunes/Apple Music Store
    final albums = <Map<String, dynamic>>[];
    final seenAlbumTitles = <String>{};

    try {
      final itunesUri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=album&limit=8',
      );
      final res = await http
          .get(itunesUri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null) {
          for (final item in results) {
            if (item is! Map) continue;
            final albumTitle = item['collectionName']?.toString().trim() ?? '';
            if (albumTitle.isEmpty) continue;
            final normTitle = albumTitle.toLowerCase();
            if (!seenAlbumTitles.add(normTitle)) continue;

            final rawArt = item['artworkUrl100']?.toString() ?? '';
            final art = rawArt.isNotEmpty
                ? rawArt.replaceAll('100x100bb', '500x500bb')
                : (artistTracks.isNotEmpty ? artistTracks.first.artworkUrl : null);
            final rawDate = item['releaseDate']?.toString() ?? '';
            final year = rawDate.length >= 4 ? rawDate.substring(0, 4) : 'Album';

            // Associate tracks from artist catalog matching this album
            final albumTracks = artistTracks
                .where((s) =>
                    s.album.toLowerCase() == normTitle ||
                    s.album.toLowerCase().contains(normTitle))
                .toList();

            albums.add({
              'title': albumTitle,
              'year': year,
              'art': art,
              'tracks': albumTracks.isNotEmpty ? albumTracks : artistTracks.take(4).toList(),
            });
            if (albums.length >= 6) break;
          }
        }
      }
    } catch (_) {}

    // Fallback: Group tracks by genuine non-generic album names
    if (albums.length < 2) {
      const genericAlbums = {
        '320k master',
        'global catalog',
        'spotify global',
        'cd master edition',
        'unknown album',
        'single release',
        'global audio',
        'unknown',
      };
      for (final s in artistTracks) {
        final a = s.album.trim();
        final aLower = a.toLowerCase();
        if (a.isNotEmpty &&
            !genericAlbums.contains(aLower) &&
            seenAlbumTitles.add(aLower)) {
          final albumTracks =
              artistTracks.where((t) => t.album.toLowerCase() == aLower).toList();
          albums.add({
            'title': a,
            'year': 'Album',
            'art': s.artworkUrl,
            'tracks': albumTracks,
          });
          if (albums.length >= 5) break;
        }
      }
    }

    // 2. Real singles & standalone releases from top tracks
    final singles = <Map<String, dynamic>>[];
    for (final s in artistTracks.take(4)) {
      singles.add({
        'title': s.title,
        'year': 'Single',
        'art': s.artworkUrl,
        'tracks': [s],
      });
    }

    // 3. Dynamic collaborating and related artists
    final dynamicSimilarNames =
        await ArtistMetadataService.fetchDynamicSimilarArtists(clean);
    final similar = <Map<String, dynamic>>[];
    for (final name in dynamicSimilarNames.take(6)) {
      final info = await ArtistMetadataService.fetchArtistInfo(name);
      similar.add({
        'name': name,
        'art': info.imageUrl ??
            (artistTracks.isNotEmpty ? artistTracks.first.artworkUrl : null),
      });
    }

    return ArtistDiscography(
      topTracks: artistTracks,
      albums: albums,
      singles: singles,
      similarArtists: similar,
    );
  }
}
