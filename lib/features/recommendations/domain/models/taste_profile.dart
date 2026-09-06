import 'dart:math';

/// Representation of a multi-tier, normalized user taste profile.
class TasteProfile {
  static const int dimension = 32;

  final List<double> shortTermVector;
  final List<double> mediumTermVector;
  final List<double> longTermVector;
  final Map<String, double> artistAffinities;
  final Map<String, double> genreAffinities;
  final DateTime updatedAt;

  const TasteProfile({
    required this.shortTermVector,
    required this.mediumTermVector,
    required this.longTermVector,
    required this.artistAffinities,
    required this.genreAffinities,
    required this.updatedAt,
  });

  factory TasteProfile.initial() {
    final def = List<double>.filled(dimension, 0.5);
    return TasteProfile(
      shortTermVector: List.unmodifiable(def),
      mediumTermVector: List.unmodifiable(def),
      longTermVector: List.unmodifiable(def),
      artistAffinities: const {},
      genreAffinities: const {},
      updatedAt: DateTime.now(),
    );
  }

  /// Blends the tiers into a single target scoring vector.
  /// Standard weighting: 50% long-term anchor, 35% medium-term mood, 15% short-term session.
  List<double> get blendedVector {
    final result = List<double>.filled(dimension, 0.5);
    for (int i = 0; i < dimension; i++) {
      final s = i < shortTermVector.length ? shortTermVector[i] : 0.5;
      final m = i < mediumTermVector.length ? mediumTermVector[i] : 0.5;
      final l = i < longTermVector.length ? longTermVector[i] : 0.5;
      result[i] = (l * 0.50 + m * 0.35 + s * 0.15).clamp(0.05, 0.95);
    }
    return result;
  }

  /// Applies temporal exponential half-life decay to the medium-term profile.
  TasteProfile applyDecay({int daysElapsed = 14}) {
    final factor = exp(-0.0495 * daysElapsed);
    final baseline = 0.5;
    final decayedMedium = List<double>.filled(dimension, 0.5);

    for (int i = 0; i < dimension; i++) {
      final cur = i < mediumTermVector.length ? mediumTermVector[i] : baseline;
      decayedMedium[i] = (baseline + (cur - baseline) * factor).clamp(0.05, 0.95);
    }

    return TasteProfile(
      shortTermVector: shortTermVector,
      mediumTermVector: decayedMedium,
      longTermVector: longTermVector,
      artistAffinities: artistAffinities,
      genreAffinities: genreAffinities,
      updatedAt: DateTime.now(),
    );
  }
}
