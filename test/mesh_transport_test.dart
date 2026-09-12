import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/mesh/domain/mesh_packets.dart';
import 'package:noctra/features/mesh/infrastructure/mesh_crypto.dart';
import 'package:noctra/features/mesh/infrastructure/mesh_transport.dart';
import 'package:noctra/features/mesh/infrastructure/mesh_transport_events.dart';

class _EventSink implements MeshTransportListener {
  final events = <MeshTransportEvent>[];
  final completer = Completer<MeshTransportEvent>();
  @override
  void onEvent(MeshTransportEvent event) {
    events.add(event);
    if (!completer.isCompleted) completer.complete(event);
  }

  void reset() {
    events.clear();
  }

  List<MeshPacket> get packets =>
      events.map((e) => e.packet).whereType<MeshPacket>().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshTransport loopback (real WebSockets)', () {
    late MeshTransport host;
    late MeshTransport member;
    late _EventSink hostSink;
    late _EventSink memberSink;

    setUp(() {
      host = MeshTransport(role: MeshTransportRole.host, port: 0);
      member = MeshTransport(role: MeshTransportRole.member, port: 0);
      hostSink = _EventSink();
      memberSink = _EventSink();
      host.bindListener(hostSink);
      member.bindListener(memberSink);
    });

    tearDown(() async {
      await host.shutdown();
      await member.shutdown();
    });

    test('member joins with correct secret and receives WELCOME', () async {
      final port = await host.startHost(roomSecret: 'S3CRET', epoch: 1);
      expect(port, isNotNull);

      member.port = port!; // test host binds an ephemeral port
      final joined =
          member.joinHost('127.0.0.1', roomSecret: 'S3CRET', epoch: 1);
      final welcomeFuture = hostSink.completer.future;
      final ok = await joined.timeout(const Duration(seconds: 8),
          onTimeout: () => false);
      expect(ok, isTrue);

      // Host saw the member join.
      final joinEvent = await welcomeFuture.timeout(const Duration(seconds: 5));
      expect(joinEvent.reason, 'memberJoined');

      // Member receives the WELCOME packet.
      final welcome = memberSink.packets
          .where((p) => p.type == MeshPacketType.meshWelcome)
          .toList();
      expect(welcome, isNotEmpty);
    });

    test('member with wrong secret is rejected', () async {
      final port = await host.startHost(roomSecret: 'RIGHT', epoch: 1);
      expect(port, isNotNull);

      member.port = port!;
      final ok = await member
          .joinHost('127.0.0.1', roomSecret: 'WRONG', epoch: 1)
          .timeout(const Duration(seconds: 10), onTimeout: () => true);
      expect(ok, isFalse);

      // Give the host a beat to (not) register the member.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(host.memberCount, 0);
    });

    test('host broadcast reaches all members', () async {
      final port = await host.startHost(roomSecret: 'BCAST', epoch: 1);
      expect(port, isNotNull);
      member.port = port!;
      final ok = await member.joinHost('127.0.0.1', roomSecret: 'BCAST', epoch: 1);
      expect(ok, isTrue);
      memberSink.reset();

      host.broadcast(MeshPacket(
        type: MeshPacketType.meshAnchor,
        epoch: 1,
        seq: 2,
        senderId: 'host',
        songId: 's1',
        anchorHostMs: 12345,
        startOffsetMs: 6789,
      ));

      // Poll until the anchor lands (loopback is fast but async).
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline)) {
        if (memberSink.packets
            .any((p) => p.type == MeshPacketType.meshAnchor)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final anchor = memberSink.packets
          .firstWhere((p) => p.type == MeshPacketType.meshAnchor);
      expect(anchor.songId, 's1');
      expect(anchor.anchorHostMs, 12345);
      expect(anchor.startOffsetMs, 6789);
    });

    test('auth challenge response uses constant-time compare correctly',
        () {
      expect(MeshCrypto.constantTimeEquals('abc', 'abc'), isTrue);
      expect(MeshCrypto.constantTimeEquals('abc', 'abd'), isFalse);
      expect(MeshCrypto.constantTimeEquals('abc', 'abcd'), isFalse);
      // HMAC is deterministic for the same key/message.
      expect(MeshCrypto.hmacHex('k', 'm'), MeshCrypto.hmacHex('k', 'm'));
      expect(MeshCrypto.hmacHex('k', 'm'), isNot(MeshCrypto.hmacHex('k2', 'm')));
    });
  });
}
