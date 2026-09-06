import 'dart:async';
import '../models/recommendation_context.dart';
import '../models/recommendation_event.dart';
import '../models/taste_profile.dart';
import '../recommendation_repository_contract.dart';

/// Pure domain interface for the modular recommendation pipeline.
abstract interface class RecommendationEngineContract {
  /// Curates a ranked, diversified feed according to [context].
  Future<List<CuratedCandidate>> curateFeed(RecommendationContext context);

  /// Ingests a user behavioral event to update the taste profile.
  Future<void> recordEvent(RecommendationEvent event);

  /// Current user multi-tier taste profile snapshot.
  TasteProfile get currentProfile;

  /// Stream of taste profile updates.
  Stream<TasteProfile> get profileStream;
}
