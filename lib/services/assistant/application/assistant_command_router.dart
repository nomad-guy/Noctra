import 'package:just_audio/just_audio.dart';
import '../../../core/utils/noctra_logger.dart';
import '../../../data/repositories/music_repository.dart';
import '../../audio/audio_player_service.dart';
import '../domain/assistant_command.dart';
import '../domain/assistant_result.dart';
import 'assistant_content_router.dart';
import 'assistant_search_pipeline.dart';

export 'assistant_content_router.dart' show ThemeChangeCallback;

/// Authoritative command router coordinating voice and media session actions
/// with Noctra's single AudioPlayerService, MusicRepository, and Theme systems.
class AssistantCommandRouter {
  final AudioPlayerService _playerService;
  final AssistantContentRouter _contentRouter;

  AssistantCommandRouter({
    AudioPlayerService? playerService,
    MusicRepository? musicRepo,
    AssistantSearchPipeline? searchPipeline,
    ThemeChangeCallback? themeCallback,
  })  : _playerService = playerService ?? AudioPlayerService.instance,
        _contentRouter = AssistantContentRouter(
          playerService: playerService ?? AudioPlayerService.instance,
          musicRepo: musicRepo ?? MusicRepository.instance,
          searchPipeline: searchPipeline ??
              AssistantSearchPipeline(musicRepo: musicRepo ?? MusicRepository.instance),
          themeCallback: themeCallback,
        );

  void setThemeCallback(ThemeChangeCallback callback) {
    _contentRouter.themeCallback = callback;
  }

  /// Execute an AssistantCommand and return an explicit AssistantResult.
  Future<AssistantResult> execute(AssistantCommand command) async {
    try {
      return await switch (command) {
        PlayCommand() => _handlePlay(),
        PauseCommand() => _handlePause(),
        ResumeCommand() => _handleResume(),
        StopCommand() => _handleStop(),
        NextCommand() => _handleNext(),
        PreviousCommand() => _handlePrevious(),
        SeekCommand(:final position) => _handleSeek(position),
        FastForwardCommand(:final offset) => _handleSeekRelative(offset),
        RewindCommand(:final offset) => _handleSeekRelative(-offset),
        SetPlaybackSpeedCommand(:final speed) => _handleSetSpeed(speed),
        SetShuffleCommand(:final enable) => _handleSetShuffle(enable),
        SetRepeatCommand(:final mode) => _handleSetRepeat(mode),
        SearchAndPlayCommand(:final query, :final extras) =>
          _contentRouter.handleSearchAndPlay(query, extras),
        PlayTrackCommand(:final trackId, :final title, :final artist) =>
          _contentRouter.handlePlayTrack(trackId, title: title, artist: artist),
        PlayArtistCommand(:final artistName) =>
          _contentRouter.handlePlayArtist(artistName),
        PlayAlbumCommand(:final albumName) =>
          _contentRouter.handlePlayAlbum(albumName),
        PlayPlaylistCommand(:final playlistIdOrName, :final shuffle) =>
          _contentRouter.handlePlayPlaylist(playlistIdOrName, shuffle: shuffle),
        PlayRecommendationCommand(:final intent) =>
          _contentRouter.handlePlayRecommendation(intent),
        AddToQueueCommand(:final queryOrTrackId) =>
          _contentRouter.handleAddToQueue(queryOrTrackId),
        PlayNextCommand(:final queryOrTrackId) =>
          _contentRouter.handlePlayNext(queryOrTrackId),
        RemoveFromQueueCommand(:final trackId) =>
          _contentRouter.handleRemoveFromQueue(trackId),
        ClearQueueCommand() => _contentRouter.handleClearQueue(),
        AddFavoriteCommand(:final trackId) =>
          _contentRouter.handleAddFavorite(trackId),
        RemoveFavoriteCommand(:final trackId) =>
          _contentRouter.handleRemoveFavorite(trackId),
        ChangeThemeCommand(:final themeName) =>
          _contentRouter.handleChangeTheme(themeName),
      };
    } catch (e, stack) {
      NoctraLogger.e('AssistantCommandRouter error', e, stack);
      return AssistantInternalFailure(e);
    }
  }

  Future<AssistantResult> _handlePlay() async {
    await _playerService.resumeOrPlay();
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handlePause() async {
    _playerService.pause();
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleResume() async {
    await _playerService.resumeOrPlay();
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleStop() async {
    _playerService.pause();
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleNext() async {
    await _playerService.skipNext();
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handlePrevious() async {
    await _playerService.skipPrevious();
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleSeek(Duration position) async {
    final maxDur = _playerService.player.duration ?? Duration.zero;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (maxDur > Duration.zero && position > maxDur ? maxDur : position);
    await _playerService.seek(clamped);
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleSeekRelative(Duration offset) async {
    final cur = _playerService.player.position;
    return _handleSeek(cur + offset);
  }

  Future<AssistantResult> _handleSetSpeed(double speed) async {
    final clamped = speed.clamp(0.25, 2.0);
    await _playerService.player.setSpeed(clamped);
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleSetShuffle(bool enable) async {
    if (_playerService.isShuffleEnabled != enable) {
      _playerService.toggleShuffle();
    }
    return const AssistantSuccess();
  }

  Future<AssistantResult> _handleSetRepeat(String mode) async {
    final current = _playerService.loopMode;
    if (mode == 'one' && current != LoopMode.one) {
      _playerService.toggleLoopMode();
      if (_playerService.loopMode != LoopMode.one) _playerService.toggleLoopMode();
    } else if (mode == 'all' && current != LoopMode.all) {
      _playerService.toggleLoopMode();
      if (_playerService.loopMode != LoopMode.all) _playerService.toggleLoopMode();
    } else if (mode == 'off' && current != LoopMode.off) {
      _playerService.toggleLoopMode();
      if (_playerService.loopMode != LoopMode.off) _playerService.toggleLoopMode();
    }
    return const AssistantSuccess();
  }
}
