part of '../p2p_sync_service.dart';

extension P2PDiscoveryEngine on P2PSyncService {
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
        P2PSyncService.beaconPort,
      );
    } catch (_) {}
  }

  Future<void> startDiscovery() async {
    if (kIsWeb) return;
    stopDiscovery();
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        P2PSyncService.beaconPort,
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
        if (_discoveredRooms.length != beforeCount) notify();
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
        notify();
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
      notify();
    }
  }
}
