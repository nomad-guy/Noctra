import 'dart:math';

/// Speaker Mesh — pure clock-sync estimation (NTP-style round-trip).
///
/// Every member periodically exchanges timestamp quadruples with the host:
///
/// ```text
/// t1 = host_tx     (host clock when ping left)
/// t2 = member_rx   (member clock when ping arrived)
/// t3 = member_tx2  (member clock when pong left)
/// t4 = host_rx     (host clock when pong arrived back)
/// ```
///
/// offset = ((t2 - t1) - (t4 - t3)) / 2   → "member clock minus host clock"
/// rtt    = (t4 - t1) - (t3 - t2)
///
/// Positive offset means the member clock runs AHEAD of the host. A member
/// converts a host anchor [anchorHostMs] to its own wall clock via
/// `anchorHostMs - offset`. Pure class: no I/O, no timers, fully testable.
class MeshClockEstimator {
  MeshClockEstimator({
    this.sampleWindow = 20,
    this.keepBest = 5,
    this.rttOutlierMs = 250,
    this.rttJitterWarnMs = 60,
  })  : assert(sampleWindow > 0),
        assert(keepBest > 0 && keepBest <= sampleWindow);

  /// Number of recent samples considered.
  final int sampleWindow;

  /// How many of the lowest-RTT samples are averaged (min-RTT filtering:
  /// the lowest round trips are the least queue-distorted).
  final int keepBest;

  /// Samples with RTT above this are discarded as network outliers.
  final int rttOutlierMs;

  /// RTT jitter above this marks the link "unstable" (UI warning chip).
  final int rttJitterWarnMs;

  final List<_ClockSample> _samples = [];

  /// Member clock minus host clock, in ms (positive = member ahead).
  double? get offsetMs {
    final best = _bestSamples();
    if (best.isEmpty) return null;
    return best.map((s) => s.offset).reduce((a, b) => a + b) / best.length;
  }

  /// Average round-trip time of the kept samples, in ms.
  double? get rttMs {
    final best = _bestSamples();
    if (best.isEmpty) return null;
    return best.map((s) => s.rtt).reduce((a, b) => a + b) / best.length;
  }

  /// True when recent RTT jitter exceeds [rttJitterWarnMs].
  bool get isUnstable {
    final best = _bestSamples();
    if (best.length < 2) return false;
    final rtts = best.map((s) => s.rtt).toList()
      ..sort();
    final spread = rtts.last - rtts.first;
    return spread > rttJitterWarnMs;
  }

  bool get hasEstimate => _samples.isNotEmpty;

  /// Number of retained samples.
  int get sampleCount => _samples.length;

  /// Records one ping/pong exchange. Returns the RTT in ms.
  double addSample({
    required int t1HostTx,
    required int t2MemberRx,
    required int t3MemberTx,
    required int t4HostRx,
  }) {
    final rtt = (t4HostRx - t1HostTx).toDouble() - (t3MemberTx - t2MemberRx);
    final offset = ((t2MemberRx - t1HostTx) - (t4HostRx - t3MemberTx)) / 2.0;
    if (rtt < 0 || rtt > rttOutlierMs) {
      return rtt.clamp(0, double.infinity).toDouble(); // outlier: not stored
    }
    _samples.add(_ClockSample(offset, rtt));
    while (_samples.length > sampleWindow) {
      _samples.removeAt(0);
    }
    return rtt;
  }

  /// Clears all samples (session reset / host change).
  void reset() => _samples.clear();

  List<_ClockSample> _bestSamples() {
    final sorted = List<_ClockSample>.from(_samples)
      ..sort((a, b) => a.rtt.compareTo(b.rtt));
    return sorted.take(min(keepBest, sorted.length)).toList();
  }
}

class _ClockSample {
  final double offset;
  final double rtt;
  const _ClockSample(this.offset, this.rtt);
}

/// Converts between host-anchored times and local execution times.
///
/// Pure math, split out so the execution path (SM-3) can be tested without
/// any transport.
class MeshAnchorPlanner {
  MeshAnchorPlanner({
    required this.offsetMs,
    this.maxScheduleAheadMs = 1500,
    this.maxLateMs = 2000,
  });

  /// Clock offset from [MeshClockEstimator] (member minus host, ms;
  /// positive = member ahead).
  final double offsetMs;

  /// Delays longer than this use a timer; shorter ones busy-wait the tail
  /// for sub-tick precision.
  final int maxScheduleAheadMs;

  /// Being later than this requires a re-anchor instead of a seek.
  final int maxLateMs;

  /// Computes how the member should execute an anchor for a track.
  ///
  /// [nowLocalMs]     — member wall clock (ms)
  /// [anchorHostMs]   — host wall clock when playback should be at [startOffsetMs]
  /// [startOffsetMs]  — position in the track the anchor refers to
  /// [loadLeadMs]     — estimated time to load/prepare the source; loading
  ///                    should START this long before the target moment
  ///
  /// [MeshAnchorPlan.delayMs] is the total scheduled waiting time before the
  /// play attempt; the execution layer decides whether to spend it as a
  /// timer + load + spin tail (schedule) or load-first-then-spin (busyWait).
  MeshAnchorPlan plan({
    required int nowLocalMs,
    required int anchorHostMs,
    required int startOffsetMs,
    int loadLeadMs = 300,
  }) {
    // offset = member − host → a host moment H happens locally at H − offset.
    final targetLocal = anchorHostMs - offsetMs.round();
    final loadStartLocal = targetLocal - loadLeadMs;
    final loadDelay = loadStartLocal - nowLocalMs;
    final playDelay = targetLocal - nowLocalMs;

    // Plenty of time: idle first, then load, then spin the tail.
    if (loadDelay > maxScheduleAheadMs) {
      return MeshAnchorPlan.schedule(
          delayMs: loadDelay, startOffsetMs: startOffsetMs);
    }
    // Target still ahead (even if the load window already opened): load now,
    // spin until the play moment.
    if (playDelay > 0) {
      return MeshAnchorPlan.busyWait(
          delayMs: playDelay, startOffsetMs: startOffsetMs);
    }
    // Past the target: catch up by seeking forward, or re-anchor when hopeless.
    final lateMs = -playDelay;
    if (lateMs <= maxLateMs) {
      return MeshAnchorPlan.seekAndPlay(
          lateMs: lateMs, startOffsetMs: startOffsetMs);
    }
    return MeshAnchorPlan.reAnchor(lateMs: lateMs);
  }
}

/// What a member should do to join/sync a host anchor.
class MeshAnchorPlan {
  const MeshAnchorPlan.schedule(
      {required this.delayMs, required this.startOffsetMs})
      : action = MeshAnchorAction.schedule,
        lateMs = 0;

  const MeshAnchorPlan.busyWait(
      {required this.delayMs, required this.startOffsetMs})
      : action = MeshAnchorAction.busyWait,
        lateMs = 0;

  const MeshAnchorPlan.seekAndPlay(
      {required this.lateMs, required this.startOffsetMs})
      : action = MeshAnchorAction.seekAndPlay,
        delayMs = 0;

  const MeshAnchorPlan.reAnchor({required this.lateMs})
      : action = MeshAnchorAction.reAnchor,
        delayMs = 0,
        startOffsetMs = 0;

  final MeshAnchorAction action;

  /// Timer delay before play (schedule/busyWait).
  final int delayMs;

  /// How far behind the anchor we are (seekAndPlay/reAnchor).
  final int lateMs;

  /// Track position the anchor refers to.
  final int startOffsetMs;
}

enum MeshAnchorAction { schedule, busyWait, seekAndPlay, reAnchor }
