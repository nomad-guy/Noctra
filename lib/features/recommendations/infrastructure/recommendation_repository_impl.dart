import 'dart:async';
import '../../../data/repositories/music_repository.dart';
import '../../../services/ai/candidate_retrieval_service.dart';
import '../../../shared/models/models.dart';
import '../domain/recommendation_repository_contract.dart';

/// Infrastructure implementation of [RecommendationRepositoryContract].
/// Bridges recommendation requests to [CandidateRetrievalService] and [MusicRepository].
class RecommendationRepositoryImpl implements RecommendationRepositoryContract {
  final MusicRepository _musicRepository;

  RecommendationRepositoryImpl({MusicRepository? musicRepository})
      : _musicRepository = musicRepository ?? MusicRepository.instance;

  @override
  Future<List<CuratedCandidate>> getPersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
  }) async {
    final rawResults = await CandidateRetrievalService.curatePersonalizedFeed(
      vibeKey: vibeKey,
      naturalPrompt: naturalPrompt,
      seedSong: seedSong,
      targetCount: targetCount,
      preferDeepCuts: preferDeepCuts,
    );
    return rawResults.map((m) => CuratedCandidate.fromMap(m)).toList();
  }

  @override
  List<CuratedCandidate> getCuratedByVibe({
    String? vibeKey,
    String? naturalPrompt,
  }) {
    final rawResults = _musicRepository.curateByVibe(
      vibeKey: vibeKey,
      naturalPrompt: naturalPrompt,
    );
    return rawResults.map((m) => CuratedCandidate.fromMap(m)).toList();
  }
}
