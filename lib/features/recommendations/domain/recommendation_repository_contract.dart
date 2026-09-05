import 'dart:async';
import '../../../shared/models/models.dart';

/// Representation of a curated recommendation candidate.
class CuratedCandidate {
  final Song song;
  final double score;
  final String matchReason;

  const CuratedCandidate({
    required this.song,
    required this.score,
    required this.matchReason,
  });

  Map<String, dynamic> toMap() => {
        'song': song,
        'score': score,
        'matchReason': matchReason,
      };

  factory CuratedCandidate.fromMap(Map<String, dynamic> map) {
    return CuratedCandidate(
      song: map['song'] as Song,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      matchReason: map['matchReason'] as String? ?? 'Curated for your vibe',
    );
  }
}

/// Pure domain contract for personalized recommendations & vibe curation.
abstract class RecommendationRepositoryContract {
  Future<List<CuratedCandidate>> getPersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
  });

  List<CuratedCandidate> getCuratedByVibe({
    String? vibeKey,
    String? naturalPrompt,
  });
}
