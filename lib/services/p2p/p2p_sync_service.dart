import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/noctra_logger.dart';
import '../../core/utils/path_safe_identifier.dart';
import '../../data/models/song_model.dart';
import '../audio/audio_player_service.dart';
import 'p2p_models.dart';
import 'p2p_socket_engine.dart';

part 'parts/p2p_crypto.dart';
part 'parts/p2p_rate_limiting.dart';
part 'parts/p2p_packet_codec.dart';
part 'parts/p2p_discovery_engine.dart';
part 'parts/p2p_host_auth.dart';
part 'parts/p2p_host_engine.dart';
part 'parts/p2p_client_engine.dart';
part 'parts/p2p_sync_broadcast.dart';

enum SyncCastRole { idle, host, client }

class P2PSyncService extends ChangeNotifier {
  static final P2PSyncService _instance = P2PSyncService._internal();
  factory P2PSyncService() => _instance;
  P2PSyncService._internal();

  @visibleForTesting
  static P2PSyncService newForTest() => P2PSyncService._internal();

  static const int maxPeers = 8;
  static const int maxChatCount = 100;
  static const int maxQueueLength = 200;
  static const int maxPayloadBytes = 65536;
  static const int _maxJsonDepth = 64;

  @visibleForTesting
  static int inboundWindowMs = 2000;
  @visibleForTesting
  static int inboundLimitPerWindow = 40;
  @visibleForTesting
  static int chatWindowMs = 2000;
  @visibleForTesting
  static int chatLimitPerWindow = 12;

  @visibleForTesting
  static int authFailLimit = 6;
  @visibleForTesting
  static int authFailWindowMs = 30000;
  static const int _authTrackMaxEntries = 64;

  static const int _maxPendingAuth = 16;
  static const Duration _authChallengeTimeout = Duration(seconds: 12);

  SyncCastRole _role = SyncCastRole.idle;
  SyncCastRole get role => _role;
  bool get isHost => _role == SyncCastRole.host;
  bool get isClient => _role == SyncCastRole.client;
  bool get isIdle => _role == SyncCastRole.idle;
  bool get isJamActive => _role != SyncCastRole.idle;

  HttpServer? _server;
  final List<dynamic> _connectedPeers = [];
  int get connectedPeersCount =>
      isHost ? (_connectedPeers.length + 1) : (isClient ? 2 : 0);

  int? get boundPort => _server?.port;

  dynamic _clientSocket;
  String? _localIp;
  String? get localIp => _localIp;
  String? _connectedHostIp;
  String? get connectedHostIp => _connectedHostIp;
  String _roomCode = 'JAM-8088';
  String get roomCode => _roomCode;

  String _roomSecret = '';
  String get roomSecret => _roomSecret;

  String _clientRoomSecret = '';
  String _userName = 'Host';
  String get userName => _userName;
  int _port = 8099;
  int get port => _port;
  bool _hostControlsOnly = false;
  bool get hostControlsOnly => _hostControlsOnly;

  int _sessionEpoch = 0;
  int _syncSequence = 0;
  int _lastSeenSequence = -1;
  String? _clientSessionId;
  String get activeSessionId => isHost
      ? '$_roomCode-$_sessionEpoch'
      : (_clientSessionId ?? '$_roomCode-$_sessionEpoch');
  bool _isApplyingRemoteSync = false;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Song?>? _currentSongSub;
  Timer? _periodicSyncTimer;
  Timer? _debounceSyncTimer;

  Timer? _heartbeatTimer;
  Timer? _clientLivenessTimer;
  int _lastHostActivityMs = 0;

  static const int beaconPort = 8098;
  RawDatagramSocket? _beaconBroadcastSocket;
  Timer? _beaconBroadcastTimer;
  RawDatagramSocket? _discoverySocket;
  Timer? _discoveryPruneTimer;
  final List<DiscoveredJamRoom> _discoveredRooms = [];
  List<DiscoveredJamRoom> get discoveredRooms =>
      List.unmodifiable(_discoveredRooms);

  final List<Song> _collaborativeQueue = [];
  List<Song> get collaborativeQueue => List.unmodifiable(_collaborativeQueue);
  final List<JamChatMessage> _chatMessages = [];
  List<JamChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  AudioPlayerService? _audioPlayer;
  Timer? _reconnectTimer;
  int _clientRetryCount = 0;

  final Map<dynamic, _PeerInboundTrack> _peerTracks = {};
  final Map<dynamic, _PendingAuth> _pendingAuth = {};
  final Map<String, _AuthTrack> _authFailures = {};

