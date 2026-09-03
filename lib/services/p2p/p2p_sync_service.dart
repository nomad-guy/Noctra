import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../audio/audio_player_service.dart';
import 'p2p_models.dart';
import 'p2p_socket_engine.dart';

/// Cryptographically strong room secret generator. Produces 8
/// alphanumeric chunks separated by `-` for human-readable entry
/// without sacrificing entropy. Total entropy ~190 bits — effectively
/// unguessable on a LAN.
String _generateRoomSecret() {
  final rng = Random.secure();
  // RFC4648 base32 alphabet (no I/L/O/U to avoid confusion).
  const alphabet = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';
  String chunk() => List.generate(
        5,
        (_) => alphabet[rng.nextInt(alphabet.length)],
      ).join();
  return '${chunk()}-${chunk()}-${chunk()}-${chunk()}-${chunk()}-'
      '${chunk()}-${chunk()}-${chunk()}';
}

/// Constant-time string equality to prevent timing oracles during
/// room-secret verification.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// HMAC-SHA256 of [message] keyed by [key], hex-encoded. Used by the
/// challenge/response authentication handshake so the raw room secret is
/// never transmitted over the wire and a captured response is bound to the
/// server-issued one-time nonce (not replayable against a later challenge).
String _hmacHex(String key, String message) {
  final hmac = Hmac(sha256, utf8.encode(key));
  return hmac.convert(utf8.encode(message)).toString();
}

/// Random 32-byte challenge nonce (base64url). Generated per connection by
/// the host; the client proves knowledge of the room secret by MACing it.
String _randomNonce() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes);
}

/// Sliding-window rate state. Windows are fixed-size and reset lazily on
/// the first tick after expiry, so entries cost constant memory.
class _RateState {
  int startMs = 0;
  int count = 0;
}

bool _tickRate(_RateState st, int limit, int windowMs, int nowMs) {
  if (nowMs - st.startMs >= windowMs) {
    st.startMs = nowMs;
    st.count = 0;
  }
  st.count++;
  return st.count <= limit;
}

enum SyncCastRole { idle, host, client }

class P2PSyncService extends ChangeNotifier {
  static final P2PSyncService _instance = P2PSyncService._internal();
  factory P2PSyncService() => _instance;
  P2PSyncService._internal();

  /// Create an independent instance for tests. Production code must keep
  /// using the [P2PSyncService] singleton so a single room state exists.
  @visibleForTesting
  static P2PSyncService newForTest() => P2PSyncService._internal();

  static const int maxPeers = 8;
  static const int maxChatCount = 100;
  static const int maxQueueLength = 200;

  /// Hard cap on a single inbound WebSocket payload. The cap is applied to
  /// the raw frame BEFORE JSON parsing, so a hostile peer cannot make the
  /// host allocate an unbounded string or a deep parse tree.
  static const int maxPayloadBytes = 65536;

  /// Maximum allowed JSON nesting depth (defense against depth bombs that
  /// could otherwise overflow the recursive decoder on a 64 KiB frame).
  static const int _maxJsonDepth = 64;

  /// Per-peer inbound message rate (defaults, overridable in tests).
  @visibleForTesting
  static int inboundWindowMs = 2000;
  @visibleForTesting
  static int inboundLimitPerWindow = 40;
  @visibleForTesting
  static int chatWindowMs = 2000;
  @visibleForTesting
  static int chatLimitPerWindow = 12;

  /// Per-IP failed-authentication throttle. Bounded map (entries expire and
  /// the table itself is capped), so attacker-controlled IPs cannot grow it.
  @visibleForTesting
  static int authFailLimit = 6;
  @visibleForTesting
  static int authFailWindowMs = 30000;
  static const int _authTrackMaxEntries = 64;

  /// Cap on WebSocket connections that have upgraded but NOT yet completed
  /// the authentication challenge. Bounds the pre-auth resource window so a
  /// LAN flooder cannot hold unlimited half-open sockets.
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

  /// Actual bound port when the host asked for port 0 (random); used by
  /// tests and for display of a host-started room.
  int? get boundPort => _server?.port;

  dynamic _clientSocket;
  String? _localIp;
  String? get localIp => _localIp;
  String? _connectedHostIp;
  String? get connectedHostIp => _connectedHostIp;
  String _roomCode = 'JAM-8088';
  String get roomCode => _roomCode;

  /// 40-character room secret. Displayed to the host for out-of-band
  /// sharing and used as the actual authentication credential for the
  /// WebSocket upgrade. Cleared whenever the room ends so a previous
  /// credential can never authenticate a later room.
  String _roomSecret = '';
  String get roomSecret => _roomSecret;

  /// Secret the client used to join; retained only so automatic reconnects
  /// can re-authenticate without re-prompting the user. Cleared on leave.
  String _clientRoomSecret = '';
  String _userName = 'Host';
  String get userName => _userName;
  int _port = 8099;
  int get port => _port;
  bool _hostControlsOnly = false;
  bool get hostControlsOnly => _hostControlsOnly;

  /// Monotonic session generation. Every state-mutating async continuation
  /// (reconnect timers, server request handlers, socket listeners) captures
  /// the epoch it belongs to and discards itself when it no longer matches,
  /// so an old session can never mutate a newer one.
  int _sessionEpoch = 0;

  /// Monotonic sequence number for sync packets to enforce strict ordering
  /// and reject replay attacks.
  int _syncSequence = 0;
  int _lastSeenSequence = -1;
  String? _clientSessionId;
  String get activeSessionId =>
      isHost ? '$_roomCode-$_sessionEpoch' : (_clientSessionId ?? '$_roomCode-$_sessionEpoch');
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

  /// Bounded per-peer inbound trackers. Peers are limited to [maxPeers]
  /// authenticated sockets, so this map cannot grow without bound.
  final Map<dynamic, _PeerInboundTrack> _peerTracks = {};

