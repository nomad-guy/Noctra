part of 'mesh_session_controller.dart';

/// Member-side execution of host anchors and commands.
///
/// Split from the controller to keep both files under the 300-LOC
/// architecture gate. All state lives on [MeshSessionController].
extension MeshMemberExecutor on MeshSessionController {
  /// Executes a host anchor: ensure the song is loaded, then follow the
  /// [MeshAnchorPlan] (seek / schedule+spin / re-anchor request).
  void executeAnchor(MeshPacket p) {
    if (_applyingRemote) return;
    final songJson = p.params['song'];
    final anchorMs = p.anchorHostMs;
    final offsetMs = p.startOffsetMs;
    if (songJson == null || anchorMs == null || offsetMs == null) return;
    if (clock.offsetMs == null) {
      NoctraLogger.d('Mesh anchor held: no clock estimate yet');
      return;
    }
    Song song;
    try {
      song = Song.fromMap(
          (songJson is String ? jsonDecode(songJson) : songJson)
              as Map<String, dynamic>);
    } catch (e) {
      NoctraLogger.w('Mesh anchor had undecodable song', e);
      return;
    }
    final planner = MeshAnchorPlanner(offsetMs: clock.offsetMs!);
    final plan = planner.plan(
      nowLocalMs: DateTime.now().millisecondsSinceEpoch,
      anchorHostMs: anchorMs,
      startOffsetMs: offsetMs,
    );
    _applyingRemote = true;
    Future(() async {
      try {
        if (_player.currentSong?.id != song.id) {
          await _player.playSong(song, newQueue: [song]);
        }
        switch (plan.action) {
          case MeshAnchorAction.seekAndPlay:
            final target = plan.startOffsetMs + plan.lateMs;
            await _player.seek(Duration(milliseconds: target));
            break;
          case MeshAnchorAction.schedule:
          case MeshAnchorAction.busyWait:
            if (plan.delayMs > 0) {
              await Future<void>.delayed(Duration(milliseconds: plan.delayMs));
            }
            await _player.seek(Duration(milliseconds: plan.startOffsetMs));
            break;
          case MeshAnchorAction.reAnchor:
            NoctraLogger.w('Mesh re-anchor requested (too far behind)');
            break;
        }
      } catch (e) {
        NoctraLogger.w('Mesh anchor execution failed', e);
      } finally {
        _applyingRemote = false;
      }
    });
  }

  /// Executes one mirrored host command.
  void executeCommand(MeshPacket p) {
    if (_applyingRemote) return;
    _applyingRemote = true;
    Future(() async {
      try {
        switch (p.command) {
          case MeshCommand.pause:
            _player.pause();
            break;
          case MeshCommand.play:
            _player.resumeOrPlay();
            break;
          case MeshCommand.seek:
            final ms = (p.params['positionMs'] as num?)?.toInt();
            if (ms != null) await _player.seek(Duration(milliseconds: ms));
            break;
          case MeshCommand.next:
            await _player.skipNext();
            break;
          case MeshCommand.prev:
            await _player.skipPrevious();
            break;
          default:
            break;
        }
      } catch (e) {
        NoctraLogger.w('Mesh command execution failed', e);
      } finally {
        _applyingRemote = false;
      }
    });
  }
}
