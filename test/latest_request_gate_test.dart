import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/utils/latest_request_gate.dart';

void main() {
  test('only the latest asynchronous interaction remains authoritative', () {
    final gate = LatestRequestGate();
    final first = gate.begin();
    final second = gate.begin();

    expect(gate.isCurrent(first), isFalse);
    expect(gate.isCurrent(second), isTrue);
  });

  test('invalidation rejects a completion after widget disposal', () {
    final gate = LatestRequestGate();
    final request = gate.begin();
    gate.invalidate();

    expect(gate.isCurrent(request), isFalse);
  });
}
