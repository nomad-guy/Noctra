part of '../p2p_sync_service.dart';

extension P2PSyncBroadcast on P2PSyncService {
  void broadcastSync() {
    if (!isHost) return;
    _syncSequence++;
    final current = _audioPlayer?.currentSong;
    final sanitizedCurrent =
        current != null ? _sanitizeSongForWire(current) : null;
    final packet = jsonEncode(P2PPacket.createSyncPacket(
      song: sanitizedCurrent,
      position: _audioPlayer?.player.position ?? Duration.zero,
      isPlaying: _audioPlayer?.player.playing ?? false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      queue: _collaborativeQueue
          .take(P2PSyncService.maxQueueLength)
          .map(_sanitizeSongForWire)
          .toList(),
      hostControlsOnly: _hostControlsOnly,
      sequence: _syncSequence,
      sessionId: activeSessionId,
    ));
    _broadcastToPeers(packet);
  }

  void _broadcastToPeers(String message) {
    final dead = <dynamic>[];
    final peersSnapshot = List<dynamic>.from(_connectedPeers);
    for (final peer in peersSnapshot) {
      try {
        peer.add(message);
      } catch (e) {
        dead.add(peer);
      }
    }
    if (dead.isNotEmpty) {
      for (final peer in dead) {
        _unregisterPeer(peer);
      }
    }
  }

  void _scheduleDebouncedSync() {
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = Timer(const Duration(milliseconds: 60), () {
      if (isHost) broadcastSync();
    });
  }
}
