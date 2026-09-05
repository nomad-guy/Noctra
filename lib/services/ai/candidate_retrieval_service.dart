import 'package:flutter/foundation.dart';
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

  /// Only this many top candidates get the (network) Deezer audio-feature
  /// lookup before MLP scoring. The pool can reach ~100 items; fetching
  /// features for all of them serially in chunks could exceed the caller's
  /// UI budget (AI Studio wraps calls in an 8-10s timeout) and leave the
  /// feed empty on slow networks. Candidates ranked below the cap are
  /// scored with neutral audio features — identical fallback to what a
  /// failed/late lookup returns anyway, but without the wait.
  static const int audioFeatureLookupCap = 32;
  static const Duration audioFeatureTimeout = Duration(milliseconds: 600);
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};

  static Future<List<Map<String, dynamic>>> curatePersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
    @visibleForTesting
    Future<AudioFeatures> Function(String title, String artist)? featureFetcher,
    @visibleForTesting List<Song>? poolOverride,
  }) {
    // Test seams and caller-supplied pools must remain fully independent.
    if (featureFetcher != null || poolOverride != null) {
      return _curatePersonalizedFeed(
        vibeKey: vibeKey,
        naturalPrompt: naturalPrompt,
        seedSong: seedSong,
        targetCount: targetCount,
        preferDeepCuts: preferDeepCuts,
        featureFetcher: featureFetcher,
        poolOverride: poolOverride,
      );
    }
    final key = '${vibeKey ?? ''}|${naturalPrompt?.trim().toLowerCase() ?? ''}'
        '|${seedSong?.id ?? ''}|$targetCount|$preferDeepCuts';
    final active = _inFlight[key];
    if (active != null) return active;
    final future = _curatePersonalizedFeed(
      vibeKey: vibeKey,
      naturalPrompt: naturalPrompt,
      seedSong: seedSong,
      targetCount: targetCount,
      preferDeepCuts: preferDeepCuts,
    );
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
  }

  static Future<List<Map<String, dynamic>>> _curatePersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
    @visibleForTesting
    Future<AudioFeatures> Function(String title, String artist)? featureFetcher,
    @visibleForTesting List<Song>? poolOverride,
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
        final similar =
            await MusicService.search('${seedSong.artist} ${seedSong.title}');
        addTracks(similar);
      } catch (_) {}
    }

    // Fetch dynamic live candidates
    try {
      if (poolOverride != null) {
        addTracks(poolOverride);
      } else if (naturalPrompt != null && naturalPrompt.trim().isNotEmpty) {
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
    if (pool.isEmpty && poolOverride == null) {
      for (final item in repo.curateByVibe(
          vibeKey: vibeKey, naturalPrompt: naturalPrompt)) {
        final song = item['song'];
        if (song is Song && song.id.isNotEmpty && seenIds.add(song.id)) {
          pool.add(song);
        }
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
      final seedEmbed = seedSong.hasUsableEmbedding
          ? seedSong.featureVector
          : TasteVectorEngine.extractSongEmbedding(seedSong);
      targetVector =
          TasteVectorEngine.blendVectors(targetVector, seedEmbed, 0.70);
    }

    // Build rich 24-dim context from session
    final contextFeatures = NeuralRecommenderEngine.buildContext(
      sessionSongCount: session.sessionSongCount,
      momentumFeatures: session.momentumFeatures,
      affinityFeatures: session.topArtistAffinityFeatures(),
    );

    // Check if user wants deep cuts / unpopular tracks (case-insensitive)
    final normalizedPrompt = naturalPrompt?.toLowerCase() ?? '';
    final wantsDeepCuts = preferDeepCuts ||
        normalizedPrompt.contains('deep cut') ||
        normalizedPrompt.contains('less popular') ||
        normalizedPrompt.contains('underground') ||
        normalizedPrompt.contains('hidden gem');

    // Stage 2c: cheap embedding pre-rank, so the expensive audio-feature
    // pass below only ever touches the most relevant candidates.
    List<double> embeddingOf(Song s) => s.hasUsableEmbedding
        ? s.featureVector
        : TasteVectorEngine.extractSongEmbedding(s);
    final rankedPool = List<Song>.of(pool)
      ..sort((a, b) =>
          TasteVectorEngine.cosineSimilarity(embeddingOf(b), targetVector)
              .compareTo(TasteVectorEngine.cosineSimilarity(
                  embeddingOf(a), targetVector)));

    // Stage 3: Neural MLP scoring (bounded audio features lookup)
    final List<ScoredCandidate> scored = [];
    final fetchFeatures = featureFetcher ??
        ((t, a) => DeezerAudioFeaturesService.fetchFeatures(t, a));
    const chunkSize = 8;
    // id → fetched audio features for candidates within the lookup cap.
    final audioById = <String, AudioFeatures>{};
    for (int i = 0;
        i < rankedPool.length && i < audioFeatureLookupCap;
        i += chunkSize) {
      final chunk = rankedPool.skip(i).take(chunkSize).toList();
      final featureList = await Future.wait(chunk.map((song) async {
        try {
          return await fetchFeatures(song.title, song.artist)
              .timeout(audioFeatureTimeout);
        } catch (_) {
          return AudioFeatures.defaults;
        }
      }));
      for (int j = 0; j < chunk.length; j++) {
        audioById[chunk[j].id] = featureList[j];
      }
    }

    for (int i = 0; i < rankedPool.length; i++) {
      final song = rankedPool[i];
      final audioFeats = audioById[song.id] ?? AudioFeatures.defaults;

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
      final explanation = TasteVectorEngine.generateExplanation(
          song, score, vibeKey, naturalPrompt);
      scored.add(ScoredCandidate(
          song: song, score: score / 100.0, explanation: explanation));
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
