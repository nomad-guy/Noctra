import 'dart:async';
import '../../../services/p2p/p2p_models.dart';
import '../../../shared/models/models.dart';

/// Pure domain contract for local Jam / SyncCast real-time collaborative playback.
abstract class JamSessionContract {
  bool get isHost;
  bool get isClient;
  bool get isConnected;
  String? get roomCode;
  int get connectedCount;

  Stream<JamChatMessage> get chatStream;
  Stream<List<DiscoveredJamRoom>> get discoveredRoomsStream;

  Future<bool> startHostSession({String? customCode});

  Future<bool> joinSession(String hostIp, int port, {String? roomCode});

  Future<void> leaveSession();

  void sendChatMessage(String text);

  void broadcastPlaybackSync({
    required Song? currentSong,
    required Duration position,
    required bool isPlaying,
    required List<Song> queue,
  });
}
