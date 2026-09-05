import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x: StateProvider & ChangeNotifierProvider moved to legacy.dart.
// Importing both keeps all existing providers working without rewriting.
import 'package:flutter_riverpod/legacy.dart';
import '../core/theme/noir_theme.dart';
import '../services/platform/dynamic_icon_service.dart';
import '../core/utils/noctra_localization.dart';
import '../data/models/song_model.dart';
import '../data/models/catalog_topic.dart';
import '../data/repositories/music_repository.dart';
import '../data/sources/noctra_local_database.dart';
import '../services/audio/audio_player_service.dart';
import '../services/audio/audio_router_service.dart';
import '../services/p2p/p2p_sync_service.dart';
import '../services/ytdlp/music_service.dart';
import '../services/ai/candidate_retrieval_service.dart';
import '../services/discovery/catalog_discovery_service.dart';
import '../data/models/stream_metadata_model.dart';
import '../features/search/domain/search_repository_contract.dart';
import '../features/search/application/search_coordinator.dart';
import '../features/search/infrastructure/search_repository_impl.dart';

// Navigation & App State
final currentNavigationIndexProvider = StateProvider<int>((ref) => 0);
final bottomNavIndexProvider = currentNavigationIndexProvider;
final appInitializedProvider = StateProvider<bool>((ref) => false);
final onboardingCompletedProvider =
    StateProvider<bool>((ref) => NoctraLocalDatabase().hasCompletedOnboarding);
final rootScaffoldKeyProvider =
    Provider<GlobalKey<ScaffoldState>>((ref) => GlobalKey<ScaffoldState>());

// App Language state
final appLanguageProvider = StateProvider<String>((ref) {
  final cached = NoctraLocalDatabase().getCachedLanguage();
  NoctraLocalization.currentLanguage = cached;
  return cached;
});

void updateAppLanguage(WidgetRef ref, String code) {
  NoctraLocalization.currentLanguage = code;
  ref.read(appLanguageProvider.notifier).state = code;
  NoctraLocalDatabase().saveLanguage(code);
}

Future<void> refreshHomeFeeds(WidgetRef ref) async {
  MusicService.clearSearchCache();
  ref.read(homeFeedRefreshNonceProvider.notifier).state++;
  ref.invalidate(dynamicTrendingFeedProvider);
  ref.invalidate(dynamicVibeTracksProvider);
  ref.invalidate(dynamicSpotifyChartsProvider);
}

// Theme state with persistent storage
final themeModeProvider = StateProvider<NoirThemeMode>((ref) {
  final saved = NoctraLocalDatabase().getCachedThemeMode();
  if (saved == 'noirWhite' || saved == 'light') {
    return NoirThemeMode.noirWhite;
  }
  if (saved == 'liquidGlass' || saved == 'liquid_glass') {
    return NoirThemeMode.liquidGlass;
  }
  // Migrate removed noirAmoled to noirBlack
  return NoirThemeMode.noirBlack;
});

// App Icon state (independent of theme, synced from DynamicIconService)
final appIconProvider = StateProvider<NoctraAppIcon>((ref) {
  return DynamicIconService.currentIcon;
});

// Settings state
final audioQualityProvider =
    StateProvider<String>((ref) => 'Master (320 kbps High-Fidelity)');
final lyricsPreferenceProvider =
    StateProvider<String>((ref) => 'English / Global (Standard)');
final autoplayDelayProvider = StateProvider<int>((ref) => 3);
final audioFadeTransitionProvider = StateProvider<bool>((ref) => true);
final downloadLocationProvider = StateProvider<String>(
    (ref) => NoctraLocalDatabase().getCachedDownloadLocation());

// Repository
final musicRepositoryProvider =
    ChangeNotifierProvider<MusicRepository>((ref) => MusicRepository.instance);

// Audio Player Service & Router
final audioPlayerServiceProvider =
    Provider<AudioPlayerService>((ref) => AudioPlayerService.instance);
final audioRouterServiceProvider =
    Provider<AudioRouterService>((ref) => AudioRouterService());

// Audio Output Devices Stream
final connectedAudioDevicesProvider =
    StreamProvider<List<AudioDeviceEndpoint>>((ref) {
  final router = ref.watch(audioRouterServiceProvider);
  return router.devicesStream;
});
final initialAudioDevicesProvider =
    FutureProvider<List<AudioDeviceEndpoint>>((ref) async {
  final router = ref.watch(audioRouterServiceProvider);
  return router.getConnectedDevices();
});

// Sleep Timer Stream
final sleepTimerStreamProvider = StreamProvider<int?>((ref) {
  final audioPlayer = ref.watch(audioPlayerServiceProvider);
  return audioPlayer.playbackSettingsStream.map((s) => s['sleepTimer'] as int?);
});

// Current Playing Song Stream Provider
final currentSongStreamProvider = StreamProvider<Song?>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.currentSongStream;
});

/// Emits a tick whenever AudioPlayerService replaces its underlying player
/// instance (crossfade promotion / preload handoff / recovery).
///
/// The payload is a monotonic counter (see AudioPlayerServiceBase): every
/// swap is a distinct value so Riverpod stream dependents always
/// invalidate. A constant payload would be deduplicated after the first
/// swap and the UI would stay frozen on a disposed player instance.
final playerSwapStreamProvider = StreamProvider<int>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.playerSwapStream;
});

