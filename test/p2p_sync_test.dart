import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';
import 'p2p_test_helpers.dart';

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
                'response': hmacHex(secret, obj['nonce'] as String),
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
  });
}
