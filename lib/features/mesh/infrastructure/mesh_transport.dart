import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/noctra_logger.dart';
import '../../../services/p2p/p2p_socket_engine.dart';
import '../domain/mesh_packets.dart';
import 'mesh_crypto.dart';
import 'mesh_transport_events.dart';

part 'mesh_transport_member.dart';

/// Speaker Mesh transport: a WebSocket host endpoint + member connections
/// carrying MESH_* JSON packets.
///
/// Built on the same low-level primitives as Jam (P2PSocketEngine WebSocket
/// connect, in-band HMAC challenge auth) but a fully separate protocol on
/// its own port — Jam code paths are neither modified nor invoked.
class MeshTransport implements MeshTransportListener {
  MeshTransport(
      {this.role = MeshTransportRole.member, this.port = defaultPort});

  static const int defaultPort = 8155;
  static const int maxMembers = 8;

  /// Derives the shared wire key both sides use for the HMAC challenge.
  static String memberKey(String roomSecret) => 'mesh:${roomSecret.trim()}';

  final MeshTransportRole role;
  int port;

  HttpServer? _server;
  WebSocket? _hostSocket;
  final Map<String, WebSocket> _members = {};
  final Map<WebSocket, String> _socketToMember = {};
  final Map<WebSocket, StreamSubscription> _subs = {};
  final Map<String, String> _pendingChallenge = {};
  final Map<String, int> _authFailures = {};
  Timer? _heartbeatTimer;
  StreamSubscription? _hostSocketSub;
  MeshTransportListener? _listener;
  String _roomSecret = '';
  int _epoch = 0;
  int _memberCounter = 0;
  bool _closed = true;

  static const Duration _authTimeout = Duration(seconds: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 4);
  static const int _maxAuthFailures = 12;

  int get memberCount => role == MeshTransportRole.host
      ? _members.length
      : (_hostSocket != null ? 1 : 0);
  bool get isRunning => !_closed;
  List<String> get memberIds => List.unmodifiable(_members.keys);

  void bindListener(MeshTransportListener listener) => _listener = listener;

  // ─── Host side ─────────────────────────────────────────────────────────

