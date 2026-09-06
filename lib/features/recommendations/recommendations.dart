/// Recommendations Feature Module
///
/// Exposes public domain contracts, models, and modular engines for recommendations.
library;

export 'domain/recommendation_repository_contract.dart';
export 'domain/contracts/recommendation_engine_contract.dart';
export 'domain/models/recommendation_context.dart';
export 'domain/models/recommendation_event.dart';
export 'domain/models/taste_profile.dart';
export 'candidates/candidate_generator_contract.dart';
export 'ranking/candidate_ranker_contract.dart';
export 'ranking/hybrid_candidate_ranker.dart';
export 'diversity/diversity_strategy_contract.dart';
export 'diversity/mmr_diversity_reranker.dart';
export 'events/event_qualifier.dart';
export 'infrastructure/recommendation_repository_impl.dart';
