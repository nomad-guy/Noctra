import 'dart:async';
import '../../../services/p2p/p2p_models.dart';
import '../../../shared/models/models.dart';
import '../domain/jam_session_contract.dart';

/// Test/Mock implementation of [JamSessionContract].
/// Enables multi-client synchronization unit tests without opening raw network sockets.
class FakeJamSession implements JamSessionContract {
  @override
  bool isHost = false;

  @override
  bool isClient = false;

  @override
  bool get isConnected => isHost || isClient;

  @override
  String? roomCode;

  @override
  int connectedCount = 0;

  final StreamController<JamChatMessage> _chatController =
      StreamController<JamChatMessage>.broadcast();
  final StreamController<List<DiscoveredJamRoom>> _roomsController =
      StreamController<List<DiscoveredJamRoom>>.broadcast();

  final List<Map<String, dynamic>> sentSyncPackets = [];

  @override
  Stream<JamChatMessage> get chatStream => _chatController.stream;

  @override
  Stream<List<DiscoveredJamRoom>> get discoveredRoomsStream =>
      _roomsController.stream;

  @override
  Future<bool> startHostSession({String? customCode}) async {
    isHost = true;
    isClient = false;
    roomCode = customCode ?? 'JAM-1234';
    connectedCount = 1;
    return true;
  }

  @override
  Future<bool> joinSession(String hostIp, int port, {String? roomCode}) async {
    isHost = false;
    isClient = true;
    this.roomCode = roomCode ?? 'JAM-1234';
    connectedCount = 2;
    return true;
  }

  @override
  Future<void> leaveSession() async {
    isHost = false;
    isClient = false;
    roomCode = null;
    connectedCount = 0;
  }

  @override
  void sendChatMessage(String text) {
    _chatController.add(JamChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderName: isHost ? 'Host' : 'Client',
      text: text,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void broadcastPlaybackSync({
    required Song? currentSong,
    required Duration position,
    required bool isPlaying,
    required List<Song> queue,
  }) {
    sentSyncPackets.add(P2PPacket.createSyncPacket(
      song: currentSong,
      position: position,
      isPlaying: isPlaying,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      queue: queue,
      hostControlsOnly: false,
    ));
  }

  void dispose() {
    _chatController.close();
    _roomsController.close();
  }
}
