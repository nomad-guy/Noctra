import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';
import 'p2p_test_helpers.dart';

void main() {
  late P2PSyncService host;
  late P2PSyncService client;

  setUp(() {
    P2PSyncService.inboundWindowMs = 2000;
    P2PSyncService.inboundLimitPerWindow = 40;
    P2PSyncService.chatWindowMs = 2000;
    P2PSyncService.chatLimitPerWindow = 12;
    P2PSyncService.authFailLimit = 6;
    P2PSyncService.authFailWindowMs = 30000;
    host = P2PSyncService.newForTest();
    client = P2PSyncService.newForTest();
  });

  tearDown(() async {
    await client.stopParty();
    await host.stopParty();
    await Future<void>.delayed(const Duration(milliseconds: 40));
  });

  group('host inbound validation', () {
    test('remote songs added to the shared queue are strictly sanitized',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {
          'id': 'remote-1',
          'title': 'Evil\u0000Title',
          'artist': 'A' * 500,
          'album': 'X',
          'streamUrl': 'javascript:alert(1)',
          'artworkUrl': 'https://saavncdn.com/ok.jpg',
          'localFilePath': '/etc/passwd',
          'durationMs': 99999999999,
          'featureVector': List<double>.filled(32, 0.5),
        }
      }));
      expect(await waitFor(() => host.collaborativeQueue.isNotEmpty), isTrue);
      final song = host.collaborativeQueue.first;
      expect(song.id, 'remote-1');
      expect(song.title.contains('Evil'), isTrue);
      expect(song.title.contains('\u0000'), isFalse);
      expect(song.streamUrl, isNull);
      expect(song.artworkUrl, 'https://saavncdn.com/ok.jpg');
      expect(song.localFilePath, isNull);
      expect(song.duration, Duration.zero);
      expect(song.artist.length, lessThanOrEqualTo(200));
      await ws.close();
    });

    test('remote song with an invalid identity is rejected entirely', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {'id': 123, 'title': 'X'}
      }));
      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {'id': '   ', 'title': 'X'}
      }));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(host.collaborativeQueue, isEmpty);
      await ws.close();
    });

    test('shared queue is capped and duplicates collapse', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      for (var i = 0; i < 5; i++) {
        ws.add(jsonEncode({
          'type': 'add_to_queue',
          'song': {'id': 'dup-1', 'title': 'T'}
        }));
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(host.collaborativeQueue.length, 1);
      await ws.close();
    });
  });

  group('resource limits', () {
    test('a peer flooding chat is dropped while the room stays healthy',
        () async {
      P2PSyncService.chatLimitPerWindow = 5;
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      for (var i = 0; i < 30; i++) {
        ws.add(jsonEncode({
          'type': 'chat',
          'message': {
            'id': 'f$i',
            'senderName': 'Flooder',
            'text': 'msg $i',
            'timestamp': 1
          }
        }));
      }
      // The flooder is dropped: host is back to being alone.
      expect(await waitFor(() => host.connectedPeersCount == 1), isTrue);
      // Only messages under the limit were appended (1 = system message).
      expect(host.chatMessages.length,
          lessThanOrEqualTo(1 + P2PSyncService.chatLimitPerWindow));

      // After the window expires a new peer can join and chat normally.
      P2PSyncService.chatLimitPerWindow = 12;
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      final ws2 = await connectRaw(host);
      ws2.add(jsonEncode({
        'type': 'chat',
        'message': {
          'id': 'after',
          'senderName': 'NewPeer',
          'text': 'still works',
          'timestamp': 1
        }
      }));
      expect(
          await waitFor(
              () => host.chatMessages.any((m) => m.text == 'still works')),
          isTrue);
      await ws2.close();
    });

    test('frames larger than maxPayloadBytes are dropped without parsing',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      final huge = 'A' * (P2PSyncService.maxPayloadBytes + 1024);
      ws.add(jsonEncode({
        'type': 'chat',
        'message': {'id': 'h', 'senderName': 'X', 'text': huge, 'timestamp': 1}
      }));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(host.chatMessages.length, 1);

      ws.add(jsonEncode({
        'type': 'chat',
        'message': {'id': 'ok', 'senderName': 'X', 'text': 'ok', 'timestamp': 1}
      }));
      expect(
          await waitFor(() => host.chatMessages.any((m) => m.text == 'ok')),
          isTrue);
      await ws.close();
    });

    test('deeply nested JSON depth bombs are rejected before mutation',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      final bomb = '${'{"a":' * 120}1${'}' * 120}';
      ws.add(bomb);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final ws2 = await connectRaw(host);
      ws2.add(jsonEncode({
        'type': 'chat',
        'message': {
          'id': 'after',
          'senderName': 'NewPeer',
          'text': 'still works',
          'timestamp': 1
        }
      }));
      expect(
          await waitFor(
              () => host.chatMessages.any((m) => m.text == 'still works')),
          isTrue);
      await ws.close();
      await ws2.close();
    });
  });

  group('client trust boundary', () {
    Future<HttpServer> startFakeHost(String payloadJson) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((socket) {
            socket.add(jsonEncode({
              'type': 'jam_auth_challenge',
              'nonce': 'dGVzdC1ub25jZQ',
            }));
            socket.listen((_) {
              socket.add(payloadJson);
            });
          }).catchError((Object e) {});
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });
      return server;
    }

    test('client sanitizes a hostile host queue and never stores local paths',
        () async {
      final fake = await startFakeHost(jsonEncode({
        'type': 'jam_full_state',
        'hostControlsOnly': false,
        'queue': [
          {
            'id': 'h-1',
            'title': 'Track 1',
            'artist': 'Artist 1',
            'localFilePath': 'C:\\secret\\file.txt',
            'streamUrl': 'https://saavncdn.com/track.mp4',
            'durationMs': 120000,
          }
        ],
      }));
      addTearDown(() async => fake.close(force: true));

      expect(
          await client.joinParty('127.0.0.1', port: fake.port, roomSecret: 'x'),
          isTrue);
      expect(
          await waitFor(() => client.collaborativeQueue.isNotEmpty), isTrue);
      final song = client.collaborativeQueue.first;
      expect(song.localFilePath, isNull);
      expect(song.streamUrl, 'https://saavncdn.com/track.mp4');
    });

    test('client caps an oversized hostile queue', () async {
      final queue = List.generate(
          P2PSyncService.maxQueueLength + 150,
          (i) => {
                'id': 'q-$i',
                'title': 'Title $i',
                'artist': 'A',
                'durationMs': 1000,
              });
      final fake = await startFakeHost(jsonEncode({
        'type': 'jam_full_state',
        'hostControlsOnly': false,
        'queue': queue,
      }));
      addTearDown(() async => fake.close(force: true));

      expect(
          await client.joinParty('127.0.0.1', port: fake.port, roomSecret: 'x'),
          isTrue);
      expect(
          await waitFor(() =>
              client.collaborativeQueue.length ==
              P2PSyncService.maxQueueLength),
          isTrue);
    });
  });

  group('lifecycle', () {
    test('stopParty clears the credential and leaves the service idle',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(host.roomSecret, isNotEmpty);
      await host.stopParty();
      expect(host.isIdle, isTrue);
      expect(host.roomSecret, isEmpty);
      expect(host.boundPort, isNull);
      expect(host.connectedPeersCount, 0);
    });

    test('rapid stopParty/startHost does not leak state between sessions',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final firstSecret = host.roomSecret;
      await host.stopParty();
      expect(await host.startHost(port: 0), isTrue);
      expect(host.roomSecret, isNot(firstSecret));
      expect(host.collaborativeQueue, isEmpty);
      final joined = await client.joinParty('127.0.0.1',
          port: host.boundPort!, roomSecret: host.roomSecret);
      expect(joined, isTrue);
      expect(await waitFor(() => host.connectedPeersCount >= 2), isTrue);
    });
  });
}
