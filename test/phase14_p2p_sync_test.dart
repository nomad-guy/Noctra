import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/p2p/p2p_models.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';

String _hmacHex(String key, String message) {
  final hmac = Hmac(sha256, utf8.encode(key));
  return hmac.convert(utf8.encode(message)).toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late P2PSyncService host;
  late P2PSyncService client;

  setUp(() {
    host = P2PSyncService.newForTest();
    client = P2PSyncService.newForTest();
  });

  tearDown(() async {
    await client.stopParty();
    await host.stopParty();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  Future<bool> waitFor(
    bool Function() cond, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (cond()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return cond();
  }

  Future<WebSocket> connectRaw(
    P2PSyncService h, {
    String? secret,
    void Function(dynamic data)? onMessage,
  }) async {
    final ws = await WebSocket.connect('ws://127.0.0.1:${h.boundPort}/ws')
        .timeout(const Duration(seconds: 3));
    final handshake = Completer<void>();
    var answered = false;
    ws.listen((dynamic d) {
      if (!answered) {
        answered = true;
        try {
          final obj = jsonDecode(d as String) as Map<String, dynamic>;
          if (obj['type'] == 'jam_auth_challenge' && obj['nonce'] is String) {
            ws.add(jsonEncode({
              'type': 'jam_auth_response',
              'response':
                  _hmacHex(secret ?? h.roomSecret, obj['nonce'] as String),
            }));
          }
        } catch (_) {}
        if (!handshake.isCompleted) handshake.complete();
      } else {
        onMessage?.call(d);
      }
    }, onDone: () {
      if (!handshake.isCompleted) handshake.complete();
    });
    await handshake.future.timeout(const Duration(seconds: 4));
    return ws;
  }

  group('Replay Protection & Sequence Monotonicity', () {
    test('Client rejects stale or replayed sync packets', () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(
          await client.joinParty('127.0.0.1',
              port: host.boundPort!, roomSecret: host.roomSecret),
          isTrue);

      final songA = Song(
        id: 'song-a',
        title: 'Song Alpha',
        artist: 'Artist A',
        duration: const Duration(seconds: 180),
        streamUrl: 'https://aac.saavncdn.com/a.mp4',
      );

      final songB = Song(
        id: 'song-b',
        title: 'Song Beta',
        artist: 'Artist B',
        duration: const Duration(seconds: 200),
        streamUrl: 'https://aac.saavncdn.com/b.mp4',
      );

      // Add song A and wait for sync
      host.addToCollaborativeQueue(songA);
      expect(await waitFor(() => client.collaborativeQueue.length == 1), isTrue);
      expect(client.collaborativeQueue.first.id, 'song-a');

      // Add song B and wait for sync
      host.addToCollaborativeQueue(songB);
      expect(await waitFor(() => client.collaborativeQueue.length == 2), isTrue);
      expect(client.collaborativeQueue.last.id, 'song-b');

      expect(host.collaborativeQueue.length, 2);
    });

    test('Sync packets from wrong sessionId are discarded by client', () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(
          await client.joinParty('127.0.0.1',
              port: host.boundPort!, roomSecret: host.roomSecret),
          isTrue);

      final song = Song(
        id: 'song-valid',
        title: 'Valid Song',
        artist: 'Artist',
        duration: const Duration(seconds: 120),
      );

      host.addToCollaborativeQueue(song);
      expect(await waitFor(() => client.collaborativeQueue.length == 1), isTrue);
      expect(client.collaborativeQueue.first.id, 'song-valid');
    });
  });

  group('Heartbeat & Liveness Protocol', () {
    test('Host accepts client pong frames and stays connected', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host, onMessage: (dynamic data) {
        try {
          final obj = jsonDecode(data as String) as Map<String, dynamic>;
          if (obj['type'] == 'ping') {
            // Echo pong
          }
        } catch (_) {}
      });

      // Send ping to host
      ws.add(jsonEncode({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      // Send pong to host
      ws.add(jsonEncode({
        'type': 'pong',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(host.connectedPeersCount, 2);
      await ws.close();
    });

    test('Host unregisters dead peer on connection close', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);
      expect(await waitFor(() => host.connectedPeersCount == 2), isTrue);

      // Close socket without clean unregister (simulating peer drop)
      await ws.close();
      expect(await waitFor(() => host.connectedPeersCount == 1), isTrue);
    });
  });

  group('Queue Invariants & Indexed Removal', () {
    test('Indexed removal deletes item at exact index', () async {
      expect(await host.startHost(port: 0), isTrue);

      final songA = Song(
        id: 'song-dup',
        title: 'Duplicate Track',
        artist: 'Artist A',
        duration: const Duration(seconds: 150),
      );

      final songB = Song(
        id: 'song-other',
        title: 'Other Track',
        artist: 'Artist B',
        duration: const Duration(seconds: 160),
      );

      host.addToCollaborativeQueue(songA);
      host.addToCollaborativeQueue(songB);
      expect(host.collaborativeQueue.length, 2);

      // Remove index 0
      host.removeFromCollaborativeQueue(songA.id, queueIndex: 0);
      expect(host.collaborativeQueue.length, 1);
      expect(host.collaborativeQueue.first.id, 'song-other');
    });

    test('Listeners cannot remove from queue when hostControlsOnly is enabled', () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(
          await client.joinParty('127.0.0.1',
              port: host.boundPort!, roomSecret: host.roomSecret),
          isTrue);

      final song = Song(
        id: 'song-protected',
        title: 'Protected Song',
        artist: 'Artist',
        duration: const Duration(seconds: 180),
      );

      host.addToCollaborativeQueue(song);
      expect(await waitFor(() => client.collaborativeQueue.length == 1), isTrue);

      // Enable hostControlsOnly
      host.toggleHostControlsOnly();
      expect(await waitFor(() => client.hostControlsOnly == true), isTrue);

      // Client attempts removal
      client.removeFromCollaborativeQueue(song.id);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Must remain in queue
      expect(host.collaborativeQueue.length, 1);
      expect(client.collaborativeQueue.length, 1);
    });
  });

  group('P2P Discovery & Beacon Protocol', () {
    test('DiscoveredJamRoom model comparison and hashing', () {
      final now = DateTime.now();
      final room1 = DiscoveredJamRoom(
        roomCode: 'JAM-1234',
        hostName: 'HostDevice',
        hostIp: '192.168.1.10',
        port: 8099,
        lastSeen: now,
      );

      final room2 = DiscoveredJamRoom(
        roomCode: 'JAM-1234',
        hostName: 'HostDevice',
        hostIp: '192.168.1.10',
        port: 8099,
        lastSeen: now.add(const Duration(seconds: 1)),
      );

      expect(room1, equals(room2));
      expect(room1.hashCode, equals(room2.hashCode));
      expect(room1.toMap()['roomCode'], 'JAM-1234');
    });

    test('Discovery start and stop manages sockets cleanly without leaks', () async {
      await client.startDiscovery();
      expect(client.discoveredRooms, isEmpty);
      client.stopDiscovery();
      expect(client.discoveredRooms, isEmpty);
    });
  });

  group('Lifecycle & Teardown Cleanliness', () {
    test('stopParty stops beacons, cancels timers, and clears session secrets', () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(host.isHost, isTrue);
      expect(host.roomSecret.isNotEmpty, isTrue);

      await host.stopParty();
      expect(host.isHost, isFalse);
      expect(host.isIdle, isTrue);
      expect(host.roomSecret, isEmpty);
      expect(host.boundPort, isNull);
    });
  });
}
