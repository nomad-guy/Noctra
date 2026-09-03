part of '../noctra_local_database.dart';

extension LocalDatabaseManifests on NoctraLocalDatabase {
  Future<void> completeOnboarding({
    required List<String> languages,
    required List<String> genres,
    required List<String> artists,
  }) {
    _hasCompletedOnboarding = true;
    _onboardedLanguages = languages;
    _onboardedGenres = genres;
    _onboardedArtists = artists;
    return _enqueuePrefsWrite(() async {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setBool('noctra_onboarded', true);
      await prefs.setStringList('noctra_onboarded_languages', languages);
      await prefs.setStringList('noctra_onboarded_genres', genres);
      await prefs.setStringList('noctra_onboarded_artists', artists);
    });
  }

  Future<void> recordManifest(
    Song song, {
    String action = 'play',
    int listenedSeconds = 0,
    double completionRate = 1.0,
  }) async {
    await init();
    _manifestStore.recordManifest(
      song,
      action: action,
      listenedSeconds: listenedSeconds,
      completionRate: completionRate,
    );
    await _enqueuePrefsWrite(() => _manifestStore.persist());
  }

  List<String> getTopArtists({int limit = 6}) {
    final sorted = _manifestStore.artistWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final historyList = sorted
        .take(limit)
        .map((e) => e.key)
        .where((a) => a.isNotEmpty)
        .toList();
    return <String>{..._onboardedArtists, ...historyList}.take(limit).toList();
  }

  double getArtistAffinity(String artist) {
    if (artist.isEmpty || _manifestStore.artistWeights.isEmpty) return 0.0;
    final w = _manifestStore.artistWeights[artist] ?? 0;
    return (w / 10.0).clamp(0.0, 1.0);
  }

  List<String> getTopGenres({int limit = 4}) {
    final sorted = _manifestStore.genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final history = sorted
        .take(limit)
        .map((e) => e.key)
        .where((g) => g.isNotEmpty)
        .toList();
    return <String>{..._onboardedGenres, ...history}.take(limit).toList();
  }

  List<String> getTopLanguages({int limit = 3}) {
    final sorted = _manifestStore.languageWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final history = sorted
        .take(limit)
        .map((e) => e.key)
        .where((l) => l.isNotEmpty)
        .toList();
    return <String>{..._onboardedLanguages, ...history}.take(limit).toList();
  }

  Map<String, dynamic> getKnowledgeGraphSummary() => {
        'totalTracksLearned': _manifestStore.manifests.length,
        'topArtists': getTopArtists(limit: 4),
        'topGenres': getTopGenres(limit: 3),
        'topLanguages': getTopLanguages(limit: 2),
      };
}
