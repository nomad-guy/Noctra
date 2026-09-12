part of 'mesh_transport.dart';

/// Member-side join logic (split to keep the transport core ≤300 LOC).
extension MeshTransportMemberJoin on MeshTransport {
  /// Connects to a mesh host and performs the auth handshake.
  Future<bool> joinHost(String hostIp,
      {required String roomSecret, required int epoch}) async {
    if (kIsWeb) return false;
    _roomSecret = MeshTransport.memberKey(roomSecret);
    _epoch = epoch;
    _closed = false;
    try {
      final ws = await P2PSocketEngine.connectClient(hostIp, port);
      if (ws == null) {
        await shutdown();
        return false;
      }
      _hostSocket = ws;

      final authed = Completer<bool>();
      _hostSocketSub = ws.listen(
        (data) {
          if (_closed) return;
          final text = data is List<int> ? utf8.decode(data) : data as String;
          if (!authed.isCompleted) {
            final obj = _decodeMap(text);
            if (obj?['type'] == 'mesh_auth_challenge') {
              final nonce = obj!['nonce']?.toString() ?? '';
              if (nonce.isNotEmpty) {
                _hostSocket?.add(jsonEncode({
                  'type': 'mesh_auth_response',
                  'response': MeshCrypto.hmacHex(_roomSecret, nonce),
                }));
                return;
              }
              authed.complete(false);
              return;
            }
            authed.complete(true);
          }
          _dispatchInbound(text, from: null);
        },
        onDone: () {
          if (_closed) return;
          _hostSocket = null;
          // Closed before the handshake completed → wrong secret or refusal.
          if (!authed.isCompleted) authed.complete(false);
          _listener?.onEvent(const MeshTransportEvent.custom('hostLost'));
        },
        onError: (_) {
          if (_closed) return;
          _hostSocket = null;
          if (!authed.isCompleted) authed.complete(false);
          _listener?.onEvent(const MeshTransportEvent.custom('hostLost'));
        },
        cancelOnError: true,
      );

      final ok = await authed.future
          .timeout(MeshTransport._authTimeout, onTimeout: () => false);
      if (!ok) {
        await shutdown();
        return false;
      }
      // ignore: avoid_redundant_argument_values
      NoctraLogger.i('Mesh joined host $hostIp:$port');
      return true;
    } catch (e) {
      NoctraLogger.w('Mesh join failed: $hostIp:$port', e);
      await shutdown();
      return false;
    }
  }
}
