part of '../p2p_sync_service.dart';

/// Host-side WebSocket authentication challenge flow.
///
/// Split out of P2PHostEngine so every part file stays under the 300-LOC
/// limit: this extension owns the challenge → HMAC-response → grant/reject
/// handshake; P2PHostEngine owns session startup, heartbeats, and the
/// authenticated peer message handlers.
extension P2PHostAuthEngine on P2PSyncService {
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
    pending.deadline = Timer(P2PSyncService._authChallengeTimeout, () {
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
        if (epoch == _sessionEpoch) _onPeerSocketClosed(socket, ip);
      },
      onError: (_) {
        if (epoch == _sessionEpoch) _onPeerSocketClosed(socket, ip);
      },
    );
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
}
