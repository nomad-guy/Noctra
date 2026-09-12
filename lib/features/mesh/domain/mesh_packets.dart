import 'dart:convert';

/// Speaker Mesh wire vocabulary. All packets travel as JSON over the Jam
/// TCP transport and reuse its caps (payload ≤64 KB, depth ≤64) and
/// sequence/epoch staleness checks.
///
/// ```text
/// MESH_HELLO / MESH_WELCOME      join handshake (auth challenge rides on Jam)
/// MESH_CLOCK_PING / MESH_CLOCK_PONG
/// MESH_ANCHOR   {songId, anchorHostMs, startOffsetMs, epoch, seq}
/// MESH_CMD      {action, params, epoch, seq}
/// MESH_STATE    {isPlaying, positionMs, epoch, seq}   periodic (2 s)
/// MESH_KICK     {reason}
/// MESH_BYE      {reason}
/// ```
enum MeshPacketType {
  meshHello('MESH_HELLO'),
  meshWelcome('MESH_WELCOME'),
  meshClockPing('MESH_CLOCK_PING'),
  meshClockPong('MESH_CLOCK_PONG'),
  meshAnchor('MESH_ANCHOR'),
  meshCmd('MESH_CMD'),
  meshState('MESH_STATE'),
  meshKick('MESH_KICK'),
  meshBye('MESH_BYE');

  const MeshPacketType(this.wire);
  final String wire;

  static MeshPacketType? fromWire(String? w) {
    for (final t in MeshPacketType.values) {
      if (t.wire == w) return t;
    }
    return null;
  }
}

/// Host playback commands a member mirrors.
enum MeshCommand { play, pause, seek, next, prev, setVolume }

class MeshPacket {
  const MeshPacket({
    required this.type,
    required this.epoch,
    required this.seq,
    this.senderId,
    this.songId,
    this.anchorHostMs,
    this.startOffsetMs,
    this.command,
    this.params = const {},
    this.isPlaying,
    this.positionMs,
    this.t1HostTx,
    this.t2MemberRx,
    this.t3MemberTx,
    this.t4HostRx,
    this.reason,
  });

  final MeshPacketType type;
  final int epoch;
  final int seq;
  final String? senderId;

  // ANCHOR
  final String? songId;
  final int? anchorHostMs;
  final int? startOffsetMs;

  // CMD
  final MeshCommand? command;
  final Map<String, dynamic> params;

  // STATE
  final bool? isPlaying;
  final int? positionMs;

  // CLOCK
  final int? t1HostTx;
  final int? t2MemberRx;
  final int? t3MemberTx;
  final int? t4HostRx;

  // KICK/BYE
  final String? reason;

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'type': type.wire,
      'epoch': epoch,
      'seq': seq,
    };
    void put(String k, Object? v) {
      if (v != null) m[k] = v;
    }

    put('senderId', senderId);
    put('songId', songId);
    put('anchorHostMs', anchorHostMs);
    put('startOffsetMs', startOffsetMs);
    if (command != null) m['command'] = command!.name;
    if (params.isNotEmpty) m['params'] = params;
    put('isPlaying', isPlaying);
    put('positionMs', positionMs);
    put('t1', t1HostTx);
    put('t2', t2MemberRx);
    put('t3', t3MemberTx);
    put('t4', t4HostRx);
    put('reason', reason);
    return m;
  }

  String encode() => jsonEncode(toMap());

  /// Parses a wire map into a [MeshPacket]. Returns null for non-mesh
  /// packets (Jam sync/chat payloads) or malformed input — callers must
  /// treat null as "not mine" and pass it along to Jam handling.
  static MeshPacket? tryParse(Map<String, dynamic> map) {
    try {
      final type = MeshPacketType.fromWire(map['type']?.toString());
      if (type == null) return null;
      final epoch = (map['epoch'] as num?)?.toInt() ?? -1;
      final seq = (map['seq'] as num?)?.toInt() ?? -1;
      MeshCommand? cmd;
      final rawCmd = map['command']?.toString();
      if (rawCmd != null) {
        for (final c in MeshCommand.values) {
          if (c.name == rawCmd) cmd = c;
        }
      }
      final paramsRaw = map['params'];
      return MeshPacket(
        type: type,
        epoch: epoch,
        seq: seq,
        senderId: map['senderId']?.toString(),
        songId: map['songId']?.toString(),
        anchorHostMs: (map['anchorHostMs'] as num?)?.toInt(),
        startOffsetMs: (map['startOffsetMs'] as num?)?.toInt(),
        command: cmd,
        params: paramsRaw is Map<String, dynamic>
            ? paramsRaw
            : const {},
        isPlaying: map['isPlaying'] is bool ? map['isPlaying'] as bool : null,
        positionMs: (map['positionMs'] as num?)?.toInt(),
        t1HostTx: (map['t1'] as num?)?.toInt(),
        t2MemberRx: (map['t2'] as num?)?.toInt(),
        t3MemberTx: (map['t3'] as num?)?.toInt(),
        t4HostRx: (map['t4'] as num?)?.toInt(),
        reason: map['reason']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Convenience: parse from a raw JSON string.
  static MeshPacket? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return tryParse(decoded);
    } catch (_) {
      return null;
    }
  }
}

/// Staleness gate shared by host and member: packets from an older epoch or
/// an already-seen sequence number are dropped. Pure function so both sides
/// and tests share one definition of "fresh".
class MeshStalenessGate {
  int _lastSeq = -1;
  int _epoch = -1;

  int get epoch => _epoch;

  /// Returns true when (epoch, seq) is fresh; updates internal watermarks.
  bool accept({required int epoch, required int seq}) {
    if (epoch < _epoch) return false;
    if (epoch > _epoch) {
      _epoch = epoch;
      _lastSeq = seq;
      return true;
    }
    if (seq <= _lastSeq) return false;
    _lastSeq = seq;
    return true;
  }

  void reset() {
    _lastSeq = -1;
    _epoch = -1;
  }
}
