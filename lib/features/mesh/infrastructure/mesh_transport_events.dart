import '../domain/mesh_packets.dart';

/// Speaker Mesh transport roles.
enum MeshTransportRole { host, member }

/// Transport events delivered to the session layer.
class MeshTransportEvent {
  const MeshTransportEvent.custom(this.reason)
      : packet = null,
        memberId = null,
        raw = null;

  const MeshTransportEvent.memberJoined(String id)
      : reason = 'memberJoined',
        packet = null,
        memberId = id,
        raw = null;

  const MeshTransportEvent.memberLeft(String id)
      : reason = 'memberLeft',
        packet = null,
        memberId = id,
        raw = null;

  const MeshTransportEvent.packetIn(MeshPacket p, String? senderId)
      : reason = null,
        packet = p,
        memberId = senderId,
        raw = null;

  final String? reason;
  final MeshPacket? packet;
  final String? memberId;
  final String? raw;
}

/// Callbacks the session layer registers on the transport.
abstract class MeshTransportListener {
  void onEvent(MeshTransportEvent event);
}
