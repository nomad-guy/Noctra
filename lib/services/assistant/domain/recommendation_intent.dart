/// Structured recommendation request intent derived from Google Assistant/Gemini
/// queries or in-app recommendation requests.
class RecommendationIntent {
  final String? genre;
  final String? language;
  final String? mood;
  final double? energy; // 0.0 to 1.0
  final bool? novelty;
  final String? artist;
  final String? context;
  final String? seedTrackId;

  const RecommendationIntent({
    this.genre,
    this.language,
    this.mood,
    this.energy,
    this.novelty,
    this.artist,
    this.context,
    this.seedTrackId,
  });

  /// Parse natural phrases or voice queries into a structured intent.
  factory RecommendationIntent.fromNaturalQuery(String query, {String? currentTrackId}) {
    final lower = query.toLowerCase().trim();

    String? mood;
    if (lower.contains('relax') || lower.contains('calm') || lower.contains('peace') || lower.contains('sleep')) {
      mood = 'chill';
    } else if (lower.contains('energ') || lower.contains('workout') || lower.contains('party') || lower.contains('gym')) {
      mood = 'energetic';
    } else if (lower.contains('focus') || lower.contains('study') || lower.contains('work')) {
      mood = 'focus';
    } else if (lower.contains('sad') || lower.contains('heartbreak') || lower.contains('emotional')) {
      mood = 'melancholy';
    } else if (lower.contains('happy') || lower.contains('uplifting') || lower.contains('feel good')) {
      mood = 'happy';
    }

    String? language;
    if (lower.contains('hindi') || lower.contains('bollywood')) {
      language = 'hindi';
    } else if (lower.contains('punjabi')) {
      language = 'punjabi';
    } else if (lower.contains('tamil')) {
      language = 'tamil';
    } else if (lower.contains('telugu')) {
      language = 'telugu';
    } else if (lower.contains('english') || lower.contains('western') || lower.contains('pop')) {
      language = 'english';
    }

    final isSimilar = lower.contains('similar') ||
        lower.contains('like this') ||
        lower.contains('more like this');

    final isNovel = lower.contains('new') ||
        lower.contains('haven\'t heard') ||
        lower.contains('discover');

    return RecommendationIntent(
      mood: mood,
      language: language,
      novelty: isNovel ? true : null,
      context: query,
      seedTrackId: isSimilar ? currentTrackId : null,
    );
  }

  @override
  String toString() =>
      'RecommendationIntent(genre: $genre, mood: $mood, lang: $language, seed: $seedTrackId)';
}
