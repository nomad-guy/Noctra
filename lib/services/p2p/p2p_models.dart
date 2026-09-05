import '../../data/models/song_model.dart';

class JamChatMessage {
  final String id;
  final String senderName;
  final String text;
  final DateTime timestamp;

  JamChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

class DiscoveredJamRoom {
  final String roomCode;
  final String hostName;
  final String hostIp;
  final int port;
  final DateTime lastSeen;

  DiscoveredJamRoom({
    required this.roomCode,
    required this.hostName,
    required this.hostIp,
    required this.port,
    required this.lastSeen,
  });

  DiscoveredJamRoom copyWith({
    String? roomCode,
    String? hostName,
    String? hostIp,
    int? port,
    DateTime? lastSeen,
  }) {
    return DiscoveredJamRoom(
      roomCode: roomCode ?? this.roomCode,
      hostName: hostName ?? this.hostName,
      hostIp: hostIp ?? this.hostIp,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() => {
        'roomCode': roomCode,
        'hostName': hostName,
        'hostIp': hostIp,
        'port': port,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredJamRoom &&
          runtimeType == other.runtimeType &&
          roomCode == other.roomCode &&
          hostIp == other.hostIp &&
          port == other.port;

  @override
  int get hashCode => roomCode.hashCode ^ hostIp.hashCode ^ port.hashCode;
}

class P2PPacket {
  static Map<String, dynamic> createSyncPacket({
    required Song? song,
    required Duration position,
    required bool isPlaying,
    required int timestamp,
    required List<Song> queue,
    required bool hostControlsOnly,
    int? sequence,
    String? sessionId,
  }) {
    final map = <String, dynamic>{
      'type': 'sync',
      'song': song?.toMap(),
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'hostTimestamp': timestamp,
      'queue': queue.map((s) => s.toMap()).toList(),
      'hostControlsOnly': hostControlsOnly,
    };
    if (sequence != null) map['seq'] = sequence;
    if (sessionId != null) map['sessionId'] = sessionId;
    return map;
  }

  static Map<String, dynamic> createChatPacket(JamChatMessage msg) {
    return {
      'type': 'chat',
      'message': msg.toMap(),
    };
  }
}
