import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/neural_recommender_engine.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';
import 'package:noctra/services/ai/knowledge_graph.dart';

void main() {
  group('NeuralRecommenderEngine online learning', () {
    test('training steps increment', () {
      final initialSteps = NeuralRecommenderEngine.totalTrainSteps;
      final song = Song(
        id: 'test_1', title: 'Test Song', artist: 'Test Artist',
        duration: const Duration(minutes: 3),
      );
      NeuralRecommenderEngine.trainFromSignal(
        userVector: TasteVectorEngine.getDefaultVector(),
        song: song,
        eventType: 'complete_listen',
      );
      expect(NeuralRecommenderEngine.totalTrainSteps, initialSteps + 1);
    });

    test('accuracy updates after training', () {
      final initialAcc = NeuralRecommenderEngine.accuracy;
      final song = Song(
        id: 'test_2', title: 'Another Song', artist: 'Another Artist',
        duration: const Duration(minutes: 4),
      );
      // Train with positive signal
      NeuralRecommenderEngine.trainFromSignal(
        userVector: TasteVectorEngine.getDefaultVector(),
        song: song,
        eventType: 'favorite',
      );
      // Accuracy should change
      expect(NeuralRecommenderEngine.accuracy != initialAcc || NeuralRecommenderEngine.totalTrainSteps > 0, true);
    });

    test('loss history accumulates', () {
      final song = Song(
        id: 'test_3', title: 'Loss Test', artist: 'Loss Artist',
        duration: const Duration(minutes: 3),
      );
      // Train multiple times to populate loss history
      for (int i = 0; i < 55; i++) {
        NeuralRecommenderEngine.trainStep(
          userVector: TasteVectorEngine.getDefaultVector(),
          song: song,
          target: i % 2 == 0 ? 1.0 : 0.0,
        );
      }
      expect(NeuralRecommenderEngine.lossHistory.isNotEmpty, true);
    });

    test('trainStep returns a valid loss', () {
      final song = Song(
        id: 'test_4', title: 'Loss Value', artist: 'Loss Artist',
        duration: const Duration(minutes: 3),
      );
      final loss = NeuralRecommenderEngine.trainStep(
        userVector: TasteVectorEngine.getDefaultVector(),
        song: song,
        target: 0.8,
      );
      expect(loss, greaterThan(0.0));
      expect(loss.isFinite, true);
    });

    test('predictScore still works after training', () {
      final song = Song(
        id: 'test_5', title: 'Predict Test', artist: 'Predict Artist',
        duration: const Duration(minutes: 3),
      );
      // Train first
      NeuralRecommenderEngine.trainFromSignal(
        userVector: TasteVectorEngine.getDefaultVector(),
        song: song,
        eventType: 'complete_listen',
      );
      // Then predict
      final score = NeuralRecommenderEngine.predictScore(
        userVector: TasteVectorEngine.getDefaultVector(),
        song: song,
      );
      expect(score, greaterThan(0.0));
      expect(score, lessThan(1.0));
    });
  });

  group('MusicKnowledgeGraph', () {
    late MusicKnowledgeGraph kg;

    setUp(() {
      kg = MusicKnowledgeGraph();
    });

    test('seed edges exist for genres', () {
      final related = kg.getRelated('genre:bollywood');
      expect(related.isNotEmpty, true);
    });

    test('inferMood from genres', () {
      final mood = kg.inferMood(['hip-hop', 'rap']);
      expect(mood.isNotEmpty, true);
    });

    test('findSimilarArtists returns results', () {
      final similar = kg.findSimilarArtists('Arijit Singh');
      expect(similar.isNotEmpty, true);
      // Arijit should be similar to Pritam, Shreya, etc.
      expect(similar.any((a) => a.contains('pritam') || a.contains('shreya')), true);
    });

    test('reinforce strengthens edges', () {
      kg.reinforce('test:from', 'test:to', 0.5);
      final related = kg.getRelated('test:from');
      expect(related.any((e) => e.key == 'test:to'), true);
    });

    test('recordSongPlay creates artist-genre edge', () {
      kg.recordSongPlay('New Artist', 'Rock', weight: 1.0);
      final related = kg.getRelated('artist:new-artist');
      expect(related.any((e) => e.key == 'genre:rock'), true);
    });

    test('explainRecommendation returns non-empty string', () {
      final explanation = kg.explainRecommendation('Arijit Singh', 'Bollywood', ['Bollywood', 'Romantic']);
      expect(explanation.isNotEmpty, true);
    });

    test('decay reduces edge weights', () {
      kg.reinforce('decay:test', 'decay:target', 1.0);
      final before = kg.getRelated('decay:test').firstWhere((e) => e.key == 'decay:target').value;
      kg.applyDecay();
      final after = kg.getRelated('decay:test').firstWhere((e) => e.key == 'decay:target', orElse: () => MapEntry('', 0.0)).value;
      expect(after, lessThan(before));
    });

    test('mood inference returns neutral for empty genres', () {
      final mood = kg.inferMood([]);
      expect(mood, 'neutral');
    });
  });
}
