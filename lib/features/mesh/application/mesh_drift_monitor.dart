/// Speaker Mesh — drift monitoring and correction policy.
///
/// A member compares its actual playback position against the position the
/// host anchor predicts. Corrections are deliberately conservative:
///  - only when |drift| exceeds [correctionThresholdMs] (default 120 ms —
///    empirically the boundary where distributed speakers start to sound
///    like an echo)
///  - at most one correction per [cooldown] window, so a noisy link cannot
///    produce seek-storms
/// Pure class: no timers; the session controller feeds it samples.
class MeshDriftMonitor {
  MeshDriftMonitor({
    this.correctionThresholdMs = 120,
    this.cooldownMs = 4000,
    this.echoDivergenceMs = 900,
  });

  /// |drift| beyond this triggers an inaudible micro-seek.
  final int correctionThresholdMs;

  /// Minimum spacing between corrections.
  final int cooldownMs;

  /// |drift| beyond this for multiple consecutive samples means the device
  /// cannot hold sync (or is wrong-track) and should leave the mesh.
  final int echoDivergenceMs;

  int? _lastCorrectionAtMs;
  int _consecutiveDivergent = 0;

  /// Result of feeding one drift sample.
  MeshDriftDecision evaluate({
    required int driftMs,
    required int nowMs,
  }) {
    final abs = driftMs.abs();

    if (abs > echoDivergenceMs) {
      _consecutiveDivergent++;
    } else {
      _consecutiveDivergent = 0;
    }

    final last = _lastCorrectionAtMs;
    if (last != null && nowMs - last < cooldownMs) {
      return MeshDriftDecision(
        action: MeshDriftAction.observe,
        driftMs: driftMs,
        consecutiveDivergent: _consecutiveDivergent,
      );
    }

    if (abs <= correctionThresholdMs) {
      return MeshDriftDecision(
        action: MeshDriftAction.observe,
        driftMs: driftMs,
        consecutiveDivergent: _consecutiveDivergent,
      );
    }

    _lastCorrectionAtMs = nowMs;
    return MeshDriftDecision(
      action: abs > echoDivergenceMs && _consecutiveDivergent >= 3
          ? MeshDriftAction.leaveMesh
          : MeshDriftAction.correct,
      driftMs: driftMs,
      consecutiveDivergent: _consecutiveDivergent,
    );
  }

  /// Called after a correction was applied so the monitor doesn't double-fire.
  void resetWindow() {
    _lastCorrectionAtMs = null;
    _consecutiveDivergent = 0;
  }
}

enum MeshDriftAction { observe, correct, leaveMesh }

class MeshDriftDecision {
  const MeshDriftDecision({
    required this.action,
    required this.driftMs,
    required this.consecutiveDivergent,
  });

  final MeshDriftAction action;
  final int driftMs;
  final int consecutiveDivergent;

  @override
  String toString() =>
      'MeshDriftDecision(${action.name}, drift=$driftMs ms, div=$consecutiveDivergent)';
}
