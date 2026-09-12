import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/mesh/domain/mesh_clock.dart';
import 'package:noctra/features/mesh/domain/mesh_latency_profile.dart';

void main() {
  group('MeshClockEstimator', () {
    late MeshClockEstimator clock;

    setUp(() => clock = MeshClockEstimator());

    test('computes exact offset/rtt for a clean sample', () {
      clock.addSample(t1HostTx: 1000, t2MemberRx: 1100, t3MemberTx: 1102, t4HostRx: 1104);
      // rtt = (1104-1000) - (1102-1100) = 104 - 2 = 102
      // offset = ((1100-1000) - (1104-1102))/2 = (100 - 2)/2 = 49
      expect(clock.rttMs, moreOrLessEquals(102, epsilon: 0.001));
      expect(clock.offsetMs, moreOrLessEquals(49, epsilon: 0.001));
    });

    test('symmetric link yields offset 0', () {
      clock.addSample(t1HostTx: 5000, t2MemberRx: 5000, t3MemberTx: 5000, t4HostRx: 5000);
      expect(clock.offsetMs, moreOrLessEquals(0, epsilon: 0.001));
      expect(clock.rttMs, moreOrLessEquals(0, epsilon: 0.001));
    });

    test('rejects negative and >250ms RTT outliers', () {
      clock.addSample(t1HostTx: 1000, t2MemberRx: 900, t3MemberTx: 900, t4HostRx: 800); // negative rtt
      expect(clock.hasEstimate, isFalse);

      clock.addSample(t1HostTx: 1000, t2MemberRx: 1500, t3MemberTx: 1502, t4HostRx: 1800); // ~800ms rtt
      expect(clock.hasEstimate, isFalse);
    });

    test('min-RTT filtering prefers clean samples over queued ones', () {
      // Quadruple construction for exact (offset o, rtt r, processing 1):
      //   a = t2-t1 = r/2 + o ; b = t4-t3 = r/2 - o ; t4 = t1 + r + 1
      // Clean: offset 100, rtt 220 (|o| <= r/2 holds).
      for (int i = 0; i < 15; i++) {
        final t1 = 1000 + i * 500;
        clock.addSample(
            t1HostTx: t1,
            t2MemberRx: t1 + 210,
            t3MemberTx: t1 + 211,
            t4HostRx: t1 + 221);
      }
      // Queued/asymmetric: offset 900, rtt 248 (b negative — valid math).
      for (int i = 0; i < 5; i++) {
        final t1 = 9000 + i * 500;
        clock.addSample(
            t1HostTx: t1,
            t2MemberRx: t1 + 1024,
            t3MemberTx: t1 + 1025,
            t4HostRx: t1 + 249);
      }
      // Best-5-by-RTT are all clean samples.
      expect(clock.offsetMs!, closeTo(100, 1));
      expect(clock.rttMs!, closeTo(220, 1));
    });

    test('isUnstable flags jittery links', () {
      clock.addSample(t1HostTx: 1000, t2MemberRx: 1006, t3MemberTx: 1007, t4HostRx: 1012); // rtt 11
      expect(clock.isUnstable, isFalse);
      clock.addSample(t1HostTx: 2000, t2MemberRx: 2006, t3MemberTx: 2007, t4HostRx: 2012); // rtt 11
      expect(clock.isUnstable, isFalse);
      clock.addSample(t1HostTx: 3000, t2MemberRx: 3040, t3MemberTx: 3041, t4HostRx: 3082); // rtt 81
      expect(clock.isUnstable, isTrue); // spread 70 > 60
    });

    test('window caps and reset work', () {
      // Exact quadruples: offset 10, rtt 20 → t2 = T+20, t3 = T+21, t4 = T+21.
      for (int i = 0; i < 30; i++) {
        final t1 = 1000 + i * 100;
        clock.addSample(
            t1HostTx: t1,
            t2MemberRx: t1 + 20,
            t3MemberTx: t1 + 21,
            t4HostRx: t1 + 21);
      }
      expect(clock.sampleCount, 20); // default window
      expect(clock.offsetMs!, closeTo(10, 0.001));
      clock.reset();
      expect(clock.sampleCount, 0);
      expect(clock.hasEstimate, isFalse);
    });
  });

  group('MeshAnchorPlanner', () {
    test('far-future anchor → schedule with timer', () {
      final p = MeshAnchorPlanner(offsetMs: 0)
          .plan(nowLocalMs: 1000, anchorHostMs: 5000, startOffsetMs: 0);
      expect(p.action, MeshAnchorAction.schedule);
      // load starts at target − 300 = 4700; delay = 4700 − 1000 = 3700
      expect(p.delayMs, 3700);
    });

    test('near-future anchor → busy-wait tail', () {
      final p = MeshAnchorPlanner(offsetMs: 0)
          .plan(nowLocalMs: 4700, anchorHostMs: 5000, startOffsetMs: 0);
      expect(p.action, MeshAnchorAction.busyWait);
      expect(p.delayMs, 300); // spins until the play moment at 5000
    });

    test('slightly late → seek and play', () {
      final p = MeshAnchorPlanner(offsetMs: 0)
          .plan(nowLocalMs: 5100, anchorHostMs: 5000, startOffsetMs: 0);
      expect(p.action, MeshAnchorAction.seekAndPlay);
      expect(p.lateMs, 100);
    });

    test('very late → re-anchor', () {
      final p = MeshAnchorPlanner(offsetMs: 0)
          .plan(nowLocalMs: 8000, anchorHostMs: 5000, startOffsetMs: 0);
      expect(p.action, MeshAnchorAction.reAnchor);
    });

    test('clock offset shifts the target correctly', () {
      // offset = member − host = +200 → member is ahead; host t=5000 happens
      // at local 4800. Now=4700 → busy-wait 100ms until the play moment.
      final p = MeshAnchorPlanner(offsetMs: 200)
          .plan(nowLocalMs: 4700, anchorHostMs: 5000, startOffsetMs: 0);
      expect(p.action, MeshAnchorAction.busyWait);
      expect(p.delayMs, 100);
    });

    test('late join mid-track seeks to offset + lateness', () {
      final p = MeshAnchorPlanner(offsetMs: 0).plan(
          nowLocalMs: 5250, anchorHostMs: 5000, startOffsetMs: 30000);
      expect(p.action, MeshAnchorAction.seekAndPlay);
      expect(p.lateMs, 250);
      // Execution layer seeks to 30000 + 250 = 30250ms.
    });
  });

  group('MeshLatencyProfile', () {
    test('route table has sane latencies', () {
      expect(MeshOutputRoute.phoneSpeaker.latencyMs, 40);
      expect(MeshOutputRoute.bluetoothSbc.latencyMs, greaterThan(MeshOutputRoute.bluetoothAac.latencyMs));
      expect(MeshOutputRoute.wired.latencyMs, lessThan(MeshOutputRoute.phoneSpeaker.latencyMs));
    });

    test('trim clamps to ±500 and total never goes negative', () {
      final profile = MeshLatencyProfile.instance;
      profile.routeKey = MeshOutputRoute.phoneSpeaker.key;
      profile.setTrim(5000);
      expect(profile.trimMs, MeshLatencyProfile.trimMaxMs);
      expect(profile.totalLatencyMs, 40 + MeshLatencyProfile.trimMaxMs);
      profile.setTrim(-9999);
      expect(profile.trimMs, MeshLatencyProfile.trimMinMs);
      // 40 + (-500) clamps to 0 total
      expect(profile.totalLatencyMs, 0);
      profile.setTrim(0);
    });
  });
}