  /// Connections that upgraded but have not yet passed the auth challenge.
  /// Bounded by [_maxPendingAuth].
  final Map<dynamic, _PendingAuth> _pendingAuth = {};

  /// Per-IP failed-auth tracking; bounded by [_authTrackMaxEntries].
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

  void _scheduleDebouncedSync() {
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = Timer(const Duration(milliseconds: 60), () {
      if (isHost) broadcastSync();
    });
  }

  void _startHostHeartbeat(int epoch) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (epoch != _sessionEpoch || !isHost) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final pingMsg = jsonEncode({'type': 'ping', 'timestamp': nowMs});
      _broadcastToPeers(pingMsg);

      final deadSockets = <dynamic>[];
      _peerTracks.forEach((socket, track) {
        if (nowMs - track.lastSeenMs > 15000) {
          deadSockets.add(socket);
        }
      });
      for (final s in deadSockets) {
        NoctraLogger.w(
            'Jam dropping unresponsive peer (15s heartbeat timeout)');
        _dropPeer(s);
      }
    });
  }

  void _startClientLivenessCheck(int epoch, String hostIp, int port) {
    _clientLivenessTimer?.cancel();
    _lastHostActivityMs = DateTime.now().millisecondsSinceEpoch;
    _clientLivenessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (epoch != _sessionEpoch || !isClient) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastHostActivityMs > 15000) {
        NoctraLogger.w(
            'Jam host heartbeat timeout (15s) - attempting reconnect');
        _clientLivenessTimer?.cancel();
        _onClientSocketClosed(epoch, hostIp, port);
      }
    });
  }

  Future<void> _startBeaconBroadcast() async {
    _beaconBroadcastTimer?.cancel();
    try {
      _beaconBroadcastSocket?.close();
    } catch (_) {}
    if (kIsWeb) return;
    try {
      _beaconBroadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _beaconBroadcastSocket?.broadcastEnabled = true;
      _beaconBroadcastTimer =
          Timer.periodic(const Duration(seconds: 2), (_) => _sendBeacon());
    } catch (e) {
      NoctraLogger.w('Jam beacon broadcast init failed', e);
    }
  }

  void _sendBeacon() {
    if (!isHost || _beaconBroadcastSocket == null) return;
    final payload = jsonEncode({
      'type': 'noctra_jam_beacon',
      'roomCode': _roomCode,
      'hostName': _userName,
      'hostIp': _localIp ?? '127.0.0.1',
      'port': _port,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    try {
      _beaconBroadcastSocket?.send(
        utf8.encode(payload),
        InternetAddress('255.255.255.255'),
        beaconPort,
      );
    } catch (_) {}
  }

  Future<void> startDiscovery() async {
    if (kIsWeb) return;
    stopDiscovery();
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
      );
      _discoverySocket?.broadcastEnabled = true;
      _discoverySocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket?.receive();
          if (datagram != null) {
            _handleBeaconPacket(datagram.data, datagram.address.address);
          }
        }
      });
      _discoveryPruneTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        final now = DateTime.now();
        final beforeCount = _discoveredRooms.length;
        _discoveredRooms
            .removeWhere((r) => now.difference(r.lastSeen).inSeconds > 6);
        if (_discoveredRooms.length != beforeCount) notifyListeners();
      });
    } catch (e) {
      NoctraLogger.w('Jam UDP discovery start failed', e);
    }
  }

  void _handleBeaconPacket(List<int> bytes, String senderIp) {
    try {
      final str = utf8.decode(bytes);
      final map = jsonDecode(str);
      if (map is! Map<String, dynamic>) return;
      if (map['type'] != 'noctra_jam_beacon') return;
      final rCode = map['roomCode']?.toString();
      final hName = map['hostName']?.toString();
      final portNum = map['port'] is int ? map['port'] as int : 8099;
      final claimedIp = map['hostIp']?.toString();
      final effectiveIp = (claimedIp != null &&
              claimedIp.isNotEmpty &&
              claimedIp != '127.0.0.1' &&
              claimedIp != '0.0.0.0')
          ? claimedIp
          : senderIp;
      if (rCode == null || rCode.isEmpty) return;

      final room = DiscoveredJamRoom(
        roomCode: rCode,
        hostName: (hName != null && hName.isNotEmpty) ? hName : 'Host',
        hostIp: effectiveIp,
        port: portNum,
        lastSeen: DateTime.now(),
      );

      final idx = _discoveredRooms.indexWhere((r) =>
          r.roomCode == rCode &&
          r.hostIp == effectiveIp &&
          r.port == portNum);
      if (idx >= 0) {
        _discoveredRooms[idx] = room;
      } else {
        _discoveredRooms.add(room);
        notifyListeners();
      }
    } catch (_) {}
  }

  void stopDiscovery() {
    _discoveryPruneTimer?.cancel();
    _discoveryPruneTimer = null;
    try {
      _discoverySocket?.close();
    } catch (_) {}
    _discoverySocket = null;
    if (_discoveredRooms.isNotEmpty) {
      _discoveredRooms.clear();
      notifyListeners();
    }
  }
  void setUserName(String name) {
    _userName = name.trim().isEmpty ? 'Listener' : name.trim();
    notifyListeners();
  }

  /// Legacy display-only room code. Authentication uses [_roomSecret].
  String _generateRoomCode() {
    final rng = Random.secure();
    return 'JAM-${1000 + rng.nextInt(9000)}';
  }

  bool _isValidHostOrIp(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    // Hostnames (.local, .lan, alphanumeric)
    if (RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(host) && !host.contains('..')) {
      // If looks like IPv4, validate strictly
      if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) {
        final parts = host.split('.');
        if (parts.length != 4) return false;
        int first = 0, second = 0;
        for (int i = 0; i < 4; i++) {
          final n = int.tryParse(parts[i]);
          if (n == null || n < 0 || n > 255) return false;
          if (i == 0) first = n;
          if (i == 1) second = n;
        }
        if (first == 0 || first == 127) return false;
        if (first == 169 && second == 254) return false;
        if (first >= 224) return false;
        return true;
      }
      // Valid hostname or IPv6
      return true;
    }
    return false;
  }

  Future<bool> startHost({int port = 8099, String? customRoomCode}) async {
    await stopParty();
    final epoch = _sessionEpoch;

    _roomCode = customRoomCode ?? _generateRoomCode();
    final secret = _generateRoomSecret();
    _roomSecret = secret;
    if (_userName == 'Listener') _userName = 'Host';
    _chatMessages.clear();
    _collaborativeQueue.clear();
    _authFailures.clear();
    _chatMessages.add(JamChatMessage(
        id: 'system_init',
        senderName: 'System',
        text: 'Noctra Jam Room "$_roomCode" online.',
        timestamp: DateTime.now()));

    if (kIsWeb) {
      // No real WebSocket transport exists on web: fail closed instead of
      // reporting a fake "hosted" room with no synchronization channel.
      NoctraLogger.w('Jam hosting is not supported on the web platform.');
      _roomSecret = '';
      return false;
    }

    final server = await P2PSocketEngine.bindServer(port);
    if (server == null || epoch != _sessionEpoch) {
      _roomSecret = '';
      await server?.close(force: true);
      return false;
    }
    _server = server;
    _port = port;
    _role = SyncCastRole.host;
    _localIp = await P2PSocketEngine.findLocalIp();
    if (epoch != _sessionEpoch) {
      // Another session began while we awaited network calls.
      await stopParty();
      return false;
    }

    server.listen((request) {
      // Requests racing in from a previous (closed) room must never be
      // processed against the new room's state.
      if (epoch != _sessionEpoch || _server != server) {
        try {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.close();
        } catch (_) {}
        return;
      }
      if (request.uri.path != '/ws') {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
        return;
      }
      final ip = request.connectionInfo?.remoteAddress.address ?? '';
      // Fail-closed: an IP that exhausted its failed-auth budget is refused
      // at the HTTP layer before any upgrade/challenge work happens.
      if (_isAuthThrottled(ip)) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.close();
        return;
      }
      if (_connectedPeers.length >= maxPeers ||
          _pendingAuth.length >= _maxPendingAuth) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.close();
        return;
      }
      WebSocketTransformer.upgrade(request).then((socket) {
        _startAuthChallenge(socket, epoch, ip);
      }).catchError((e) {
        NoctraLogger.w('WebSocket upgrade failed', e);
      });
    }, onError: (Object e) {
      NoctraLogger.w('Jam host server error', e);
    });
    _syncSequence = 0;
    _attachPlayerListeners();
    _startHostHeartbeat(epoch);
    _startBeaconBroadcast();
    notifyListeners();
    return true;
  }

  // ---- Peer authentication & registration ------------------------------

  /// Begin the challenge/response handshake for a newly-upgraded socket.
  ///
  /// The room secret itself is NEVER sent over the wire: the host issues a
  /// random one-time nonce and the peer must MAC it with the secret. A
  /// captured response is worthless against a different nonce, so a passive
  /// LAN sniffer cannot replay authentication or recover the credential.
  void _startAuthChallenge(dynamic socket, int epoch, String ip) {
    if (epoch != _sessionEpoch) {
      try {
        socket.close();
      } catch (_) {}
      return;
    }
    final nonce = _randomNonce();
    final pending = _PendingAuth(ip, nonce);
    _pendingAuth[socket] = pending;
    try {
      socket.add(jsonEncode({'type': 'jam_auth_challenge', 'nonce': nonce}));
    } catch (_) {
      _cancelPendingAuth(socket);
      return;
    }
    // Connections that never complete the challenge are closed and count
    // as a failed attempt for their IP (bounded by the auth throttle).
    pending.deadline = Timer(_authChallengeTimeout, () {
      if (_pendingAuth.remove(socket) == pending) {
        _recordAuthFailure(ip);
        try {
          socket.close();
        } catch (_) {}
      }
    });
    socket.listen(
      (data) => _handlePeerSocketMessage(socket, data, epoch, ip),
      onDone: () {
        // Only count teardown as a failed attempt while this room session
        // is still live (never during stopParty of the same instance).
        if (epoch == _sessionEpoch) _onPeerSocketClosed(socket, ip);
      },
      onError: (_) {
        if (epoch == _sessionEpoch) _onPeerSocketClosed(socket, ip);
      },
    );
  }

  void _handlePeerSocketMessage(
      dynamic socket, dynamic rawData, int epoch, String ip) {
    if (epoch != _sessionEpoch) return;
    final pending = _pendingAuth[socket];
    if (pending != null) {
      // Not yet authenticated: this frame is the auth response.
      _attemptAuth(socket, pending, rawData, epoch, ip);
      return;
    }
    _handleHostIncomingMessage(socket, rawData, epoch);
  }

  void _attemptAuth(dynamic socket, _PendingAuth pending, dynamic rawData,
      int epoch, String ip) {
    final data = _decodeWireObject(rawData);
    final type = data?['type'];
    final response = type == 'jam_auth_response' ? data!['response'] : null;
    if (response is! String || response.isEmpty) {
      _failAuth(socket, pending, ip);
      return;
    }
    final expected = _hmacHex(_roomSecret, pending.nonce);
    if (!_constantTimeEquals(response, expected)) {
      _failAuth(socket, pending, ip);
      return;
    }
    // Authenticated: promote to a full peer and send the room state.
    _cancelPendingAuth(socket);
    _clearAuthFailures(ip);
    _grantPeer(socket, epoch);
  }

  void _failAuth(dynamic socket, _PendingAuth pending, String ip) {
    _cancelPendingAuth(socket);
    _recordAuthFailure(ip);
    try {
      socket.close();
    } catch (_) {}
  }

  void _cancelPendingAuth(dynamic socket) {
    final pending = _pendingAuth.remove(socket);
    pending?.deadline?.cancel();
  }

  void _onPeerSocketClosed(dynamic socket, String ip) {
    // If the socket still owed us an auth response, its departure counts as
    // a failed authentication attempt for that IP.
    if (_pendingAuth.remove(socket) != null) {
      _recordAuthFailure(ip);
      return;
    }
    _unregisterPeer(socket);
  }

  /// Promote an authenticated socket to a registered peer and send it the
  /// current room state. The listener was attached by [_startAuthChallenge]
  /// and keeps dispatching through [_handlePeerSocketMessage].
  void _grantPeer(dynamic socket, int epoch) {
    if (epoch != _sessionEpoch) {
      try {
        socket.close();
      } catch (_) {}
      return;
    }
    _connectedPeers.add(socket);
    _peerTracks[socket] = _PeerInboundTrack();
    notifyListeners();

    _syncSequence++;
    final statePayload = <String, dynamic>{
      'type': 'jam_full_state',
      'seq': _syncSequence,
      'sessionId': activeSessionId,
      'roomCode': _roomCode,
      'hostControlsOnly': _hostControlsOnly,
      'queue': _wireQueueSlice(),
      'chatMessages': _chatMessages.map((m) => m.toMap()).toList(),
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    };
    if (_audioPlayer?.currentSong != null) {
      statePayload['song'] =
          _sanitizeSongForWire(_audioPlayer!.currentSong!).toMap();
      statePayload['positionMs'] = _audioPlayer!.player.position.inMilliseconds;
      statePayload['isPlaying'] = _audioPlayer!.player.playing;
      statePayload['hostTimestamp'] = DateTime.now().millisecondsSinceEpoch;
    }
    try {
      socket.add(jsonEncode(statePayload));
    } catch (_) {
      // Dead-on-arrival socket; the onDone/onError listener cleans it up.
    }
  }

  void _unregisterPeer(dynamic socket) {
    final wasPresent = _connectedPeers.remove(socket);
    _peerTracks.remove(socket);
    if (wasPresent) notifyListeners();
  }

  /// Drop a peer that violated protocol-level limits. The socket is closed
  /// and fully unregistered so a single hostile peer cannot block the room.
  void _dropPeer(dynamic socket) {
    _unregisterPeer(socket);
    try {
      socket.close();
    } catch (_) {}
  }

  // ---- Host inbound handling -------------------------------------------

  void _handleHostIncomingMessage(dynamic socket, dynamic rawData, int epoch) {
    if (epoch != _sessionEpoch) return; // stale room

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final track = _peerTracks[socket];
    if (track == null) return;
    track.lastSeenMs = nowMs;

    if (!_tickRate(track.general, P2PSyncService.inboundLimitPerWindow,
        P2PSyncService.inboundWindowMs, nowMs)) {
      NoctraLogger.w('Jam peer dropped: inbound message rate exceeded');
      _dropPeer(socket);
      return;
    }

    final data = _decodeWireObject(rawData);
    if (data == null) return; // malformed/oversized/deep — rejected silently
    final type = data['type'];
    if (type is! String || type.isEmpty) return;

    if (type == 'pong') return;
    if (type == 'ping') {
      try {
        socket.add(
            jsonEncode({'type': 'pong', 'timestamp': data['timestamp']}));
      } catch (_) {}
      return;
    }

    switch (type) {
      case 'chat':
        final chatTrack = track.chat;
        if (!_tickRate(chatTrack, P2PSyncService.chatLimitPerWindow,
            P2PSyncService.chatWindowMs, nowMs)) {
          NoctraLogger.w('Jam peer dropped: chat rate exceeded');
          _dropPeer(socket);
          return;
        }
        _handlePeerChat(socket, data['message']);
        break;
      case 'add_to_queue':
        // Authorization is enforced server-side. Listeners may only mutate
        // the shared queue when the host has not enabled host-controls-only.
        if (!_hostControlsOnly) {
          final song = _decodeRemoteSong(data['song']);
          if (song != null) addToCollaborativeQueue(song);
        }
        break;
      case 'remove_from_queue':
        if (!_hostControlsOnly) {
          final rawIndex = data['queueIndex'];
          if (rawIndex is int &&
              rawIndex >= 0 &&
              rawIndex < _collaborativeQueue.length) {
            _collaborativeQueue.removeAt(rawIndex);
            notifyListeners();
            broadcastSync();
          } else {
            final id = data['songId'];
            if (id is String && id.trim().isNotEmpty && id.length <= 128) {
              removeFromCollaborativeQueue(id.trim());
            }
          }
        }
        break;
      default:
        // Unknown packet types are ignored (never mutate state).
        break;
    }
  }

  void _handlePeerChat(dynamic socket, dynamic raw) {
    final msg = _decodeChatMessage(raw);
    if (msg == null) return;
    // Sender identity is host-assigned at the relay: strip control
    // characters and prevent peers from impersonating the room's system or
    // the host's own display name.
    final sanitized = JamChatMessage(
      id: msg.id,
      senderName: _safePeerSenderName(msg.senderName),
      text: msg.text,
      timestamp: msg.timestamp,
    );
    _appendChat(sanitized);
    _broadcastToPeers(jsonEncode(P2PPacket.createChatPacket(sanitized)));
  }

  /// Rewrites claimed sender names that would collide with privileged or
  /// self-identity labels ("System", or the host's own name).
  String _safePeerSenderName(String claimed) {
    final name = claimed.trim();
    if (name.isEmpty) return 'Listener';
    final lower = name.toLowerCase();
    final hostName = _userName.trim();
    if (lower == 'system' ||
        (hostName.isNotEmpty && lower == hostName.toLowerCase())) {
      return 'Listener';
    }
    return name;
  }

  // ---- Wire decoding / strict validation -------------------------------

  /// Decode one inbound payload into a Map, enforcing the byte cap and the
  /// JSON nesting cap BEFORE parsing. Returns null for anything invalid.
  Map<String, dynamic>? _decodeWireObject(dynamic rawData) {
    try {
      String str;
      if (rawData is List<int>) {
        if (rawData.length > maxPayloadBytes) return null;
        str = utf8.decode(rawData, allowMalformed: false);
      } else if (rawData is String) {
        if (rawData.length > maxPayloadBytes) return null;
        str = rawData;
      } else {
        return null;
      }
      if (_jsonNestingDepth(str) > _maxJsonDepth) return null;
      final decoded = jsonDecode(str);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Cheap pre-parse scan for JSON nesting depth, ignoring string contents.
  static int _jsonNestingDepth(String s) {
    var depth = 0;
    var maxDepth = 0;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < s.length; i++) {
      final ch = s.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == 0x5C) {
          escaped = true;
        } else if (ch == 0x22) {
          inString = false;
        }
        continue;
      }
      if (ch == 0x22) {
        inString = true;
      } else if (ch == 0x7B || ch == 0x5B) {
        depth++;
        if (depth > maxDepth) maxDepth = depth;
      } else if (ch == 0x7D || ch == 0x5D) {
        depth--;
        if (depth < 0) return _maxJsonDepth + 1; // malformed
      }
    }
    return maxDepth;
  }

  static const int _maxIdLen = 128;
  static const int _maxTitleLen = 300;
  static const int _maxArtistLen = 200;
  static const int _maxAlbumLen = 200;
  static const int _maxGenreLen = 100;
  static const int _maxMoodLen = 100;
  static const int _maxNameLen = 40;
  static const int _maxChatLen = 500;
  static const int _maxUrlLen = 2048;

  /// Remove C0 control characters, DEL and Unicode bidi-override characters
  /// (log-injection / UI-spoofing vectors) from untrusted text.
  static String _stripControlChars(String s) =>
      s.replaceAll(RegExp(r'[\x00-\x1F\x7F\u202A-\u202E]'), '');

  static String _cap(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    var cut = s.substring(0, maxLen);
    // Avoid splitting a UTF-16 surrogate pair at the cut boundary.
    final last = cut.codeUnitAt(cut.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF) {
      cut = cut.substring(0, cut.length - 1);
    }
    return cut;
  }

  /// Clean an optional free-text field: strip control chars, trim, cap.
  String? _cleanStr(dynamic v, {required int maxLen}) {
    if (v == null) return null;
    final s = _stripControlChars(v.toString()).trim();
    if (s.isEmpty) return null;
    return _cap(s, maxLen);
  }

  static double? _readNum(dynamic v) {
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is String) {
      final n = num.tryParse(v.trim());
      if (n == null || !n.isFinite) return null;
      return n.toDouble();
    }
    return null;
  }

  /// Validate an externally-supplied HTTP(S) URL against the trusted-host
  /// allowlist. Returns the cleaned URL, or null when untrusted/malformed.
  static String? _allowedRemoteUrl(dynamic v) {
    if (v == null) return null;
    final s = _stripControlChars(v.toString()).trim();
    if (s.isEmpty || s.length > _maxUrlLen) return null;
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    // Credentials embedded in the URL are always rejected.
    if (uri.userInfo.isNotEmpty) return null;
    // Only default ports are acceptable for remote media hosts.
    if (uri.port != 80 && uri.port != 443) return null;
    final host = uri.host.toLowerCase();
    // Trailing-dot DNS forms and empty hosts are rejected (the allowlist
    // check below would reject them anyway, but keep the failure explicit).
    if (host.isEmpty || host.endsWith('.')) return null;
    final allowed =
        _allowedUrlHosts.any((d) => host == d || host.endsWith('.$d'));
    if (!allowed) return null;
    return s;
  }

  static const List<String> _allowedUrlHosts = [
    'saavncdn.com',
    'jiosaavn.com',
    'cdn.jiosaavn.com',
    'i.ytimg.com',
    'music.youtube.com',
    'lh3.googleusercontent.com',
    'googlevideo.com',
    'is1-ssl.mzstatic.com',
    'itunes.apple.com',
    'jamendo.com',
    'storage.googleapis.com',
    'akamaized.net',
    'cloudfront.net',
    'images.unsplash.com',
    'i.scdn.co',
    'mosaic.scdn.co',
    'lastfm.freetls.fastly.net',
    'coverartarchive.org',
  ];

  /// Strict decoder for Song objects received over the wire. Remote input
  /// is hostile: field lengths are capped, control characters stripped,
  /// local filesystem paths dropped, local-state flags forced off, and only
  /// allowlisted HTTP(S) media hosts survive. Returns null for anything that
  /// cannot form a valid identity.
  Song? _decodeRemoteSong(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    // Identity must be a genuine, non-empty string. Coercing other JSON
    // types (numbers, maps, lists) into IDs creates anonymous collisions
    // and ambiguous queue entries, so they are rejected outright.
    final rawId = map['id'];
    if (rawId is! String) return null;
    final id = _cleanStr(rawId, maxLen: _maxIdLen);
    if (id == null || id.isEmpty) return null; // identity required
    final title =
        _cleanStr(map['title'], maxLen: _maxTitleLen) ?? 'Unknown Track';
    final artist =
        _cleanStr(map['artist'], maxLen: _maxArtistLen) ?? 'Unknown Artist';
    final album = _cleanStr(map['album'], maxLen: _maxAlbumLen);
    final genre = _cleanStr(map['genre'], maxLen: _maxGenreLen);
    final mood = _cleanStr(map['mood'], maxLen: _maxMoodLen);

    // Duration: durationMs (milliseconds) preferred; legacy 'duration' is
    // seconds. Bounded to 1ms..24h; anything outside is treated as unknown.
    var durationMs = _readNum(map['durationMs']);
    if (durationMs == null) {
      final sec = _readNum(map['duration']);
      if (sec != null) durationMs = sec * 1000;
    }
    final duration = (durationMs != null &&
            durationMs > 0 &&
            durationMs <= 24 * 60 * 60 * 1000)
        ? Duration(milliseconds: durationMs.round())
        : Duration.zero;

    // Feature vector: exactly 32 finite values within [0.0, 1.0], nothing
    // else is ever accepted as real embedding data.
    List<double> vec = List.filled(32, 0.5);
    var hasValidVector = false;
    final rawVec = map['featureVector'];
    if (rawVec != null) {
      try {
        List<dynamic> rawList;
        if (rawVec is List) {
          rawList = rawVec;
        } else {
          final decoded = jsonDecode(rawVec.toString());
          rawList = decoded is List ? decoded : <dynamic>[];
        }
        if (rawList.length == 32 && rawList.every((e) => e is num)) {
          final parsed =
              rawList.map<double>((e) => (e as num).toDouble()).toList();
          if (parsed.every((v) => v >= 0.0 && v <= 1.0)) {
            vec = parsed;
            hasValidVector = true;
          }
        }
      } catch (_) {}
    }

    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album ?? 'Single',
      artworkUrl: _allowedRemoteUrl(map['artworkUrl']),
      streamUrl: _allowedRemoteUrl(map['streamUrl']),
      // localFilePath is NEVER accepted from a remote peer.
      duration: duration,
      genre: genre,
      mood: mood,
      featureVector: vec,
      hasValidFeatureVector: hasValidVector,
    );
  }

  /// Sanitize a local (trusted-origin) Song before putting it on the wire:
  /// drop local paths and re-validate URLs/lengths so no internal detail
  /// (file paths, machine metadata) leaks to peers.
  Song _sanitizeSongForWire(Song s) => Song(
        id: _cap(_stripControlChars(s.id), _maxIdLen),
        title: _cap(_stripControlChars(s.title), _maxTitleLen),
        artist: _cap(_stripControlChars(s.artist), _maxArtistLen),
        album: _cap(_stripControlChars(s.album), _maxAlbumLen),
        artworkUrl: _allowedRemoteUrl(s.artworkUrl),
        streamUrl: _allowedRemoteUrl(s.streamUrl),
        localFilePath: null, // never leak local paths to peers
        duration: s.duration,
        genre: _cleanStr(s.genre, maxLen: _maxGenreLen),
        mood: _cleanStr(s.mood, maxLen: _maxMoodLen),
        featureVector: s.featureVector,
        hasValidFeatureVector: s.hasValidFeatureVector,
      );

  List<Map<String, dynamic>> _wireQueueSlice() => _collaborativeQueue
      .take(maxQueueLength)
      .map((s) => _sanitizeSongForWire(s).toMap())
      .toList();

  /// Strict chat-message decoder. All fields validated/bounded; returns null
  /// when the payload cannot form a usable message.
  JamChatMessage? _decodeChatMessage(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    // senderName/text must genuinely be strings; coercing other JSON types
    // (maps, lists, numbers) into display text invites confusion attacks.
    final rawSender = map['senderName'];
    final rawText = map['text'];
    if (rawSender is! String || rawText is! String) return null;
    final sender = _cleanStr(rawSender, maxLen: _maxNameLen) ?? 'Listener';
    final text = _cleanStr(rawText, maxLen: _maxChatLen);
    if (text == null || text.isEmpty) return null;
    final id = _cleanStr(map['id'], maxLen: 64) ?? '';
    final tsNum = _readNum(map['timestamp']);
    final timestamp = (tsNum != null && tsNum > 0)
        ? DateTime.fromMillisecondsSinceEpoch(tsNum.round())
        : DateTime.now();
    return JamChatMessage(
        id: id, senderName: sender, text: text, timestamp: timestamp);
  }

  void _appendChat(JamChatMessage msg) {
    _chatMessages.add(msg);
    if (_chatMessages.length > maxChatCount) {
      _chatMessages.removeRange(0, _chatMessages.length - maxChatCount);
    }
    notifyListeners();
  }

  // ---- Client side ------------------------------------------------------

  Future<bool> joinParty(String hostIp,
      {int port = 8099, String? roomSecret}) async {
    final cleanIp = hostIp.trim();
    final secret = (roomSecret ?? '').trim();
    if (!_isValidHostOrIp(cleanIp)) return false;
    if (secret.isEmpty) {
      NoctraLogger.w('joinParty refused: room secret is required.');
      return false;
    }
    await stopParty();
    final epoch = _sessionEpoch;
    _connectedHostIp = cleanIp;
    _clientRoomSecret = secret;
    _userName = 'Listener';

    if (kIsWeb) {
      NoctraLogger.w(
          'Joining a Jam room is not supported on the web platform.');
      _connectedHostIp = null;
      _clientRoomSecret = '';
      return false;
    }

    dynamic socket;
    try {
      socket = await P2PSocketEngine.connectClient(cleanIp, port);
    } catch (_) {
      socket = null;
    }
    if (socket == null || epoch != _sessionEpoch) {
      try {
        socket?.close();
      } catch (_) {}
      if (epoch == _sessionEpoch) {
        // Genuine failure (refused/timeout): end the client session state
        // cleanly rather than leaving a phantom connection.
        _connectedHostIp = null;
        _clientRoomSecret = '';
        notifyListeners();
      }
      return false;
    }

    // In-band challenge/response authentication: answer the host's one-time
    // nonce with HMAC(secret, nonce). The raw secret is never transmitted.
    var authed = false;
    final established = Completer<bool>();
    _clientSocket = socket;
    socket.listen(
      (data) {
        if (epoch != _sessionEpoch) return;
        if (!authed) {
          final obj = _decodeWireObject(data);
          if (obj != null && obj['type'] == 'jam_auth_challenge') {
            final nonce = obj['nonce'];
            if (nonce is String && nonce.isNotEmpty) {
              authed = true;
              try {
                socket.add(jsonEncode({
                  'type': 'jam_auth_response',
                  'response': _hmacHex(secret, nonce),
                }));
              } catch (_) {}
            } else if (!established.isCompleted) {
              established.complete(false);
            }
          } else if (!established.isCompleted) {
            // The first frame must be a challenge; anything else is a
            // protocol violation from the host.
            established.complete(false);
          }
          return;
        }
        _handleClientIncomingMessage(data);
        if (!established.isCompleted) established.complete(true);
      },
      onDone: () {
        if (epoch != _sessionEpoch) return;
        try {
          socket.close();
        } catch (_) {}
        _clientSocket = null;
        if (!established.isCompleted) {
          // Rejected or dropped before the room state arrived.
          established.complete(false);
          _role = SyncCastRole.idle;
          notifyListeners();
          return;
        }
        _onClientSocketClosed(epoch, cleanIp, port);
      },
      onError: (_) {
        if (epoch != _sessionEpoch) return;
        try {
          socket.close();
        } catch (_) {}
        _clientSocket = null;
        if (!established.isCompleted) {
          established.complete(false);
          _role = SyncCastRole.idle;
          notifyListeners();
          return;
        }
        _onClientSocketError(epoch);
      },
    );

    final ok = await established.future
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
    if (epoch != _sessionEpoch) return false; // session changed meanwhile
    if (!ok) {
      // Handshake failed (wrong secret, protocol violation, or timeout).
      try {
        socket.close();
      } catch (_) {}
      _clientSocket = null;
      _connectedHostIp = null;
      _clientRoomSecret = '';
      notifyListeners();
      return false;
    }
    _role = SyncCastRole.client;
    _clientRetryCount = 0;
    _lastSeenSequence = -1;
    _lastHostActivityMs = DateTime.now().millisecondsSinceEpoch;
    _startClientLivenessCheck(epoch, cleanIp, port);
    notifyListeners();
    return true;
  }

  void _onClientSocketClosed(int epoch, String hostIp, int port) {
    if (epoch != _sessionEpoch) return; // a newer session already took over
    try {
      _clientSocket?.close();
    } catch (_) {}
    _clientSocket = null;
    if (_role == SyncCastRole.client &&
        _connectedHostIp != null &&
        _clientRetryCount < 3) {
      _clientRetryCount++;
      _reconnectTimer?.cancel();
      final retrySecret = _clientRoomSecret;
      _reconnectTimer = Timer(
        Duration(milliseconds: 1200 * _clientRetryCount),
        () {
          // Only reconnect if the room session is still the one that
          // scheduled this retry and we still hold a credential.
          if (epoch != _sessionEpoch) return;
          if (retrySecret.isEmpty) {
            stopParty();
            return;
          }
          joinParty(hostIp, port: port, roomSecret: retrySecret);
        },
      );
    } else {
      stopParty();
    }
  }

  void _onClientSocketError(int epoch) {
    if (epoch != _sessionEpoch) return;
    try {
      _clientSocket?.close();
    } catch (_) {}
    _clientSocket = null;
    stopParty();
  }

  void _handleClientIncomingMessage(dynamic rawData) {
    final data = _decodeWireObject(rawData);
    if (data == null) return;
    final type = data['type'];
    if (type is! String) return;

    _lastHostActivityMs = DateTime.now().millisecondsSinceEpoch;

    if (type == 'ping') {
      if (_clientSocket != null) {
        try {
          _clientSocket.add(jsonEncode({
            'type': 'pong',
            'timestamp': data['timestamp'],
          }));
        } catch (_) {}
      }
      return;
    }
    if (type == 'pong') {
      return;
    }

    if (type == 'chat') {
      final msg = _decodeChatMessage(data['message']);
      if (msg != null) _appendChat(msg);
      return;
    }
    if (type == 'sync' || type == 'jam_full_state') {
      final incomingSession = data['sessionId'];
      if (type == 'jam_full_state') {
        if (data.containsKey('roomCode') && data['roomCode'] is String) {
          _roomCode = data['roomCode'] as String;
        }
        if (incomingSession != null && incomingSession is String) {
          _clientSessionId = incomingSession;
        }
      } else if (type == 'sync') {
        if (_clientSessionId != null &&
            incomingSession != null &&
            incomingSession is String &&
            incomingSession.isNotEmpty &&
            incomingSession != _clientSessionId) {
          // Message from a stale or foreign session — drop
          return;
        }
      }

      final incomingSeq = data['seq'];
      if (incomingSeq is int) {
        if (incomingSeq <= _lastSeenSequence) {
          // Stale / out-of-order / replayed sync packet — ignore
          return;
        }
        _lastSeenSequence = incomingSeq;
      }

      final controls = data['hostControlsOnly'];
      _hostControlsOnly = controls == true;
      if (data.containsKey('queue')) {
        _applyQueueFromHost(data['queue']);
      }
      if (data.containsKey('song') && data['song'] != null) {
        final song = _decodeRemoteSong(data['song']);
        if (song != null && _audioPlayer != null) {
          final isPlaying = data['isPlaying'] == true;
          final hostTime = _readNum(data['hostTimestamp'])?.round();
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final posMs = _readNum(data['positionMs']);
          var targetPosMs =
              (posMs != null && posMs >= 0 && posMs <= 24 * 60 * 60 * 1000)
                  ? posMs.round()
                  : 0;
          if (isPlaying && hostTime != null && nowMs > hostTime) {
            final transitMs = (nowMs - hostTime).clamp(0, 3000);
            targetPosMs += transitMs;
          }
          final position = Duration(milliseconds: targetPosMs);

          _isApplyingRemoteSync = true;
          try {
            if (_audioPlayer!.currentSong?.id != song.id) {
              unawaited(_audioPlayer!
                  .playSong(song, initialPosition: position)
                  .then((_) {
                if (!isPlaying && (_audioPlayer?.player.playing ?? false)) {
                  _audioPlayer?.pause();
                }
              }));
            } else {
              if (isPlaying && !_audioPlayer!.player.playing) {
                unawaited(_audioPlayer!.resumeOrPlay());
              } else if (!isPlaying && _audioPlayer!.player.playing) {
                _audioPlayer!.pause();
              }
              final currentPos = _audioPlayer!.player.position;
              if ((currentPos - position).inMilliseconds.abs() > 2000) {
                unawaited(_audioPlayer!.player.seek(position));
              }
            }
          } catch (e) {
            NoctraLogger.w('apply host sync failed', e);
          } finally {
            _isApplyingRemoteSync = false;
          }
        }
      } else if (data.containsKey('song') && data['song'] == null) {
        if (_audioPlayer != null && _audioPlayer!.player.playing) {
          _audioPlayer!.pause();
        }
      }
      notifyListeners();
    }
  }

  void _applyQueueFromHost(dynamic rawQueue) {
    _collaborativeQueue.clear();
    if (rawQueue is! List) return;
    for (final item in rawQueue) {
      if (_collaborativeQueue.length >= maxQueueLength) break;
      final song = _decodeRemoteSong(item);
      if (song != null && !_collaborativeQueue.any((s) => s.id == song.id)) {
        _collaborativeQueue.add(song);
      }
    }
  }

  // ---- Shared actions ---------------------------------------------------

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
          // Sanitize before sending so no local path/metadata ever leaves
          // the device (the host re-validates strictly on receipt).
          _clientSocket.add(jsonEncode({
            'type': 'add_to_queue',
            'song': _sanitizeSongForWire(song).toMap()
          }));
        } catch (_) {}
      }
    }
  }

  void removeFromCollaborativeQueue(String songId, {int? queueIndex}) {
    if (_hostControlsOnly && !isHost) return; // listeners cannot mutate
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

  void broadcastSync() {
    if (!isHost) return;
    _syncSequence++;
    final current = _audioPlayer?.currentSong;
    final sanitizedCurrent =
        current != null ? _sanitizeSongForWire(current) : null;
    final packet = jsonEncode(P2PPacket.createSyncPacket(
      song: sanitizedCurrent,
      position: _audioPlayer?.player.position ?? Duration.zero,
      isPlaying: _audioPlayer?.player.playing ?? false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      queue: _collaborativeQueue
          .take(maxQueueLength)
          .map(_sanitizeSongForWire)
          .toList(),
      hostControlsOnly: _hostControlsOnly,
      sequence: _syncSequence,
      sessionId: activeSessionId,
    ));
    _broadcastToPeers(packet);
  }

  void _broadcastToPeers(String message) {
    final dead = <dynamic>[];
    final peersSnapshot = List<dynamic>.from(_connectedPeers);
    for (final peer in peersSnapshot) {
      try {
        peer.add(message);
      } catch (e) {
        dead.add(peer);
      }
    }
    if (dead.isNotEmpty) {
      for (final peer in dead) {
        _unregisterPeer(peer);
      }
    }
  }

  Future<void> stopParty() async {
    _sessionEpoch++; // invalidate every in-flight continuation
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
    _roomSecret = ''; // previous credential must never remain valid
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
    // Close half-open (not yet authenticated) connections too.
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

  // ---- Auth-failure throttling (bounded) --------------------------------

  bool _isAuthThrottled(String ip) {
    if (ip.isEmpty) return false;
    final track = _authFailures[ip];
    if (track == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - track.windowStartMs >= P2PSyncService.authFailWindowMs) {
      _authFailures.remove(ip);
      return false;
    }
    return track.failures >= P2PSyncService.authFailLimit;
  }

  void _recordAuthFailure(String ip) {
    if (ip.isEmpty) return;
    _pruneAuthTracks();
    final now = DateTime.now().millisecondsSinceEpoch;
    final track = _authFailures[ip];
    if (track == null) {
      if (_authFailures.length >= _authTrackMaxEntries) {
        // Bound the table: evict the oldest entry before adding a new IP.
        String? oldestKey;
        int oldestStart = now;
        _authFailures.forEach((key, value) {
          if (value.windowStartMs <= oldestStart) {
            oldestStart = value.windowStartMs;
            oldestKey = key;
          }
        });
        if (oldestKey != null) _authFailures.remove(oldestKey);
      }
      _authFailures[ip] = _AuthTrack(now);
      return;
    }
    if (now - track.windowStartMs >= P2PSyncService.authFailWindowMs) {
      track.windowStartMs = now;
      track.failures = 1;
      return;
    }
    track.failures++;
  }

  void _clearAuthFailures(String ip) {
    if (ip.isNotEmpty) _authFailures.remove(ip);
  }

  void _pruneAuthTracks() {
    if (_authFailures.length < _authTrackMaxEntries) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _authFailures.removeWhere(
        (_, t) => now - t.windowStartMs >= P2PSyncService.authFailWindowMs);
  }
}

class _PeerInboundTrack {
  final _RateState general = _RateState();
  final _RateState chat = _RateState();
  int lastSeenMs = DateTime.now().millisecondsSinceEpoch;
}

/// A connection that upgraded but has not yet answered the auth challenge.
class _PendingAuth {
  final String ip;
  final String nonce;
  Timer? deadline;
  _PendingAuth(this.ip, this.nonce);
}

class _AuthTrack {
  int windowStartMs;
  int failures = 1;
  _AuthTrack(this.windowStartMs);
}
