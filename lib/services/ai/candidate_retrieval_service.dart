import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/neural_recommender_engine.dart';
import '../../data/repositories/taste_vector_engine.dart';
import '../../services/metadata/deezer_audio_features_service.dart';
import '../../services/ytdlp/music_service.dart';
import 'mmr_diversity_filter.dart';
import 'session_context_tracker.dart';

class CandidateRetrievalService {
  // Two-stage neural retrieval + MLP scoring + MMR diversity + session context
  static Future<List<Map<String, dynamic>>> curatePersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
  }) async {
    final repo = MusicRepository();
    final session = SessionContextTracker();
    final longTerm = repo.userTasteVector;

    // Blended user vector: 60% long-term + 40% session
    final userVector = session.sessionSongCount > 3
        ? session.blendedVector(longTerm)
        : longTerm;

    // Stage 1: Candidate pool (~100 items)
    final Set<String> seenIds = {};
    final List<Song> pool = [];
    void addTracks(List<Song> tracks) {
      for (final s in tracks) {
        if (s.id.isNotEmpty && seenIds.add(s.id)) pool.add(s);
      }
    }
    addTracks(repo.localLibrary);
    addTracks(repo.downloads);
    addTracks(repo.recentlyPlayed);
    addTracks(repo.favorites);

    // Seed song context: "something like this"
    if (seedSong != null) {
      try {
        final similar = await MusicService.search('${seedSong.artist} ${seedSong.title}');
        addTracks(similar);
      } catch (_) {}
    }

    // Fetch dynamic live candidates
    try {
      if (naturalPrompt != null && naturalPrompt.trim().isNotEmpty) {
        final clean = naturalPrompt.trim();
        final results = await Future.wait([
          MusicService.search(clean).catchError((_) => <Song>[]),
          MusicService.search('$clean top songs').catchError((_) => <Song>[]),
        ]);
        for (final list in results) {
          addTracks(list);
        }
      } else if (vibeKey != null) {
        final vibeTracks = await MusicService.fetchVibeFeed(vibeKey);
        addTracks(vibeTracks);
      } else {
        final trending = await MusicService.fetchTrendingFeed();
        addTracks(trending);
      }
    } catch (_) {}

    // Keep the AI surface useful during network outages or a first-run cold
    // start. Local recommendations are still ranked by the same model.
    if (pool.isEmpty) {
      for (final item in repo.curateByVibe(vibeKey: vibeKey, naturalPrompt: naturalPrompt)) {
        final song = item['song'];
        if (song is Song && song.id.isNotEmpty && seenIds.add(song.id)) pool.add(song);
      }
    }
    if (pool.isEmpty) return [];

    // Stage 2: Build target vector applying prompt modifiers + vibe
    List<double> targetVector = TasteVectorEngine.getTargetVector(
      vibeKey: vibeKey,
      prompt: naturalPrompt,
      defaultTaste: userVector,
    );

    // If seed song given, blend its embedding into target (30%)
    if (seedSong != null) {
      final seedEmbed = seedSong.featureVector.every((x) => x == 0.5)
          ? TasteVectorEngine.extractSongEmbedding(seedSong)
          : seedSong.featureVector;
      targetVector = TasteVectorEngine.blendVectors(targetVector, seedEmbed, 0.70);
    }

    // Build rich 24-dim context from session
    final contextFeatures = NeuralRecommenderEngine.buildContext(
      sessionSongCount: session.sessionSongCount,
      momentumFeatures: session.momentumFeatures,
      affinityFeatures: session.topArtistAffinityFeatures(),
    );

    // Check if user wants deep cuts / unpopular tracks
    final wantsDeepCuts = preferDeepCuts ||
        (naturalPrompt != null &&
            (naturalPrompt.contains('deep cut') || naturalPrompt.contains('less popular') ||
             naturalPrompt.contains('underground') || naturalPrompt.contains('hidden gem')));

    // Stage 3: Neural MLP scoring (with audio features from Deezer)
    final List<ScoredCandidate> scored = [];
    for (final song in pool) {
      // Fetch audio features for this song (cached after first lookup)
      AudioFeatures audioFeats;
      try {
        audioFeats = await DeezerAudioFeaturesService.fetchFeatures(
            song.title, song.artist);
      } catch (_) {
        audioFeats = AudioFeatures.defaults;
      }

      double mlpProb = NeuralRecommenderEngine.predictScore(
        userVector: targetVector,
        song: song,
        contextFeatures: contextFeatures,
        audioFeatures: audioFeats.toFeatureVector(),
      );

      // Deep cuts: penalize songs from frequently played artists
      if (wantsDeepCuts) {
        final artistKey = song.artist.toLowerCase();
        final topArtists = session.artistAffinity;
        if ((topArtists[artistKey] ?? 0.0) > 0.7) mlpProb *= 0.6;
      }

      final int score = ((mlpProb * 85) + 14).round().clamp(10, 99);
      final explanation = TasteVectorEngine.generateExplanation(song, score, vibeKey, naturalPrompt);
      scored.add(ScoredCandidate(song: song, score: score / 100.0, explanation: explanation));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Stage 4: MMR diversity reranker
    final diversified = MMRDiversityFilter.rerankWithMMR(
      candidates: scored,
      targetCount: targetCount,
      lambda: 0.75,
    );

    return diversified.map((d) => d.toMap()).toList();
  }
}
