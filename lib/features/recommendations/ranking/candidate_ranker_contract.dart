import '../../../../shared/models/models.dart';
import '../domain/models/recommendation_context.dart';
import '../domain/models/taste_profile.dart';
import '../domain/recommendation_repository_contract.dart';

/// Abstract contract for scoring and ranking candidate tracks.
abstract interface class CandidateRankerContract {
  List<CuratedCandidate> rank({
    required List<Song> candidates,
    required TasteProfile profile,
    required RecommendationContext context,
  });
}