  /// Starts the WebSocket host endpoint. Returns the bound port, or null.
  Future<int?> startHost(
      {required String roomSecret, required int epoch}) async {
    if (kIsWeb) return null;
    _roomSecret = MeshTransport.memberKey(roomSecret);
    _epoch = epoch;
    _closed = false;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      port = _server!.port;
      _server!.listen(
        (request) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request)
                .then(_acceptMemberSocket)
                .catchError((_) {});
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.close();
          }
        },
        onError: (e) => NoctraLogger.w('Mesh host server error', e),
        cancelOnError: false,
      );
      _startHeartbeat();
      NoctraLogger.i('Mesh host listening on port $port');
      return port;
    } catch (e) {
      NoctraLogger.w('Mesh host bind failed on port $port', e);
      await shutdown();
      return null;
    }
  }

  // ─── Host: member sockets ──────────────────────────────────────────────

  Future<void> _acceptMemberSocket(WebSocket ws) async {
    if (_members.length >= maxMembers) {
      try {
        ws.close();
      } catch (_) {}
      return;
    }
    final id = 'm-${++_memberCounter}';
    final nonce = MeshCrypto.randomNonce();
    _pendingChallenge[id] = nonce;
    try {
      ws.add(jsonEncode({'type': 'mesh_auth_challenge', 'nonce': nonce}));
    } catch (_) {}

    final sub = ws.listen(
      (data) {
        if (_closed) return;
        final text = data is List<int> ? utf8.decode(data) : data as String;
        final obj = _decodeMap(text);
        if (obj == null) return;

        if (_socketToMember.containsKey(ws)) {
          _dispatchInbound(text, from: ws);
          return;
        }

        if (obj['type'] == 'mesh_auth_response') {
          final expected = MeshCrypto.hmacHex(_roomSecret, nonce);
          if (MeshCrypto.constantTimeEquals(
              obj['response']?.toString() ?? '', expected)) {
            _members[id] = ws;
            _socketToMember[ws] = id;
            _pendingChallenge.remove(id);
            _listener?.onEvent(MeshTransportEvent.memberJoined(id));
            sendToMember(
                id,
                MeshPacket(
                  type: MeshPacketType.meshWelcome,
                  epoch: _epoch,
                  seq: 0,
                  senderId: 'host',
                ));
          } else {
            final fails = (_authFailures[id] ?? 0) + 1;
            _authFailures[id] = fails;
            NoctraLogger.w('Mesh auth failed (attempt $fails)');
            if (fails >= _maxAuthFailures) {
              _authFailures.remove(id);
              NoctraLogger.w('Mesh auth: too many failures from one member');
            }
            try {
              ws.close();
            } catch (_) {}
          }
        }
      },
      onDone: () => _onMemberSocketClosed(ws),
      onError: (_) => _onMemberSocketClosed(ws),
      cancelOnError: true,
    );
    _subs[ws] = sub;

    Future.delayed(_authTimeout, () {
      if (!_socketToMember.containsKey(ws) && _subs.containsKey(ws)) {
        _onMemberSocketClosed(ws);
      }
    });
  }

  void _onMemberSocketClosed(WebSocket ws) {
    final id = _socketToMember.remove(ws);
    _subs.remove(ws)?.cancel();
    try {
      ws.close();
    } catch (_) {}
    if (id != null) {
      _members.remove(id);
      _listener?.onEvent(MeshTransportEvent.memberLeft(id));
    }
  }

  // ─── Sending ───────────────────────────────────────────────────────────

  void broadcast(MeshPacket packet) {
    final wire = packet.encode();
    if (role == MeshTransportRole.host) {
      for (final ws in List<WebSocket>.from(_members.values)) {
        try {
          ws.add(wire);
        } catch (_) {
          _onMemberSocketClosed(ws);
        }
      }
    } else {
      try {
        _hostSocket?.add(wire);
      } catch (_) {}
    }
  }

  void sendToMember(String memberId, MeshPacket packet) {
    final ws = _members[memberId];
    if (ws == null) return;
    try {
      ws.add(packet.encode());
    } catch (_) {
      _onMemberSocketClosed(ws);
    }
  }

  // ─── Inbound demux ─────────────────────────────────────────────────────

  void _dispatchInbound(String text, {WebSocket? from}) {
    final packet = MeshPacket.tryDecode(text);
    if (packet != null) {
      _listener?.onEvent(
          MeshTransportEvent.packetIn(packet, _socketToMember[from]));
      return;
    }
    final obj = _decodeMap(text);
    if (obj?['type'] == 'mesh_ping') {
      final pong = jsonEncode({'type': 'mesh_pong'});
      if (role == MeshTransportRole.member) {
        try {
          _hostSocket?.add(pong);
        } catch (_) {}
      } else if (from != null) {
        try {
          from.add(pong);
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic>? _decodeMap(String text) {
    try {
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Heartbeat & lifecycle ─────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_closed) return;
      broadcast(MeshPacket(
        type: MeshPacketType.meshState,
        epoch: _epoch,
        seq: DateTime.now().millisecondsSinceEpoch % 1000000,
      ));
    });
  }

  /// Implements [MeshTransportListener] so the transport itself can be a
  /// no-op sink in tests that don't register another listener.
  @override
  void onEvent(MeshTransportEvent event) {}

  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _hostSocketSub?.cancel();
    _hostSocketSub = null;
    try {
      await _hostSocket?.close();
    } catch (_) {}
    _hostSocket = null;
    for (final sub in List<StreamSubscription>.from(_subs.values)) {
      await sub.cancel();
    }
    _subs.clear();
    for (final ws in List<WebSocket>.from(_members.values)) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _members.clear();
    _socketToMember.clear();
    _pendingChallenge.clear();
    _authFailures.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }
}
