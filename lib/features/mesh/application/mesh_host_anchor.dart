part of 'mesh_session_controller.dart';

/// Host-side anchoring: player listeners, debounced anchor broadcasts,
/// periodic re-anchors, and clock-probe exchange.
///
/// Split from the controller to keep both files under the 300-LOC
/// architecture gate. All state lives on [MeshSessionController].
extension MeshHostAnchor on MeshSessionController {
  void _attachPlayerListeners() {
    _detachPlayerListeners();
    _playerStateSub = _player.player.playerStateStream.listen((_) {
      if (isHosting && !_applyingRemote) _scheduleAnchor();
    });
    _songSub = _player.currentSongStream.listen((_) {
      if (isHosting && !_applyingRemote) _scheduleAnchor();
    });
    _reanchorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isHosting &&
          memberCount > 0 &&
          (_player.player.playing || _player.currentSong != null)) {
        _broadcastAnchor();
      }
    });
  }

  void _detachPlayerListeners() {
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _songSub?.cancel();
    _songSub = null;
    _reanchorTimer?.cancel();
    _reanchorTimer = null;
  }

  void _scheduleAnchor() {
    _anchorDebounce?.cancel();
    _anchorDebounce = Timer(const Duration(milliseconds: 80), () {
      if (isHosting && memberCount > 0) _broadcastAnchor();
    });
  }

  /// Host entry point: broadcast current playback as an anchor.
  ///
  /// The anchor timestamp is host-now + rtt/2: the moment the member
  /// receives it, it should be at [startOffsetMs].
  void _broadcastAnchor() {
    final song = _player.currentSong;
    final playing = _player.player.playing;
    final positionMs = _player.player.position.inMilliseconds;
    final anchorHostMs =
        DateTime.now().millisecondsSinceEpoch + (rttMs ?? 0) ~/ 2;
    _transport.broadcast(MeshPacket(
      type: playing ? MeshPacketType.meshAnchor : MeshPacketType.meshCmd,
      epoch: epoch,
      seq: ++_seq,
      senderId: 'host',
      songId: song?.id,
      anchorHostMs: anchorHostMs,
      startOffsetMs: positionMs,
      command: playing ? null : MeshCommand.pause,
      params:
          song != null ? {'song': jsonEncode(song.toMap())} : const {},
    ));
  }

  void _startProbeTimer() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!isHosting || memberCount == 0) return;
      for (final id in memberIds) {
        final probeId = 'p${++_probeCounter}';
        _openProbes[probeId] = DateTime.now().millisecondsSinceEpoch;
        _transport.sendToMember(
            id,
            MeshPacket(
              type: MeshPacketType.meshClockPing,
              epoch: epoch,
              seq: ++_seq,
              senderId: probeId,
              t1HostTx: _openProbes[probeId],
            ));
      }
    });
  }
}
