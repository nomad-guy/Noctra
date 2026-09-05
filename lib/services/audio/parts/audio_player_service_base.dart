part of '../audio_player_service.dart';

/// Base state, player instances, synchronization chains, and cross-mixin contracts
/// for AudioPlayerService.
abstract class AudioPlayerServiceBase {
  // ─── [01] Player references & subscriptions ─────────────────────────────

  AudioPlayer _player = AudioPlayer(maxSkipsOnError: 6);
  AudioPlayer get player => _player;
  AudioPlayer? _bufferedNext;
  Song? _bufferedNextSong;

  /// Broadcasts a tick every time [_player] is replaced by a different
  /// AudioPlayer instance (crossfade promotion / preload handoff). UI that
  /// binds to `player.player.*Stream`s must re-bind on this tick, otherwise
  /// it keeps listening to the disposed previous instance.
  ///
  /// The payload is a MONOTONIC COUNTER, not a constant. Consumers re-seed
  /// their subscriptions by watching this stream; a stream that emitted the
  /// same value (e.g. `null`) twice would be treated by Riverpod's
  /// StreamProvider as unchanged and dependents would never invalidate,
  /// leaving the UI frozen on a disposed player's last position/state.
  final _playerSwapController = StreamController<int>.broadcast();
  Stream<int> get playerSwapStream => _playerSwapController.stream;
  int _playerSwapCounter = 0;

  /// Emits the swap tick. Must be called AFTER `_player` is reassigned so a
  /// listener that re-reads `player.player` observes the new instance.
  void _notifyPlayerSwap() {
    if (!_playerSwapController.isClosed) {
      _playerSwapController.add(++_playerSwapCounter);
    }
  }

  /// Queue revision the current preload was prepared against. A preload
  /// is only valid for the queue entry that existed at this revision.
  int _bufferedNextRevision = -1;
  int _preloadingGeneration = 0;
  bool _preloading = false;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _sessionSub;
  int _listenerGeneration = 0;

  // ─── [01b] Ownership tokens ────────────────────────────────────────────

  int _autoCrossfadeGeneration = 0;
  bool _autoCrossfadeQueued = false;
  bool _crossfadePending = false;
  String? _crossfadePendingSongId;
  int _crossfadePendingEpoch = 0;
  int _recoveryGeneration = 0;
  bool _recoveryInFlight = false;
  final Map<String, Future<List<Song>>> _radioRequests = {};
  int _radioGeneration = 0;
  int _autoplayDelayGeneration = 0;

  void _invalidatePlaybackOperations() {
    _autoCrossfadeGeneration++;
    _autoCrossfadeQueued = false;
    _crossfadePending = false;
    _crossfadePendingSongId = null;
    _autoplayDelayGeneration++;
  }

  // ─── [02] Serialization (state lock + async work) ──────────────────────

  bool _isDisposed = false;

  /// Serialized operation chain for playback operations.
  Future<void> _opChain = Future.value();
  Future<void> _serialize(Future<void> Function() operation) {
    if (_isDisposed) return Future.value();
    final next = _opChain.then((_) async {
      if (_isDisposed) return;
      try {
        await operation();
      } catch (e, st) {
        NoctraLogger.e('Serialized playback operation failed', e, st);
        rethrow;
      }
    });
    _opChain = next.catchError((_) {});
    return next;
  }

  void _enqueue(Future<void> Function() operation) {
    _serialize(operation).catchError((e, st) {
      NoctraLogger.e('Enqueued playback operation failed', e, st);
    });
  }

  // ─── [03] Queue / playback state ────────────────────────────────────────

  final List<Song> _queue = [];
  List<Song> get queue => List.unmodifiable(_queue);
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  Song? _currentSong;
  Song? get currentSong => _currentSong;
  int _queueRevision = 0;

  // ─── [04] Stream controllers ────────────────────────────────────────────

  final _currentSongController = StreamController<Song?>.broadcast();
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  final _queueController = StreamController<List<Song>>.broadcast();
  Stream<List<Song>> get queueStream => _queueController.stream;
  final _resolutionController =
      StreamController<StreamResolutionMetadata>.broadcast();
  Stream<StreamResolutionMetadata> get resolutionStream =>
      _resolutionController.stream;
  final _playbackSettingsController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get playbackSettingsStream =>
      _playbackSettingsController.stream;

  // ─── [05] Settings & flags ──────────────────────────────────────────────

  bool _isShuffleEnabled = false,
      _isAutoplayEnabled = true,
      _isFadeEnabled = false;
  int _sleepFadeId = 0;

  /// Canonical (unshuffled) queue order — saved before first shuffle.
  List<Song>? _canonicalQueue;
  int _canonicalIndex = 0;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isAutoplayEnabled => _isAutoplayEnabled;
  bool get isFadeEnabled => _isFadeEnabled;
  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;
  int _autoplayDelaySeconds = 0;
  int get autoplayDelaySeconds => _autoplayDelaySeconds;
  int _crossfadeSeconds = 3;
  int get crossfadeSeconds => _crossfadeSeconds;
  int? _sleepTimerRemainingMinutes;
  int? get sleepTimerRemainingMinutes => _sleepTimerRemainingMinutes;
  Timer? _sleepTimer;
  DateTime? _songStartTime;
  Duration? _lastSavedPosition;
  String? _lastSavedSongId;
  StreamResolutionMetadata? _lastResolution;
  StreamResolutionMetadata? get lastResolution => _lastResolution;
  int _lastSavedBucket = -1, _playSessionEpoch = 0;
  bool _restoredPositionUsed = false;
  int _positionSaveEpoch = 0;
  String _studioMasterMode = 'lossless320';
  static const int _maxAutomaticRecoveryAttempts = 2;
  final Map<int, int> _recoveryAttemptsByEpoch = {};
  int _transitionEpoch = 0;
  int _transitionId = 0;
  bool _transitionInProgress = false;
  int _volumeEpoch = 0;
  static const int _minAutoplayBuffer = 3;

  /// Canonical target volume — never hardcode 1.0.
  double _targetVolume = 1.0;

  // ─── Cross-Mixin Contracts ──────────────────────────────────────────────

  Future<void> _disposePlayer(AudioPlayer? p);
  void _playNonBlocking(AudioPlayer p, String context);
  void _mutateQueue(bool Function() mutate);
  void _reconcileIndex();
  Future<void> playSong(Song song,
      {List<Song>? newQueue, Duration? initialPosition, int? queueIndex});
  void pause();
  Future<void> _playSongInternal(Song song,
      {List<Song>? newQueue, Duration? initialPosition, int? queueIndex});
  Future<void> _skipNextInternal();
  Future<void> _crossfadeToNext(Song nextSong, int myId);
  Future<void> _onSongCompletedInternal();
  void _checkAutoCrossfade(Duration pos);
  void _startPreloadNext();
  Future<void> _invalidatePreload();
  bool _bufferedMatches(Song song);
  Future<void> _ensureAutoplayQueue(int epoch, int revision);
  Future<List<Song>> _getRadioQueue(Song seed);
  Future<AudioPlayer?> _preparePlayer(Song song, int epoch);
  Future<void> _fadeIn();
  Future<String> _resolveUrl(Song song);
  String _extractResolver(String resolved);
  String _extractUrl(String resolved);
  MediaItem _createMediaItem(Song s);
  Future<bool> applyStudioMasterMode(String mode);
  Future<bool> attachNativeEffectsSession();
  Future<void> _attachListeners();
  Future<void> _detachListeners();
}