/// Broadcast streams do not replay, and [AudioPlayerService.player] is
/// replaced on every crossfade/preload promotion. A provider bound once to
/// `player.player.*Stream` would keep listening to the disposed previous
/// instance forever. These helpers instead reseed from the live synchronous
/// getters and re-subscribe whenever the swap signal fires, so the UI always
/// mirrors the *current* player instance.
Stream<T> _seedThen<T>(T seed, Stream<T> live) async* {
  yield seed;
  yield* live;
}

// Playing / Paused State
final isPlayingStreamProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  ref.watch(playerSwapStreamProvider);
  return _seedThen(player.player.playing, player.player.playingStream);
});

// Position Stream
final positionStreamProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  ref.watch(playerSwapStreamProvider);
  return _seedThen(player.player.position, player.player.positionStream);
});

// Volume Stream
final volumeStreamProvider = StreamProvider<double>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  ref.watch(playerSwapStreamProvider);
  return _seedThen(player.player.volume, player.player.volumeStream);
});

// Queue
final queueStreamProvider = StreamProvider<List<Song>>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.queueStream;
});

// Resolution Telemetry Stream Provider
final streamResolutionStreamProvider =
    StreamProvider<StreamResolutionMetadata?>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.resolutionStream;
});

// Playback Settings (Shuffle & Loop) Stream Provider
final playbackSettingsStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.playbackSettingsStream;
});

// Active Downloading Song IDs
final downloadingSongsProvider = StateProvider<Set<String>>((ref) => {});

// Search Results
final searchResultsProvider = StateProvider<List<Song>>((ref) => []);
final isSearchingProvider = StateProvider<bool>((ref) => false);
final searchQueryProvider = StateProvider<String>((ref) => '');
final dynamicCatalogTopicsProvider = FutureProvider<List<CatalogTopic>>(
    (ref) => CatalogDiscoveryService.fetchTopics());

// Active Vibe Filter
final selectedVibeKeyProvider = StateProvider<String?>((ref) => 'late_night');
final aiPromptProvider = StateProvider<String>((ref) => '');
final isAICuratingProvider = StateProvider<bool>((ref) => false);

final tasteVectorStateProvider = Provider<List<double>>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.userTasteVector;
});

// P2P Sync Service Provider
final p2pSyncServiceProvider = ChangeNotifierProvider<P2PSyncService>((ref) {
  final service = P2PSyncService();
  final player = ref.watch(audioPlayerServiceProvider);
  service.initialize(player);
  return service;
});

// Home Feed Refresh Nonce Provider
final homeFeedRefreshNonceProvider = StateProvider<int>((ref) => 0);

// Dynamic Live Trending Feed Future Provider
final dynamicTrendingFeedProvider = FutureProvider<List<Song>>((ref) async {
  final nonce = ref.watch(homeFeedRefreshNonceProvider);
  final repo = ref.watch(musicRepositoryProvider);
  return MusicService.fetchTrendingFeed(
    languages: repo.onboardedLanguages,
    genres: repo.onboardedGenres,
    refreshNonce: nonce,
  );
});

// Dynamic Spotify Charts Future Provider
final selectedSpotifyChartKeyProvider = StateProvider<String>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  final genres = repo.onboardedGenres.map((g) => g.toLowerCase()).toList();
  if (genres.any((g) => g.contains('bollywood') || g.contains('sufi'))) {
    return 'bollywood';
  }
  if (genres.any((g) =>
      g.contains('hip-hop') || g.contains('rap') || g.contains('phonk'))) {
    return 'rap_caviar';
  }
  if (genres.any((g) =>
      g.contains('lo-fi') || g.contains('acoustic') || g.contains('indie'))) {
    return 'chill_hits';
  }
  if (genres.any((g) => g.contains('edm') || g.contains('synthwave'))) {
    return 'pop_rising';
  }
  return 'top_hits';
});
final dynamicSpotifyChartsProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(homeFeedRefreshNonceProvider);
  final chart = ref.watch(selectedSpotifyChartKeyProvider);
  return MusicService.fetchSpotifyCharts(chartKey: chart);
});

// Dynamic Live Vibe Feed Future Provider
final dynamicVibeTracksProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(homeFeedRefreshNonceProvider);
  final vibe = ref.watch(selectedVibeKeyProvider) ?? 'late_night';
  return MusicService.fetchVibeFeed(vibe);
});

// Curated songs provider (Synchronous Fast Knowledge Graph)
final curatedRecommendationsProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  final vibe = ref.watch(selectedVibeKeyProvider);
  final prompt = ref.watch(aiPromptProvider);
  return repo.curateByVibe(vibeKey: vibe, naturalPrompt: prompt);
});

// AI Agent Dynamic Recommendations Future Provider (Two-Stage Neural MLP + MMR)
final aiAgentMixProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final prompt = ref.watch(aiPromptProvider);
  final vibe = ref.watch(selectedVibeKeyProvider);
  return CandidateRetrievalService.curatePersonalizedFeed(
      vibeKey: vibe, naturalPrompt: prompt);
});

// Search Subsystem Modular Contract Providers
final searchRepositoryContractProvider = Provider<SearchRepositoryContract>((ref) {
  return SearchRepositoryImpl();
});

final searchCoordinatorProvider = Provider<SearchCoordinator>((ref) {
  return SearchCoordinator(ref.watch(searchRepositoryContractProvider));
});

