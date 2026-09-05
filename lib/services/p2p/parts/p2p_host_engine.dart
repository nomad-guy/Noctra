part of '../p2p_sync_service.dart';

extension P2PHostEngine on P2PSyncService {
  Future<bool> startHost({int? port}) async {
    await stopParty();
    final epoch = _sessionEpoch;
    _role = SyncCastRole.host;
    _port = port ?? 8099;
    _roomCode = _generateRoomCode();
    _roomSecret = _generateRoomSecret();
    _localIp = await P2PSocketEngine.findLocalIp();

    final server = await P2PSocketEngine.bindServer(_port);
    _server = server;
    if (server == null || epoch != _sessionEpoch) {
      try {
        server?.close(force: true);
      } catch (_) {}
      if (epoch == _sessionEpoch) {
        _role = SyncCastRole.idle;
        _roomSecret = '';
        notify();
      }
      return false;
    }

    server.listen((request) {
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
      if (_isAuthThrottled(ip)) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.close();
        return;
      }
      if (_connectedPeers.length >= P2PSyncService.maxPeers ||
          _pendingAuth.length >= P2PSyncService._maxPendingAuth) {
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
    _collaborativeQueue.clear();
    _authFailures.clear();
    _chatMessages.clear();
    _chatMessages.add(JamChatMessage(
      id: 'system_init',
      senderName: 'System',
      text: 'Noctra Jam Room "$_roomCode" online.',
      timestamp: DateTime.now(),
    ));
    _attachPlayerListeners();
    _startHostHeartbeat(epoch);
    _startBeaconBroadcast();
    notify();
    return true;
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

  void _handlePeerSocketMessage(
      dynamic socket, dynamic rawData, int epoch, String ip) {
    if (epoch != _sessionEpoch) return;
    final pending = _pendingAuth[socket];
    if (pending != null) {
      _attemptAuth(socket, pending, rawData, epoch, ip);
      return;
    }
    _handleHostIncomingMessage(socket, rawData, epoch);
  }

  void _onPeerSocketClosed(dynamic socket, String ip) {
    if (_pendingAuth.remove(socket) != null) {
      _recordAuthFailure(ip);
      return;
    }
    _unregisterPeer(socket);
  }

  void _grantPeer(dynamic socket, int epoch) {
    if (epoch != _sessionEpoch) {
      try {
        socket.close();
      } catch (_) {}
      return;
    }
    _connectedPeers.add(socket);
    _peerTracks[socket] = _PeerInboundTrack();
    notify();

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
    } catch (_) {}
  }

  void _unregisterPeer(dynamic socket) {
    final wasPresent = _connectedPeers.remove(socket);
    _peerTracks.remove(socket);
    if (wasPresent) notify();
  }

  void _dropPeer(dynamic socket) {
    _unregisterPeer(socket);
    try {
      socket.close();
    } catch (_) {}
  }

  void _handleHostIncomingMessage(dynamic socket, dynamic rawData, int epoch) {
    if (epoch != _sessionEpoch) return;

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
    if (data == null) return;
    final type = data['type'];
    if (type is! String || type.isEmpty) return;

    if (type == 'pong') return;
    if (type == 'ping') {
      try {
        socket
            .add(jsonEncode({'type': 'pong', 'timestamp': data['timestamp']}));
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
            notify();
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
        break;
    }
  }

  void _handlePeerChat(dynamic socket, dynamic raw) {
    final msg = _decodeChatMessage(raw);
    if (msg == null) return;
    final sanitized = JamChatMessage(
      id: msg.id,
      senderName: _safePeerSenderName(msg.senderName),
      text: msg.text,
      timestamp: msg.timestamp,
    );
    _appendChat(sanitized);
    _broadcastToPeers(jsonEncode(P2PPacket.createChatPacket(sanitized)));
  }
}
