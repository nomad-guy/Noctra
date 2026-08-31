import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/noir_theme.dart';
import '../data/models/song_model.dart';
import '../data/repositories/music_repository.dart';
import '../data/sources/noctra_local_database.dart';
import '../services/audio/audio_player_service.dart';
import '../services/audio/audio_router_service.dart';
import '../services/p2p/p2p_sync_service.dart';
import '../services/ytdlp/music_service.dart';
import '../services/ai/candidate_retrieval_service.dart';
import '../data/models/stream_metadata_model.dart';

// Navigation & App State
final currentNavigationIndexProvider = StateProvider<int>((ref) => 0);
final bottomNavIndexProvider = currentNavigationIndexProvider;
final appInitializedProvider = StateProvider<bool>((ref) => false);
final rootScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) => GlobalKey<ScaffoldState>());

// Theme state with persistent storage
final themeModeProvider = StateProvider<NoirThemeMode>((ref) {
  final saved = NoctraLocalDatabase().getCachedThemeMode();
  if (saved == 'noirWhite') return NoirThemeMode.noirWhite;
  if (saved == 'noirAmoled') return NoirThemeMode.noirAmoled;
  return NoirThemeMode.noirBlack;
});

// Settings state
final audioQualityProvider = StateProvider<String>((ref) => 'Master (320 kbps Lossless CD)');
final lyricsPreferenceProvider = StateProvider<String>((ref) => 'English / Global (Standard)');
final autoplayDelayProvider = StateProvider<int>((ref) => 3);
final audioFadeTransitionProvider = StateProvider<bool>((ref) => true);

// Repository
final musicRepositoryProvider = ChangeNotifierProvider<MusicRepository>((ref) => MusicRepository());

// Audio Player Service & Router
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) => AudioPlayerService());
final audioRouterServiceProvider = Provider<AudioRouterService>((ref) => AudioRouterService());

// Audio Output Devices Stream
final connectedAudioDevicesProvider = StreamProvider<List<AudioDeviceEndpoint>>((ref) {
  final router = ref.watch(audioRouterServiceProvider);
  return router.devicesStream;
});
final initialAudioDevicesProvider = FutureProvider<List<AudioDeviceEndpoint>>((ref) async {
  final router = ref.watch(audioRouterServiceProvider);
  return router.getConnectedDevices();
});

// Current Playing Song Stream Provider
final currentSongStreamProvider = StreamProvider<Song?>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.currentSongStream;
});

// Playing / Paused State
final isPlayingStreamProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.player.playingStream;
});

// Position Stream
final positionStreamProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.player.positionStream;
});

// Volume Stream
final volumeStreamProvider = StreamProvider<double>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.player.volumeStream;
});

// Queue
final queueStreamProvider = StreamProvider<List<Song>>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.queueStream;
});

// Resolution Telemetry Stream Provider
final streamResolutionStreamProvider = StreamProvider<StreamResolutionMetadata?>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.resolutionStream;
});

// Playback Settings (Shuffle & Loop) Stream Provider
final playbackSettingsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final player = ref.watch(audioPlayerServiceProvider);
  return player.playbackSettingsStream;
});

// Active Downloading Song IDs
final downloadingSongsProvider = StateProvider<Set<String>>((ref) => {});

// Search Results
final searchResultsProvider = StateProvider<List<Song>>((ref) => []);
final isSearchingProvider = StateProvider<bool>((ref) => false);
final searchQueryProvider = StateProvider<String>((ref) => '');

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

// Dynamic Live Trending Feed Future Provider
final dynamicTrendingFeedProvider = FutureProvider<List<Song>>((ref) async {
  return MusicService.fetchTrendingFeed();
});

// Dynamic Spotify Charts Future Provider
final selectedSpotifyChartKeyProvider = StateProvider<String>((ref) => 'top_hits');
final dynamicSpotifyChartsProvider = FutureProvider<List<Song>>((ref) async {
  final chart = ref.watch(selectedSpotifyChartKeyProvider);
  return MusicService.fetchSpotifyCharts(chartKey: chart);
});

// Dynamic Live Vibe Feed Future Provider
final dynamicVibeTracksProvider = FutureProvider<List<Song>>((ref) async {
  final vibe = ref.watch(selectedVibeKeyProvider) ?? 'late_night';
  return MusicService.fetchVibeFeed(vibe);
});

// Curated songs provider (Synchronous Fast Knowledge Graph)
final curatedRecommendationsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  final vibe = ref.watch(selectedVibeKeyProvider);
  final prompt = ref.watch(aiPromptProvider);
  return repo.curateByVibe(vibeKey: vibe, naturalPrompt: prompt);
});

// AI Agent Dynamic Recommendations Future Provider (Two-Stage Neural MLP + MMR)
final aiAgentMixProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final prompt = ref.watch(aiPromptProvider);
  final vibe = ref.watch(selectedVibeKeyProvider);
  return CandidateRetrievalService.curatePersonalizedFeed(vibeKey: vibe, naturalPrompt: prompt);
});
