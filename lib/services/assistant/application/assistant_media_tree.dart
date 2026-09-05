import 'package:audio_service/audio_service.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../domain/stable_media_id.dart';

/// Exposes Noctra's audio library as an Android MediaBrowser hierarchy tree.
class AssistantMediaTree {
  final MusicRepository _musicRepo;

  AssistantMediaTree({MusicRepository? musicRepo})
      : _musicRepo = musicRepo ?? MusicRepository.instance;

  /// Load child items for a given parent ID in the media browser tree.
  Future<List<MediaItem>> getChildren(String parentMediaId) async {
    final parsed = StableMediaId.parse(parentMediaId) ??
        const StableMediaId(type: 'root');

    switch (parsed.type) {
      case 'root':
        return _getRootItems();
      case 'favorites':
        return _songsToMediaItems(_musicRepo.favorites);
      case 'downloads':
        return _songsToMediaItems(_musicRepo.downloads);
      case 'recently_played':
        return _songsToMediaItems(_musicRepo.recentlyPlayed);
      case 'playlists':
        return _getPlaylists();
      case 'playlist':
        if (parsed.value != null) {
          final songs = _musicRepo.customFolders[parsed.value] ?? [];
          return _songsToMediaItems(songs);
        }
        return [];
      case 'recommendations':
        return _songsToMediaItems(_musicRepo.favorites.take(15).toList());
      default:
        return [];
    }
  }

  /// Retrieve a specific MediaItem by its stable ID.
  Future<MediaItem?> getItem(String mediaId) async {
    final parsed = StableMediaId.parse(mediaId);
    if (parsed == null) return null;

    if (parsed.type == 'track' && parsed.value != null) {
      final song = _findSongById(parsed.value!);
      if (song != null) {
        return songToMediaItem(song);
      }
    }
    return null;
  }

  List<MediaItem> _getRootItems() {
    return [
      const MediaItem(
        id: StableMediaId.favoritesId,
        title: 'Favorites',
        album: 'Noctra Library',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: StableMediaId.downloadsId,
        title: 'Downloads',
        album: 'Noctra Library',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: StableMediaId.recentlyPlayedId,
        title: 'Recently Played',
        album: 'Noctra Library',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: StableMediaId.playlistsId,
        title: 'Playlists',
        album: 'Noctra Library',
        playable: false,
        extras: {'browsable': true},
      ),
      const MediaItem(
        id: StableMediaId.recommendationsId,
        title: 'Recommended For You',
        album: 'Noctra Library',
        playable: false,
        extras: {'browsable': true},
      ),
    ];
  }

  List<MediaItem> _getPlaylists() {
    return _musicRepo.customFolders.keys.map((name) {
      return MediaItem(
        id: StableMediaId.forPlaylist(name),
        title: name,
        album: 'Playlists',
        playable: false,
        extras: {'browsable': true},
      );
    }).toList();
  }

  List<MediaItem> _songsToMediaItems(List<Song> songs) {
    return songs.map((s) => songToMediaItem(s)).toList();
  }

  static MediaItem songToMediaItem(Song song) {
    return MediaItem(
      id: StableMediaId.forTrack(song.id),
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: (song.artworkUrl != null && song.artworkUrl!.startsWith('http'))
          ? Uri.tryParse(song.artworkUrl!)
          : null,
      playable: true,
      extras: {
        'originalId': song.id,
        'genre': song.genre ?? '',
      },
    );
  }

  Song? _findSongById(String id) {
    for (final s in _musicRepo.downloads) {
      if (s.id == id) return s;
    }
    for (final s in _musicRepo.favorites) {
      if (s.id == id) return s;
    }
    for (final s in _musicRepo.recentlyPlayed) {
      if (s.id == id) return s;
    }
    return null;
  }
}
