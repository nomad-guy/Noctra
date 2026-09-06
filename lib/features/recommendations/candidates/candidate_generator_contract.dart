import 'dart:async';
import '../../../../shared/models/models.dart';
import '../domain/models/recommendation_context.dart';

/// Abstract contract for candidate generation sources
/// (Library, Favorites, Recent, Vibe Feeds, Search, etc.).
abstract interface class CandidateGeneratorContract {
  String get sourceName;

  Future<List<Song>> generateCandidates(RecommendationContext context);
}
