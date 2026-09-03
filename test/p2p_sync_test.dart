import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';

String _hmacHex(String key, String message) {
  final hmac = Hmac(sha256, utf8.encode(key));
  return hmac.convert(utf8.encode(message)).toString();
}

/// Real-network regression tests for the Jam P2P layer. These exercise the
/// PRODUCTION validation path end to end: a real HttpServer/WebSocket host
/// bound on loopback, a real authenticated client, and raw (possibly
/// hostile) WebSocket peers sending hand-crafted packets.
///
/// The service is a singleton in production, so tests use the
/// [P2PSyncService.newForTest] escape hatch to get independent instances.
void main() {
  late P2PSyncService host;
  late P2PSyncService client;

  setUp(() {
    // Restore default rate-limit knobs before every test.
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

  Future<bool> waitFor(
    bool Function() cond, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (cond()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    return cond();
  }

  /// Open a raw WebSocket against the host and complete the in-band
  /// challenge/response handshake with the given (or correct) secret.
  ///
  /// The returned socket is an authenticated peer of the host. A persistent
  /// listener stays attached so the connection survives the host's
  /// broadcasts (dart:io WebSockets close when data arrives with no active
  /// subscription).
  Future<WebSocket> connectRaw(P2PSyncService h, {String? secret}) async {
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
      }
    }, onDone: () {
      if (!handshake.isCompleted) handshake.complete();
    });
    await handshake.future.timeout(const Duration(seconds: 4));
    return ws;
  }

  /// Attempt a full raw challenge/response handshake with an arbitrary
  /// secret. True only when the host accepts it and sends the room state.
  Future<bool> tryRawConnect(P2PSyncService h, String secret) async {
    final outcome = Completer<bool>();
    try {
      final ws = await WebSocket.connect('ws://127.0.0.1:${h.boundPort}/ws')
          .timeout(const Duration(seconds: 3));
      var answered = false;
      ws.listen((dynamic d) {
        if (!answered) {
          answered = true;
          try {
            final obj = jsonDecode(d as String) as Map<String, dynamic>;
            if (obj['type'] == 'jam_auth_challenge' && obj['nonce'] is String) {
              ws.add(jsonEncode({
                'type': 'jam_auth_response',
                'response': _hmacHex(secret, obj['nonce'] as String),
              }));
            }
          } catch (_) {}
          return;
        }
        try {
          final obj = jsonDecode(d as String) as Map<String, dynamic>;
          if (obj['type'] == 'jam_full_state' && !outcome.isCompleted) {
            outcome.complete(true);
          }
        } catch (_) {}
      }, onDone: () {
        if (!outcome.isCompleted) outcome.complete(false);
      }, onError: (_) {
        if (!outcome.isCompleted) outcome.complete(false);
      });
      return await outcome.future.timeout(const Duration(seconds: 5),
          onTimeout: () {
        if (!outcome.isCompleted) outcome.complete(false);
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  group('authentication', () {
    test('joinParty refuses when no room secret is provided', () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(
          await client.joinParty('127.0.0.1', port: host.boundPort!), isFalse);
      expect(client.isClient, isFalse);
      expect(client.isIdle, isTrue);
    });

    test('client with correct secret joins and is registered as a peer',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(host.roomSecret.length, greaterThan(40));
      final joined = await client.joinParty('127.0.0.1',
          port: host.boundPort!, roomSecret: host.roomSecret);
      expect(joined, isTrue);
      expect(client.isClient, isTrue);
      expect(await waitFor(() => host.connectedPeersCount >= 2), isTrue);
      // The raw secret is never transmitted over the wire: the client only
      // proves knowledge of it by MACing the host's one-time nonce, so the
      // host never needs to (and must not) echo it in any state payload.
      expect(client.roomCode, isNot(host.roomSecret));
    });

    test('client with a wrong secret is rejected and no peer is registered',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final joined = await client.joinParty('127.0.0.1',
          port: host.boundPort!, roomSecret: 'WRONG-SECRET-FOR-TEST');
      expect(joined, isFalse);
      expect(host.connectedPeersCount, 1); // host alone
      expect(client.isIdle, isTrue);
    });

    test('repeated auth failures are throttled per IP and recover', () async {
      P2PSyncService.authFailLimit = 2;
      P2PSyncService.authFailWindowMs = 600;
      expect(await host.startHost(port: 0), isTrue);

      // Two wrong attempts burn the per-IP budget.
      expect(await tryRawConnect(host, 'bad-secret-1'), isFalse);
      expect(await tryRawConnect(host, 'bad-secret-2'), isFalse);

      // While throttled, even the CORRECT secret is refused (fail-closed).
      expect(await tryRawConnect(host, host.roomSecret), isFalse);
      expect(host.connectedPeersCount, 1);

      // After the window expires the correct secret authenticates again.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final ws = await connectRaw(host);
      expect(await waitFor(() => host.connectedPeersCount >= 2), isTrue);
      await ws.close();
    });

    test('a previous room secret cannot authenticate a new host session',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final oldSecret = host.roomSecret;
      final oldPort = host.boundPort!;
      await host.stopParty();

      // Old room is gone: the old credential must fail.
      expect(
          await client.joinParty('127.0.0.1',
              port: oldPort, roomSecret: oldSecret),
          isFalse);

      // New room: secret regenerated, old one is not accepted.
      expect(await host.startHost(port: 0), isTrue);
      expect(host.roomSecret, isNot(oldSecret));
      final joined = await client.joinParty('127.0.0.1',
          port: host.boundPort!, roomSecret: oldSecret);
      expect(joined, isFalse);
      expect(host.connectedPeersCount, 1);

      final joined2 = await client.joinParty('127.0.0.1',
          port: host.boundPort!, roomSecret: host.roomSecret);
      expect(joined2, isTrue);
      expect(await waitFor(() => host.connectedPeersCount >= 2), isTrue);
    });

    test('raw peer answering the challenge with a wrong secret is rejected',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      expect(await tryRawConnect(host, 'totally-wrong-secret'), isFalse);
      // The failed peer never becomes a registered peer.
      expect(await waitFor(() => host.connectedPeersCount == 1), isTrue);
    });
  });

  group('host inbound validation', () {
    test('malformed, oversized, and unknown packets never mutate state',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      ws.add('[1,2,3]'); // non-map JSON
      ws.add(jsonEncode({'foo': 'bar'})); // missing type
      ws.add(jsonEncode({'type': 123})); // non-string type
      ws.add('{{{ definitely not json'); // malformed
      ws.add('x' * 70000); // exceeds maxPayloadBytes
      // chat whose text/sender are the wrong JSON types
      ws.add(jsonEncode({
        'type': 'chat',
        'message': {'senderName': 42, 'text': 42}
      }));

      await Future<void>.delayed(const Duration(milliseconds: 500));
      // Only the host's own system message exists; the peer is still up.
      expect(host.chatMessages.length, 1);
      expect(host.connectedPeersCount, 2);

      // The host remains fully functional.
      ws.add(jsonEncode({
        'type': 'chat',
        'message': {
          'id': 'ok',
          'senderName': 'Alice',
          'text': 'ping',
          'timestamp': 1
        }
      }));
      expect(await waitFor(() => host.chatMessages.length >= 2), isTrue);
      await ws.close();
    });

    test('chat relay strips control characters and reserved sender names',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      ws.add(jsonEncode({
        'type': 'chat',
        'message': {
          'id': 'c1',
          'senderName': 'System',
          'text': '  hello\u0000\u202Eworld  ',
          'timestamp': 1,
        }
      }));
      expect(
          await waitFor(
              () => host.chatMessages.any((m) => m.text == 'helloworld')),
          isTrue);
      final msg = host.chatMessages.firstWhere((m) => m.text == 'helloworld');
      // 'System' is reserved: peer claiming it is renamed at the relay.
      expect(msg.senderName, isNot('System'));
      expect(msg.text.contains('\u0000'), isFalse);
      expect(msg.text.contains('\u202E'), isFalse);
      await ws.close();
    });

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
      expect(song.streamUrl, isNull); // javascript: scheme rejected
      expect(song.artworkUrl, 'https://saavncdn.com/ok.jpg');
      expect(song.localFilePath, isNull); // never accepted from peers
      expect(song.duration, Duration.zero); // absurd duration -> unknown
      expect(song.artist.length, lessThanOrEqualTo(200));
      await ws.close();
    });

    test('remote song with an invalid identity is rejected entirely', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      // Numeric id and empty-string id are both invalid identities.
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

    test('hostControlsOnly blocks listener queue mutations server-side',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      // Seed one entry while open, then lock the queue down.
      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {
          'id': 'a',
          'title': 'A',
          'artist': 'Art',
          'durationMs': 1000,
        }
      }));
      expect(await waitFor(() => host.collaborativeQueue.length == 1), isTrue);

      host.toggleHostControlsOnly();
      expect(host.hostControlsOnly, isTrue);

      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {'id': 'b', 'title': 'B', 'artist': 'Art', 'durationMs': 1000}
      }));
      ws.add(jsonEncode({'type': 'remove_from_queue', 'songId': 'a'}));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(host.collaborativeQueue.length, 1); // 'b' rejected, 'a' kept
      expect(host.collaborativeQueue.first.id, 'a');
      await ws.close();
    });

    test('remove_from_queue with a non-string id is rejected', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);
      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {'id': 'a', 'title': 'A', 'artist': 'Art', 'durationMs': 1000}
      }));
      expect(await waitFor(() => host.collaborativeQueue.length == 1), isTrue);
      ws.add(jsonEncode({'type': 'remove_from_queue', 'songId': 42}));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(host.collaborativeQueue.length, 1);
      await ws.close();
    });

    test('shared queue is capped and duplicates collapse', () async {
      // Raise the inbound cap so the many add packets are not mistaken for
      // a message flood.
      P2PSyncService.inboundLimitPerWindow = 10000;
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      for (var i = 0; i < P2PSyncService.maxQueueLength + 100; i++) {
        ws.add(jsonEncode({
          'type': 'add_to_queue',
          'song': {
            'id': 'song-$i',
            'title': 'Title $i',
            'artist': 'Art',
            'durationMs': 1000,
          }
        }));
      }
      expect(
          await waitFor(() =>
              host.collaborativeQueue.length >= P2PSyncService.maxQueueLength),
          isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(host.collaborativeQueue.length, P2PSyncService.maxQueueLength);
      // No duplicate identities in the queue.
      final ids = host.collaborativeQueue.map((s) => s.id).toSet();
      expect(ids.length, host.collaborativeQueue.length);
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
  });

  group('client trust boundary', () {
    /// A deliberately malicious fake host: no secret check, hostile payload.
    Future<HttpServer> startFakeHost(String payloadJson) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((socket) {
            // Speak the challenge protocol the production client expects:
            // issue a nonce, then (whatever the response says) send the
            // hostile payload once the client's auth response arrives.
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
      final hostileState = jsonEncode({
        'type': 'jam_full_state',
        'roomCode': 'JAM-0000',
        'hostControlsOnly': false,
        'queue': [
          {
            'id': 'ok-1',
            'title': 'Fine',
            'artist': 'Artist',
            'durationMs': 1000,
            'streamUrl': 'https://googlevideo.com/v.mp4',
            'localFilePath': '/data/user/0/host/files/secret.mp3',
          },
          {
            'id': 123,
            'title': 'Bad id',
            'artist': 'Artist',
            'durationMs': 1000,
          },
          {
            'id': 'ok-2',
            'title': 'Evil stream',
            'artist': 'Artist',
            'durationMs': 1000,
            'streamUrl': 'file:///etc/passwd',
            'featureVector': 'not-a-vector',
          },
        ],
      });
      final fake = await startFakeHost(hostileState);
      addTearDown(() async => fake.close(force: true));

      final joined = await client.joinParty('127.0.0.1',
          port: fake.port, roomSecret: 'whatever');
      expect(joined, isTrue);
      expect(await waitFor(() => client.collaborativeQueue.isNotEmpty), isTrue);

      final byId = {
        for (final s in client.collaborativeQueue) s.id: s,
      };
      // The numeric-id entry is rejected outright; the valid-id entries are
      // kept but sanitized (local path and file:// stream dropped, corrupt
      // vector never flagged as real data).
      expect(byId.keys.toList()..sort(), ['ok-1', 'ok-2']);
      final ok1 = byId['ok-1']!;
      expect(ok1.localFilePath, isNull);
      expect(ok1.streamUrl, 'https://googlevideo.com/v.mp4');
      expect(ok1.hasValidFeatureVector, isFalse);
      final ok2 = byId['ok-2']!;
      expect(ok2.streamUrl, isNull); // file:// scheme rejected
      expect(ok2.hasValidFeatureVector, isFalse);
      expect(ok2.localFilePath, isNull);
    });

    test('client caps an oversized hostile queue', () async {
      final queue = List.generate(
          300,
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
      // A new peer can join the second room normally.
      final joined = await client.joinParty('127.0.0.1',
          port: host.boundPort!, roomSecret: host.roomSecret);
      expect(joined, isTrue);
      expect(await waitFor(() => host.connectedPeersCount >= 2), isTrue);
    });
  });
}
