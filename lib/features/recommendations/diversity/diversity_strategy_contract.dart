import '../domain/recommendation_repository_contract.dart';

/// Abstract contract for applying diversity (MMR, novelty, anti-repetition)
/// to pre-ranked recommendation candidates.
abstract interface class DiversityStrategyContract {
  List<CuratedCandidate> diversify(
    List<CuratedCandidate> candidates, {
    int targetCount = 15,
  });
}
