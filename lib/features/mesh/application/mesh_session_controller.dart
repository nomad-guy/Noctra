import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/noctra_logger.dart';
import '../../../data/models/song_model.dart';
import '../../../services/audio/audio_player_service.dart';
import '../domain/mesh_clock.dart';
import '../domain/mesh_latency_profile.dart';
import '../domain/mesh_packets.dart';
import '../infrastructure/mesh_crypto.dart';
import '../infrastructure/mesh_transport.dart';
import '../infrastructure/mesh_transport_events.dart';

part 'mesh_member_executor.dart';
part 'mesh_host_anchor.dart';

/// Roles of the mesh session (mirrors transport roles plus idle).
enum MeshSessionState { idle, hosting, member }

/// Orchestrates a Speaker Mesh session.
///
/// HOST owns playback: every play/pause/seek/skip re-anchors all members
/// (anchor = "at host-time T, position P, playing Q"). Members mirror the
/// anchor through [MeshAnchorPlanner] and correct drift via
/// [MeshDriftMonitor].
///
/// Clock probes are host-initiated: host sends PING{t1}, member replies
/// PONG{t1,t2,t3}, host stamps t4 and echoes the full quadruple back so the
/// member's own [MeshClockEstimator] stays authoritative for anchors.
class MeshSessionController extends ChangeNotifier
    implements MeshTransportListener {
  MeshSessionController({AudioPlayerService? player})
      : _player = player ?? AudioPlayerService.instance {
    _transport.bindListener(this);
  }

  final AudioPlayerService _player;
  final MeshTransport _transport = MeshTransport();
  final MeshClockEstimator clock = MeshClockEstimator();
  final MeshStalenessGate _gate = MeshStalenessGate();

  MeshSessionState state = MeshSessionState.idle;
  String roomCode = '';
  String roomSecret = '';
  int epoch = 0;
  int _seq = 0;
  int _probeCounter = 0;
  final Map<String, int> _openProbes = {};
  Timer? _probeTimer;
  Timer? _reanchorTimer;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _songSub;
  Timer? _anchorDebounce;
  bool _applyingRemote = false;

  bool get isHosting => state == MeshSessionState.hosting;
  bool get isMember => state == MeshSessionState.member;
  int get memberCount => _transport.memberCount;
  List<String> get memberIds => _transport.memberIds;
  int? get clockOffsetMs =>
      clock.offsetMs?.round();
  int? get rttMs => clock.rttMs?.round();
  bool get clockUnstable => clock.isUnstable;
  int get outputLatencyMs => MeshLatencyProfile.instance.totalLatencyMs;

  // ─── Host lifecycle ────────────────────────────────────────────────────

  Future<bool> startMesh() async {
    if (state != MeshSessionState.idle) return false;
    epoch++;
    roomSecret = MeshCrypto.generateRoomSecret();
    roomCode = 'MESH-${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
    final port = await _transport.startHost(roomSecret: roomSecret, epoch: epoch);
    if (port == null) {
      roomSecret = '';
      return false;
    }
    state = MeshSessionState.hosting;
    _gate.reset();
    clock.reset();
    _attachPlayerListeners();
    _startProbeTimer();
    NoctraLogger.i('Mesh hosting as $roomCode on port $port');
    notifyListeners();
    return true;
  }

  /// The secret a member must enter (host side only).
  String get shareSecret => isHosting ? roomSecret : '';

  // ─── Member lifecycle ──────────────────────────────────────────────────

  Future<bool> joinMesh(String hostIp, String secret, {int port = 8155}) async {
    if (state != MeshSessionState.idle) return false;
    if (secret.trim().isEmpty) return false;
    _transport.port = port;
    epoch++;
    final ok = await _transport.joinHost(hostIp,
        roomSecret: secret, epoch: epoch);
    if (!ok) {
      roomSecret = '';
      return false;
    }
    roomSecret = secret.trim();
    state = MeshSessionState.member;
    _gate.reset();
    clock.reset();
    NoctraLogger.i('Mesh joined host $hostIp:$port');
    notifyListeners();
    return true;
  }

  Future<void> leaveMesh() async {
    if (isHosting) {
      _transport.broadcast(MeshPacket(
          type: MeshPacketType.meshBye,
          epoch: epoch,
          seq: ++_seq,
          reason: 'hostLeft'));
    }
    state = MeshSessionState.idle;
    _detachPlayerListeners();
    _probeTimer?.cancel();
    _reanchorTimer?.cancel();
    _openProbes.clear();
    clock.reset();
    _gate.reset();
    await _transport.shutdown();
    roomSecret = '';
    NoctraLogger.i('Mesh session closed');
    notifyListeners();
  }

  // ─── Inbound events (host + member) ────────────────────────────────────

  @override
  void onEvent(MeshTransportEvent event) {
    final reason = event.reason;
    if (reason != null) {
      _onTransportState(reason);
      return;
    }
    final packet = event.packet;
    if (packet == null) return;
    if (isHosting) {
      _onHostPacket(packet, event.memberId);
    } else if (isMember) {
      _onMemberPacket(packet);
    }
  }

  void _onTransportState(String reason) {
    switch (reason) {
      case 'memberJoined':
      case 'memberLeft':
        if (isHosting) {
          _broadcastAnchor(); // bring the newcomer up to date
        }
        break;
      case 'hostLost':
        if (isMember) {
          NoctraLogger.w('Mesh host lost — leaving session');
          state = MeshSessionState.idle;
          clock.reset();
          _transport.shutdown();
          roomSecret = '';
          notifyListeners();
        }
        break;
    }
  }

  void _onHostPacket(MeshPacket p, String? memberId) {
    switch (p.type) {
      case MeshPacketType.meshClockPing:
        // Member→host probes are not used; ignore.
        break;
      case MeshPacketType.meshClockPong:
        final t2 = p.t2MemberRx;
        final t3 = p.t3MemberTx;
        final t1 = p.t1HostTx;
        if (t2 != null && t3 != null && t1 != null && memberId != null) {
          final t4 = DateTime.now().millisecondsSinceEpoch;
          // Echo the full quadruple so the member computes the same offset.
          _transport.sendToMember(
              memberId,
              MeshPacket(
                type: MeshPacketType.meshClockPong,
                epoch: epoch,
                seq: ++_seq,
                t1HostTx: t1,
                t2MemberRx: t2,
                t3MemberTx: t3,
                t4HostRx: t4,
              ));
        }
        break;
      default:
        break;
    }
  }

  void _onMemberPacket(MeshPacket p) {
    if (!_gate.accept(epoch: p.epoch, seq: p.seq)) return;
    switch (p.type) {
      case MeshPacketType.meshClockPong:
        if (p.t1HostTx != null &&
            p.t2MemberRx != null &&
            p.t3MemberTx != null &&
            p.t4HostRx != null) {
          clock.addSample(
            t1HostTx: p.t1HostTx!,
            t2MemberRx: p.t2MemberRx!,
            t3MemberTx: p.t3MemberTx!,
            t4HostRx: p.t4HostRx!,
          );
          notifyListeners();
        }
        break;
      case MeshPacketType.meshAnchor:
        executeAnchor(p);
        break;
      case MeshPacketType.meshCmd:
        executeCommand(p);
        break;
      case MeshPacketType.meshBye:
        NoctraLogger.i('Mesh host dissolved the session (${p.reason})');
        state = MeshSessionState.idle;
        clock.reset();
        roomSecret = '';
        notifyListeners();
        break;
      default:
        break;
    }
  }


  // ─── Host-side passthroughs (UI buttons) ───────────────────────────────

  /// Host UI actions re-anchor automatically via player listeners; these
  /// helpers exist for explicit immediate re-anchoring after programmatic
  /// changes.
  void anchorNow() {
    if (isHosting) _broadcastAnchor();
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _anchorDebounce?.cancel();
    _reanchorTimer?.cancel();
    _playerStateSub?.cancel();
    _songSub?.cancel();
    _transport.shutdown();
    super.dispose();
  }
}
