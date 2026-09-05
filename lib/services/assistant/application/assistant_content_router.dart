import 'dart:math';
import '../../../core/theme/noir_theme.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../data/sources/noctra_local_database.dart';
import '../../audio/audio_player_service.dart';
import '../domain/assistant_result.dart';
import 'assistant_search_pipeline.dart';

typedef ThemeChangeCallback = void Function(NoirThemeMode mode);

/// Handles search, playlist, queue, library, and theme operations for Assistant commands.
class AssistantContentRouter {
  final AudioPlayerService playerService;
  final MusicRepository musicRepo;
  final AssistantSearchPipeline searchPipeline;
  ThemeChangeCallback? themeCallback;

  AssistantContentRouter({
    required this.playerService,
    required this.musicRepo,
    required this.searchPipeline,
    this.themeCallback,
  });

  Future<AssistantResult> handleSearchAndPlay(
      String query, Map<String, dynamic>? extras) async {
    final song = await searchPipeline.resolveSearch(query, extras: extras);
    if (song == null) return const AssistantNotFound('Song not found');
    await playerService.playSong(song);
    return AssistantSuccess(song);
  }

  Future<AssistantResult> handlePlayTrack(String trackId,
      {String? title, String? artist}) async {
    final local = findLocalSong(trackId);
    if (local != null) {
      await playerService.playSong(local);
      return AssistantSuccess(local);
    }
    final query = title != null
        ? (artist != null ? '$title $artist' : title)
        : trackId;
    return handleSearchAndPlay(query, null);
  }

  Future<AssistantResult> handlePlayArtist(String artistName) async {
    final song = await searchPipeline.resolveSearch(artistName,
        extras: {'android.intent.extra.artist': artistName});
    if (song == null) return const AssistantNotFound('Artist tracks not found');
    await playerService.playSong(song);
    return AssistantSuccess(song);
  }

  Future<AssistantResult> handlePlayAlbum(String albumName) async {
    final song = await searchPipeline.resolveSearch(albumName,
        extras: {'android.intent.extra.album': albumName});
    if (song == null) return const AssistantNotFound('Album not found');
    await playerService.playSong(song);
    return AssistantSuccess(song);
  }

  Future<AssistantResult> handlePlayPlaylist(String playlistIdOrName,
      {bool shuffle = false}) async {
    final clean = playlistIdOrName.toLowerCase().trim();
    List<Song> tracks = [];

    if (clean.contains('favorite') || clean == 'favorites') {
      tracks = musicRepo.favorites;
    } else if (clean.contains('download') || clean == 'downloads') {
      tracks = musicRepo.downloads;
    } else if (clean.contains('recent') || clean == 'recently_played') {
      tracks = musicRepo.recentlyPlayed;
    } else {
      for (final entry in musicRepo.customFolders.entries) {
        if (entry.key.toLowerCase() == clean) {
          tracks = entry.value;
          break;
        }
      }
    }

    if (tracks.isEmpty) {
      return const AssistantNotFound('Playlist or collection not found');
    }

    final playList = List<Song>.from(tracks);
    if (shuffle) playList.shuffle(Random());

    await playerService.playSong(playList.first, newQueue: playList, queueIndex: 0);
    return AssistantSuccess(playList);
  }

  Future<AssistantResult> handlePlayRecommendation(
      dynamic recommendationIntent) async {
    final pool = musicRepo.favorites.isNotEmpty
        ? musicRepo.favorites
        : musicRepo.downloads;
    if (pool.isNotEmpty) {
      final shuffled = List<Song>.from(pool)..shuffle(Random());
      await playerService.playSong(shuffled.first, newQueue: shuffled, queueIndex: 0);
      return AssistantSuccess(shuffled);
    }
    return handleSearchAndPlay('trending music', null);
  }

  Future<AssistantResult> handleAddToQueue(String queryOrTrackId) async {
    final song = findLocalSong(queryOrTrackId) ??
        await searchPipeline.resolveSearch(queryOrTrackId);
    if (song == null) return const AssistantNotFound('Song not found for queue');
    playerService.addToQueue(song);
    return AssistantSuccess(song);
  }

  Future<AssistantResult> handlePlayNext(String queryOrTrackId) async {
    final song = findLocalSong(queryOrTrackId) ??
        await searchPipeline.resolveSearch(queryOrTrackId);
    if (song == null) return const AssistantNotFound('Song not found');
    playerService.playNext(song);
    return AssistantSuccess(song);
  }

  Future<AssistantResult> handleRemoveFromQueue(String trackId) async {
    final queue = playerService.queue;
    final idx = queue.indexWhere((s) => s.id == trackId);
    if (idx != -1) {
      playerService.removeFromQueue(idx);
      return const AssistantSuccess();
    }
    return const AssistantNotFound('Track not found in queue');
  }

  Future<AssistantResult> handleClearQueue() async {
    playerService.clearQueue();
    return const AssistantSuccess();
  }

  Future<AssistantResult> handleAddFavorite(String? trackId) async {
    final song = trackId != null ? findLocalSong(trackId) : playerService.currentSong;
    if (song != null) {
      musicRepo.toggleFavorite(song);
      return const AssistantSuccess();
    }
    return const AssistantNotFound('No active track to favorite');
  }

  Future<AssistantResult> handleRemoveFavorite(String? trackId) async {
    final song = trackId != null ? findLocalSong(trackId) : playerService.currentSong;
    if (song != null) {
      if (musicRepo.isFavorite(song.id)) {
        musicRepo.toggleFavorite(song);
      }
      return const AssistantSuccess();
    }
    return const AssistantNotFound('No active track to unfavorite');
  }

  Future<AssistantResult> handleChangeTheme(String themeName) async {
    final clean = themeName.toLowerCase().replaceAll(' ', '_');
    NoirThemeMode? targetMode;

    if (clean.contains('white') || clean == 'noir_white') {
      targetMode = NoirThemeMode.noirWhite;
    } else if (clean.contains('glass') || clean == 'liquid_glass') {
      targetMode = NoirThemeMode.liquidGlass;
    } else if (clean.contains('black') || clean == 'noir_black' || clean.contains('dark')) {
      targetMode = NoirThemeMode.noirBlack;
    } else {
      return const AssistantInvalidCommand(
          'Unsupported theme. Supported: Noir Black, Noir White, Liquid Glass');
    }

    themeCallback?.call(targetMode);
    NoctraLocalDatabase().saveCachedThemeMode(targetMode.name);
    return AssistantSuccess(targetMode);
  }

  Song? findLocalSong(String id) {
    for (final s in musicRepo.downloads) {
      if (s.id == id) return s;
    }
    for (final s in musicRepo.favorites) {
      if (s.id == id) return s;
    }
    for (final s in musicRepo.recentlyPlayed) {
      if (s.id == id) return s;
    }
    return null;
  }
}
