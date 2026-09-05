import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/jam/infrastructure/fake_jam_session.dart';
import 'package:noctra/shared/models/models.dart';

void main() {
  group('Jam Subsystem Contract Tests', () {
    late FakeJamSession hostSession;
    late FakeJamSession clientSession;

    setUp(() {
      hostSession = FakeJamSession();
      clientSession = FakeJamSession();
    });

    tearDown(() {
      hostSession.dispose();
      clientSession.dispose();
    });

    test('host can initiate session and broadcast sync packet', () async {
      final started = await hostSession.startHostSession(customCode: 'NOCTRA-88');
      expect(started, isTrue);
      expect(hostSession.isHost, isTrue);
      expect(hostSession.roomCode, equals('NOCTRA-88'));

      final testSong = Song(
        id: 'sync_1',
        title: 'Cyber Drift',
        artist: 'Waveform',
        duration: const Duration(seconds: 180),
      );

      hostSession.broadcastPlaybackSync(
        currentSong: testSong,
        position: const Duration(seconds: 45),
        isPlaying: true,
        queue: [testSong],
      );

      expect(hostSession.sentSyncPackets, hasLength(1));
      final packet = hostSession.sentSyncPackets.first;
      expect(packet['type'], equals('sync'));
      expect(packet['positionMs'], equals(45000));
      expect(packet['isPlaying'], isTrue);
      expect(packet['song']['title'], equals('Cyber Drift'));
    });

    test('client joins room and exchanges chat messages', () async {
      await clientSession.joinSession('192.168.1.50', 8080, roomCode: 'NOCTRA-88');
      expect(clientSession.isClient, isTrue);
      expect(clientSession.isConnected, isTrue);

      final messageFuture = clientSession.chatStream.first;
      clientSession.sendChatMessage('Hello SyncCast!');

      final received = await messageFuture;
      expect(received.text, equals('Hello SyncCast!'));
      expect(received.senderName, equals('Client'));
    });

    test('leaving session resets session state cleanly', () async {
      await hostSession.startHostSession();
      expect(hostSession.isConnected, isTrue);

      await hostSession.leaveSession();
      expect(hostSession.isConnected, isFalse);
      expect(hostSession.roomCode, isNull);
      expect(hostSession.connectedCount, equals(0));
    });
  });
}
