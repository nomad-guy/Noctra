part of '../p2p_sync_service.dart';

extension P2PClientEngine on P2PSyncService {
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
        _connectedHostIp = null;
        _clientRoomSecret = '';
        notify();
      }
      return false;
    }

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
          established.complete(false);
          _role = SyncCastRole.idle;
          notify();
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
          notify();
          return;
        }
        _onClientSocketError(epoch);
      },
    );

    final ok = await established.future
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
    if (epoch != _sessionEpoch) return false;
    if (!ok) {
      try {
        socket.close();
      } catch (_) {}
      _clientSocket = null;
      _connectedHostIp = null;
      _clientRoomSecret = '';
      notify();
      return false;
    }
    _role = SyncCastRole.client;
    _clientRetryCount = 0;
    _lastSeenSequence = -1;
    _lastHostActivityMs = DateTime.now().millisecondsSinceEpoch;
    _startClientLivenessCheck(epoch, cleanIp, port);
    notify();
    return true;
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

  void _onClientSocketClosed(int epoch, String hostIp, int port) {
    if (epoch != _sessionEpoch) return;
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
    if (type == 'pong') return;

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
          return;
        }
      }

      final incomingSeq = data['seq'];
      if (incomingSeq is int) {
        if (incomingSeq <= _lastSeenSequence) return;
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
      notify();
    }
  }

  void _applyQueueFromHost(dynamic rawQueue) {
    _collaborativeQueue.clear();
    if (rawQueue is! List) return;
    for (final item in rawQueue) {
      if (_collaborativeQueue.length >= P2PSyncService.maxQueueLength) break;
      final song = _decodeRemoteSong(item);
      if (song != null && !_collaborativeQueue.any((s) => s.id == song.id)) {
        _collaborativeQueue.add(song);
      }
    }
  }
}
