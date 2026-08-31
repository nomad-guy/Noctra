import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/neural_recommender_engine.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';
import 'package:noctra/services/ai/mmr_diversity_filter.dart';
import 'package:noctra/services/ai/implicit_signal_tracker.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('On-Device NeuralRecommenderEngine MLP Tests', () {
    test('Predicts probability between 0.0 and 1.0', () {
      final userVec = TasteVectorEngine.getDefaultVector();
      final song = Song(
        id: 'neural_1',
        title: 'Dark Synthwave Night Drive',
        artist: 'The Weeknd',
        album: 'After Hours',
        artworkUrl: null,
        streamUrl: null,
        duration: const Duration(seconds: 240),
        featureVector: TasteVectorEngine.getDefaultVector(),
      );

      final score = NeuralRecommenderEngine.predictScore(
        userVector: userVec,
        song: song,
      );

      expect(score, greaterThan(0.0));
      expect(score, lessThan(1.0));
    });
  });

  group('MMRDiversityFilter Tests', () {
    test('Ensures artist diversity and caps repeat occurrences', () {
      final dummySongs = [
        for (int i = 0; i < 10; i++)
          ScoredCandidate(
            song: Song(
              id: 'song_$i',
              title: 'Song $i',
              artist: i < 5 ? 'Arijit Singh' : 'Taylor Swift',
              album: 'Album',
              artworkUrl: null,
              streamUrl: null,
              duration: const Duration(seconds: 200),
              featureVector: TasteVectorEngine.getDefaultVector(),
            ),
            score: 0.95 - (i * 0.02),
            explanation: 'Neural Match',
          )
      ];

      final diversified = MMRDiversityFilter.rerankWithMMR(
        candidates: dummySongs,
        targetCount: 4,
      );

      final arijitCount = diversified.where((c) => c.song.artist == 'Arijit Singh').length;
      expect(arijitCount, lessThanOrEqualTo(2));
      expect(diversified.length, 4);
    });
  });

  group('ImplicitSignalTracker Tests', () {
    test('Recency decay calculates exponential decay correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final freshDecay = ImplicitSignalTracker.calculateRecencyDecay(now);
      expect(freshDecay, closeTo(1.0, 0.01));

      final twoWeeksAgo = now - (14 * 24 * 60 * 60 * 1000);
      final twoWeekDecay = ImplicitSignalTracker.calculateRecencyDecay(twoWeeksAgo);
      expect(twoWeekDecay, closeTo(0.367, 0.05));
    });
  });
}