  void initialize(AudioPlayerService audioPlayer) {
    _audioPlayer = audioPlayer;
    if (isHost) _attachPlayerListeners();
  }

  void _attachPlayerListeners() {
    _detachPlayerListeners();
    final ap = _audioPlayer;
    if (ap == null) return;

    _playerStateSub = ap.player.playerStateStream.listen((state) {
      if (isHost && _connectedPeers.isNotEmpty && !_isApplyingRemoteSync) {
        _scheduleDebouncedSync();
      }
    });

    _currentSongSub = ap.currentSongStream.listen((song) {
      if (isHost && _connectedPeers.isNotEmpty && !_isApplyingRemoteSync) {
        _scheduleDebouncedSync();
      }
    });

    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (isHost &&
          _connectedPeers.isNotEmpty &&
          (_audioPlayer?.player.playing ?? false)) {
        broadcastSync();
      }
    });
  }

  void _detachPlayerListeners() {
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _currentSongSub?.cancel();
    _currentSongSub = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = null;
  }

  void setUserName(String name) {
    _userName = name.trim().isEmpty ? 'Listener' : name.trim();
    notifyListeners();
  }

  void sendChatMessage(String text) {
    final cleanText = _stripControlChars(text.trim());
    if (cleanText.isEmpty) return;
    final msg = JamChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderName: _cap(_stripControlChars(_userName), _maxNameLen),
      text: _cap(cleanText, _maxChatLen),
      timestamp: DateTime.now(),
    );
    _appendChat(msg);
    final packet = jsonEncode(P2PPacket.createChatPacket(msg));
    if (isHost) _broadcastToPeers(packet);
    if (isClient && _clientSocket != null) {
      try {
        _clientSocket.add(packet);
      } catch (_) {}
    }
  }

  void addToCollaborativeQueue(Song song) {
    if (_collaborativeQueue.length >= maxQueueLength) return;
    if (!_collaborativeQueue.any((s) => s.id == song.id)) {
      _collaborativeQueue.add(song);
      notifyListeners();
      if (isHost) broadcastSync();
      if (isClient && _clientSocket != null && !_hostControlsOnly) {
        try {
          _clientSocket.add(jsonEncode({
            'type': 'add_to_queue',
            'song': _sanitizeSongForWire(song).toMap()
          }));
        } catch (_) {}
      }
    }
  }

  void removeFromCollaborativeQueue(String songId, {int? queueIndex}) {
    if (_hostControlsOnly && !isHost) return;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < _collaborativeQueue.length) {
      _collaborativeQueue.removeAt(queueIndex);
    } else {
      _collaborativeQueue.removeWhere((s) => s.id == songId);
    }
    notifyListeners();
    if (isHost) broadcastSync();
    if (isClient && _clientSocket != null && !_hostControlsOnly) {
      try {
        final payload = <String, dynamic>{
          'type': 'remove_from_queue',
          'songId': songId,
        };
        if (queueIndex != null) payload['queueIndex'] = queueIndex;
        _clientSocket.add(jsonEncode(payload));
      } catch (_) {}
    }
  }

  void toggleHostControlsOnly() {
    _hostControlsOnly = !_hostControlsOnly;
    notifyListeners();
    broadcastSync();
  }

  Future<void> stopParty() async {
    _sessionEpoch++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _clientLivenessTimer?.cancel();
    _clientLivenessTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _detachPlayerListeners();
    _beaconBroadcastTimer?.cancel();
    _beaconBroadcastTimer = null;
    try {
      _beaconBroadcastSocket?.close();
    } catch (_) {}
    _beaconBroadcastSocket = null;
    stopDiscovery();
    _role = SyncCastRole.idle;
    _connectedHostIp = null;
    _localIp = null;
    _clientRetryCount = 0;
    _syncSequence = 0;
    _lastSeenSequence = -1;
    _clientSessionId = null;
    _roomSecret = '';
    _clientRoomSecret = '';
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    final peers = List<dynamic>.from(_connectedPeers);
    _connectedPeers.clear();
    _peerTracks.clear();
    for (final peer in peers) {
      try {
        peer.close();
      } catch (_) {}
    }
    final pending = List<dynamic>.from(_pendingAuth.keys);
    for (final socket in pending) {
      _cancelPendingAuth(socket);
      try {
        socket.close();
      } catch (_) {}
    }
    try {
      await _clientSocket?.close();
    } catch (_) {}
    _clientSocket = null;
    notifyListeners();
  }

  void notify() => notifyListeners();
}
