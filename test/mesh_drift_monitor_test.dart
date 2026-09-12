import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/mesh/application/mesh_drift_monitor.dart';

void main() {
  group('MeshDriftMonitor', () {
    test('small drift is observed, not corrected', () {
      final m = MeshDriftMonitor();
      final d = m.evaluate(driftMs: 80, nowMs: 1000);
      expect(d.action, MeshDriftAction.observe);
    });

    test('drift beyond threshold corrects once', () {
      final m = MeshDriftMonitor();
      final d = m.evaluate(driftMs: 200, nowMs: 1000);
      expect(d.action, MeshDriftAction.correct);
    });

    test('cooldown suppresses correction storms', () {
      final m = MeshDriftMonitor();
      expect(m.evaluate(driftMs: 200, nowMs: 1000).action,
          MeshDriftAction.correct);
      expect(m.evaluate(driftMs: 300, nowMs: 2000).action,
          MeshDriftAction.observe); // inside 4s cooldown
      expect(m.evaluate(driftMs: 300, nowMs: 5100).action,
          MeshDriftAction.correct); // cooldown elapsed
    });

    test('sustained divergence beyond 900ms forces mesh exit', () {
      final m = MeshDriftMonitor();
      // First divergent sample corrects (cooldown starts).
      expect(m.evaluate(driftMs: 1000, nowMs: 0).action,
          MeshDriftAction.correct);
      // Samples during cooldown are observed but counted.
      expect(m.evaluate(driftMs: 1000, nowMs: 1000).action,
          MeshDriftAction.observe);
      expect(m.evaluate(driftMs: 1000, nowMs: 2000).action,
          MeshDriftAction.observe);
      // After cooldown, 3rd consecutive divergent → leave.
      expect(m.evaluate(driftMs: 1000, nowMs: 4500).action,
          MeshDriftAction.leaveMesh);
    });

    test('recovery resets divergence counter', () {
      final m = MeshDriftMonitor();
      m.evaluate(driftMs: 1000, nowMs: 0); // divergent #1 (correct)
      m.evaluate(driftMs: 1000, nowMs: 1000); // divergent #2 (observe)
      m.evaluate(driftMs: 50, nowMs: 2000); // healthy → reset
      final d = m.evaluate(driftMs: 200, nowMs: 8000); // normal correction
      expect(d.action, MeshDriftAction.correct);
      expect(d.consecutiveDivergent, 0);
    });

    test('negative drift (member ahead) also corrects', () {
      final m = MeshDriftMonitor();
      expect(m.evaluate(driftMs: -250, nowMs: 0).action,
          MeshDriftAction.correct);
    });
  });
}
