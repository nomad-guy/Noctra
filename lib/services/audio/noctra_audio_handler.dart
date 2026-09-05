import 'dart:async';
import 'package:audio_service/audio_service.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../assistant/application/assistant_command_router.dart';
import '../assistant/application/assistant_media_tree.dart';
import '../assistant/domain/assistant_command.dart';
import '../assistant/domain/assistant_result.dart';
import 'audio_player_service.dart';
import 'noctra_audio_handler_state.dart';

/// Bridges Noctra's playback engine to audio_service's media session,
/// notification, and media-button events, and routes Google Assistant / MediaBrowser
/// commands through AssistantCommandRouter.
class NoctraAudioHandler extends BaseAudioHandler {
  AudioPlayerService? _service;
  StreamSubscription<Song?>? _songSub;
  Timer? _ticker;
  final NoctraAudioHandlerStateMirror _mirror = NoctraAudioHandlerStateMirror();
  AssistantCommandRouter? _router;
  AssistantMediaTree? _mediaTree;

  AudioPlayerService get _svc => _service ??= AudioPlayerService.instance;
  AssistantCommandRouter get router =>
      _router ??= AssistantCommandRouter(playerService: _svc);
  AssistantMediaTree get mediaTree => _mediaTree ??= AssistantMediaTree();

  void attach(AudioPlayerService service, {AssistantCommandRouter? router}) {
    _service = service;
    if (router != null) _router = router;
    _songSub?.cancel();
    _songSub = service.currentSongStream.listen((_) => _push(forceSong: true));
    _push(forceSong: true);
  }

  void _ensureAttached() {
    if (_songSub == null) attach(_svc);
  }

  // ─── Media Controls ─────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    _ensureAttached();
    await router.execute(const PlayCommand());
    await _settle();
  }

  @override
  Future<void> pause() async {
    _ensureAttached();
    await router.execute(const PauseCommand());
    await _settle();
  }

  @override
  Future<void> stop() async {
    _ensureAttached();
    await router.execute(const StopCommand());
    await _settle();
  }

  @override
  Future<void> skipToNext() async {
    _ensureAttached();
    await router.execute(const NextCommand());
    await _settle();
  }

  @override
  Future<void> skipToPrevious() async {
    _ensureAttached();
    await router.execute(const PreviousCommand());
    await _settle();
  }

  @override
  Future<void> seek(Duration position) async {
    _ensureAttached();
    await router.execute(SeekCommand(position));
    await _settle();
  }

  @override
  Future<void> fastForward([Duration offset = const Duration(seconds: 15)]) async {
    _ensureAttached();
    await router.execute(FastForwardCommand(offset));
    await _settle();
  }

  @override
  Future<void> rewind([Duration offset = const Duration(seconds: 15)]) async {
    _ensureAttached();
    await router.execute(RewindCommand(offset));
    await _settle();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _ensureAttached();
    await router.execute(SetPlaybackSpeedCommand(speed));
    await _settle();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _ensureAttached();
    final modeStr = switch (repeatMode) {
      AudioServiceRepeatMode.one => 'one',
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => 'all',
      _ => 'off',
    };
    await router.execute(SetRepeatCommand(modeStr));
    await _settle();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _ensureAttached();
    final enable = shuffleMode != AudioServiceShuffleMode.none;
    await router.execute(SetShuffleCommand(enable));
    await _settle();
  }

  // ─── Assistant & Search Commands ────────────────────────────────────────

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    _ensureAttached();
    NoctraLogger.d('NoctraAudioHandler: playFromSearch("$query", extras=$extras)');
    await router.execute(SearchAndPlayCommand(query, extras));
    await _settle();
  }

  @override
  Future<void> prepareFromSearch(String query, [Map<String, dynamic>? extras]) =>
      playFromSearch(query, extras);

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    _ensureAttached();
    NoctraLogger.d('NoctraAudioHandler: playFromMediaId("$mediaId")');
    if (mediaId.startsWith('noctra://playlist/')) {
      final name = Uri.decodeComponent(mediaId.replaceFirst('noctra://playlist/', ''));
      await router.execute(PlayPlaylistCommand(name));
    } else {
      await router.execute(PlayTrackCommand(mediaId));
    }
    await _settle();
  }

  @override
  Future<void> prepareFromMediaId(String mediaId, [Map<String, dynamic>? extras]) =>
      playFromMediaId(mediaId, extras);

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) =>
      playFromMediaId(uri.toString(), extras);

  // ─── Queue Controls ─────────────────────────────────────────────────────

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _ensureAttached();
    await router.execute(AddToQueueCommand(mediaItem.id));
    await _settle();
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _ensureAttached();
    await router.execute(RemoveFromQueueCommand(mediaItem.id));
    await _settle();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _ensureAttached();
    final q = _svc.queue;
    if (index >= 0 && index < q.length) {
      await _svc.playSong(q[index]);
      await _settle();
    }
  }

  // ─── Custom Actions & MediaBrowserService ───────────────────────────────

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    _ensureAttached();
    NoctraLogger.d('NoctraAudioHandler: customAction("$name", extras=$extras)');
    switch (name) {
      case 'clearQueue':
        return router.execute(const ClearQueueCommand());
      case 'addFavorite':
        return router.execute(AddFavoriteCommand(extras?['trackId']?.toString()));
      case 'removeFavorite':
        return router.execute(RemoveFavoriteCommand(extras?['trackId']?.toString()));
      case 'changeTheme':
        final theme = extras?['theme']?.toString() ?? 'noir_black';
        return router.execute(ChangeThemeCommand(theme));
      default:
        return false;
    }
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) =>
      mediaTree.getChildren(parentMediaId);

  @override
  Future<MediaItem?> getMediaItem(String mediaId) =>
      mediaTree.getItem(mediaId);

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) async {
    final song = await router.execute(SearchAndPlayCommand(query, extras));
    if (song is AssistantSuccess && song.data is Song) {
      return [AssistantMediaTree.songToMediaItem(song.data as Song)];
    }
    return [];
  }

  // ─── State Mirroring ────────────────────────────────────────────────────

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60), _push);

  void _push({bool forceSong = false}) {
    if (_isDisposed) return;
    final svc = _service;
    if (svc == null) return;
    final song = svc.currentSong;
    _ensureTicker(song != null);

    _mirror.push(
      song: song,
      svc: svc,
      pushMediaItem: (item) {
        if (!mediaItem.isClosed) mediaItem.add(item);
      },
      pushPlaybackState: (state) {
        if (!playbackState.isClosed) playbackState.add(state);
      },
      forceSong: forceSong,
    );
  }

  void _ensureTicker(bool active) {
    if (active) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _push());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool _isDisposed = false;

  void dispose() {
    _isDisposed = true;
    _songSub?.cancel();
    _songSub = null;
    _ticker?.cancel();
    _ticker = null;
    if (!playbackState.isClosed) playbackState.close();
    if (!mediaItem.isClosed) mediaItem.close();
  }
}
