import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/mesh/domain/mesh_packets.dart';

void main() {
  group('MeshPacket codec', () {
    test('ANCHOR round-trips fully', () {
      final p = MeshPacket(
        type: MeshPacketType.meshAnchor,
        epoch: 3,
        seq: 42,
        senderId: 'host-1',
        songId: 'song_abc',
        anchorHostMs: 1700000000000,
        startOffsetMs: 12500,
      );
      final back = MeshPacket.tryDecode(p.encode());
      expect(back, isNotNull);
      expect(back!.type, MeshPacketType.meshAnchor);
      expect(back.epoch, 3);
      expect(back.seq, 42);
      expect(back.senderId, 'host-1');
      expect(back.songId, 'song_abc');
      expect(back.anchorHostMs, 1700000000000);
      expect(back.startOffsetMs, 12500);
    });

    test('CMD with params round-trips', () {
      final p = MeshPacket(
        type: MeshPacketType.meshCmd,
        epoch: 1,
        seq: 7,
        command: MeshCommand.seek,
        params: {'positionMs': 99000},
      );
      final back = MeshPacket.tryDecode(p.encode());
      expect(back!.command, MeshCommand.seek);
      expect(back.params['positionMs'], 99000);
    });

    test('CLOCK_PONG carries the quadruple', () {
      final p = MeshPacket(
        type: MeshPacketType.meshClockPong,
        epoch: 2,
        seq: 99,
        t1HostTx: 100,
        t2MemberRx: 150,
        t3MemberTx: 151,
        t4HostRx: 202,
      );
      final back = MeshPacket.tryParse(p.toMap());
      expect(back!.t1HostTx, 100);
      expect(back.t2MemberRx, 150);
      expect(back.t3MemberTx, 151);
      expect(back.t4HostRx, 202);
    });

    test('non-mesh packets parse to null (Jam traffic untouched)', () {
      expect(MeshPacket.tryDecode('{"type":"sync"}'), isNull);
      expect(MeshPacket.tryDecode('{"type":"chat"}'), isNull);
      expect(MeshPacket.tryDecode('not json at all'), isNull);
      expect(MeshPacket.tryDecode('[]'), isNull);
    });

    test('STATE packet with booleans survives', () {
      final p = MeshPacket(
        type: MeshPacketType.meshState,
        epoch: 5,
        seq: 1,
        isPlaying: true,
        positionMs: 44000,
      );
      final back = MeshPacket.tryDecode(p.encode());
      expect(back!.isPlaying, isTrue);
      expect(back.positionMs, 44000);
    });
  });

  group('MeshStalenessGate', () {
    test('accepts increasing seq within one epoch', () {
      final g = MeshStalenessGate();
      expect(g.accept(epoch: 1, seq: 1), isTrue);
      expect(g.accept(epoch: 1, seq: 2), isTrue);
      expect(g.accept(epoch: 1, seq: 5), isTrue);
    });

    test('drops old seq and old epochs', () {
      final g = MeshStalenessGate();
      g.accept(epoch: 2, seq: 10);
      expect(g.accept(epoch: 2, seq: 10), isFalse); // replay
      expect(g.accept(epoch: 2, seq: 9), isFalse); // old
      expect(g.accept(epoch: 1, seq: 99), isFalse); // old epoch
    });

    test('epoch jump resets seq watermark', () {
      final g = MeshStalenessGate();
      g.accept(epoch: 1, seq: 100);
      expect(g.accept(epoch: 2, seq: 1), isTrue); // new epoch, low seq ok
      expect(g.epoch, 2);
    });

    test('reset clears watermarks', () {
      final g = MeshStalenessGate();
      g.accept(epoch: 3, seq: 10);
      g.reset();
      expect(g.accept(epoch: 3, seq: 1), isTrue);
    });
  });
}
