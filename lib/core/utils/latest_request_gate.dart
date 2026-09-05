/// Monotonically identifies the latest asynchronous UI request.
///
/// Call [begin] before starting work and check [isCurrent] after every await
/// that could otherwise apply stale data over a newer user intent.
class LatestRequestGate {
  int _generation = 0;

  int begin() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  void invalidate() => _generation++;
}
