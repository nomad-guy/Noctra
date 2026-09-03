part of '../music_service.dart';

void _parseYtMusicSearchResults(
    Map<String, dynamic> sData, void Function(Song) addSong) {
    try {
      final sections = sData['contents']?['tabbedSearchResultsRenderer']
              ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'] as List?;
      if (sections == null) return;

      for (final sec in sections) {
        final secMap = sec as Map;
        final itemSections =
            secMap['itemSectionRenderer']?['contents'] as List?;
        final shelfItems = secMap['musicShelfRenderer']?['contents'] as List?;
        final allItems = [
          ...?itemSections,
          ...?shelfItems,
        ];

        for (final it in allItems) {
          final itMap = it as Map;

          final r = itMap['musicResponsiveListItemRenderer'] as Map?;
          if (r != null) {
            final flex = r['flexColumns'] as List?;
            final t = (flex != null && flex.isNotEmpty)
                ? (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']
                            ?['runs']?[0]?['text'] ??
                        '')
                    .toString()
                : '';
            final a = (flex != null && flex.length > 1)
                ? (flex[1]['musicResponsiveListItemFlexColumnRenderer']?['text']
                            ?['runs']?[0]?['text'] ??
                        'YouTube Music')
                    .toString()
                : 'YouTube Music';
            String? vid = r['playlistItemData']?['videoId']?.toString() ??
                r['navigationEndpoint']?['watchEndpoint']?['videoId']
                    ?.toString();
            String? thumb;
            try {
              final thumbnails = r['thumbnail']?['musicThumbnailRenderer']
                  ?['thumbnail']?['thumbnails'] as List?;
              if (thumbnails != null && thumbnails.isNotEmpty) {
                thumb = thumbnails.last['url']?.toString();
              }
            } catch (_) {}
            if (vid != null && vid.length == 11 && t.isNotEmpty) {
              addSong(Song(
                  id: vid,
                  title: t,
                  artist: a,
                  album: 'Global Catalog',
                  artworkUrl:
                      thumb ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                  streamUrl: null,
                  duration: const Duration(seconds: 210),
                  genre: 'Global Audio',
                  featureVector:
                      MusicService._deriveFeatureVector(t, artist: a)));
            }
            continue;
          }

          final twoRow = itMap['musicTwoRowItemRenderer'] as Map?;
          if (twoRow != null) {
            final titleRuns = twoRow['title']?['runs'] as List?;
            final t = titleRuns?.isNotEmpty == true
                ? (titleRuns![0]['text'] ?? '').toString()
                : '';
            final subRuns = twoRow['subtitle']?['runs'] as List?;
            final subText = subRuns?.isNotEmpty == true
                ? subRuns!.map((r) => r['text'] ?? '').join().toString()
                : '';
            String? thumb;
            try {
              final thumbnails = twoRow['thumbnailRenderer']
                      ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
                  as List?;
              if (thumbnails != null && thumbnails.isNotEmpty) {
                thumb = thumbnails.last['url']?.toString();
              }
            } catch (_) {}
            if (t.isNotEmpty && subText.toLowerCase().contains('artist')) {
              continue;
            } else if (t.isNotEmpty) {
              String? watchId;
              try {
                watchId = twoRow['navigationEndpoint']?['watchEndpoint']
                    ?['videoId']?.toString();
              } catch (_) {}
              if (watchId != null && watchId.length == 11) {
                addSong(Song(
                    id: watchId,
                    title: t,
                    artist: subText.isNotEmpty ? subText : 'YouTube Music',
                    album: 'Global Catalog',
                    artworkUrl: thumb ??
                        'https://i.ytimg.com/vi/$watchId/hqdefault.jpg',
                    streamUrl: null,
                    duration: const Duration(seconds: 210),
                    genre: 'Global Audio',
                    featureVector:
                        MusicService._deriveFeatureVector(t, artist: subText)));
              }
            }
            continue;
          }
        }
      }
    } catch (_) {}
  }
