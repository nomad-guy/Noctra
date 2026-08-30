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

  factory JamChatMessage.fromMap(Map<String, dynamic> map) => JamChatMessage(
    id: map['id'] ?? '',
    senderName: map['senderName'] ?? 'Peer',
    text: map['text'] ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
  );
}

class P2PPacket {
  static Map<String, dynamic> createSyncPacket({
    required Song? song,
    required Duration position,
    required bool isPlaying,
    required int timestamp,
    required List<Song> queue,
    required bool hostControlsOnly,
  }) {
    return {
      'type': 'sync',
      'song': song?.toMap(),
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'hostTimestamp': timestamp,
      'queue': queue.map((s) => s.toMap()).toList(),
      'hostControlsOnly': hostControlsOnly,
    };
  }

  static Map<String, dynamic> createChatPacket(JamChatMessage msg) {
    return {
      'type': 'chat',
      'message': msg.toMap(),
    };
  }
}
