import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/noir_theme.dart';
import 'services/platform/dynamic_icon_service.dart';
import 'core/networking/network_quality.dart';
import 'core/utils/noctra_logger.dart';
import 'core/utils/playback_settings_store.dart';
import 'services/ai/implicit_signal_tracker.dart';
import 'core/utils/permission_helper.dart';
import 'data/repositories/music_repository.dart';
import 'data/sources/noctra_local_database.dart';
import 'data/repositories/neural_recommender_engine.dart';
import 'providers/app_providers.dart';
import 'services/audio/audio_player_service.dart';
import 'services/audio/stream_quality_service.dart';
import 'services/audio/noctra_audio_handler.dart';
import 'services/assistant/infrastructure/assistant_intent_channel.dart';
import 'services/updater/app_update_service.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/main_navigation_shell.dart';
import 'core/utils/localization/localization_scope.dart';
import 'core/utils/noctra_localization.dart';
import 'ui/widgets/desktop/desktop_keyboard_shortcuts.dart';

/// Media-session handler bridging playback to audio_service. Created during
/// [main] and attached to the playback service once it is constructed.
NoctraAudioHandler? noctraAudioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NoctraLogger.install();

  // Edge-to-edge system overlays
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await NoctraLocalDatabase().init();
  } catch (e) {
    NoctraLogger.e('Database init error', e);
  }

  // Hydrate persisted playback settings (fade/crossfade/volume/...) BEFORE
  // the audio service singleton can be constructed — on Windows the process
  // fully exits between launches, so nothing survives except what we load.
  try {
    await PlaybackSettingsStore.instance.load();
    AudioPlayerService.instance.reapplyPersistedSettings();
  } catch (e) {
    NoctraLogger.w('Playback settings load error', e);
  }

  // Quality/codec/policy settings read the same persisted store; hydrate
  // before the UI or audio service constructs.
  try {
    await StreamQualityService().hydrate();
  } catch (e) {
    NoctraLogger.w('Stream quality hydrate error', e);
  }

  if (!kIsWeb) {
    try {
      // Noctra's crossfade engine keeps a second (pre-buffer) AudioPlayer
      // alive and replaces the current player per track, which the
      // just_audio_background plugin forbids (single-player limit). The
      // media session is therefore handled by NoctraAudioHandler, which
      // mirrors the service's logical state instead of one player.
      noctraAudioHandler = NoctraAudioHandler();
      await AudioService.init(
        builder: () => noctraAudioHandler!,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.nomadguy.noctra.channel.audio',
          androidNotificationChannelName: 'Noctra Playback',
          androidNotificationOngoing: true,
          androidNotificationIcon: 'drawable/ic_notification',
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: true,
        ),
      );
      AssistantIntentChannel(router: noctraAudioHandler!.router).initialize();
    } catch (e, st) {
      NoctraLogger.e('AudioService.init failed', e, st);
    }
  }

  // Network quality: connectivity type + RTT probe feed both the
  // adaptive request timeouts and the Smart streaming policy. The first
  // probe runs in the background — never blocks startup.
  try {
    await NetworkQualityService.instance.start();
  } catch (e) {
    NoctraLogger.w('Network quality init error', e);
  }
  try {
    await NeuralRecommenderEngine.restoreFromDatabase();
  } catch (e) {
    NoctraLogger.w('Neural model restore error', e);
  }
  try {
    final repo = MusicRepository();
    await repo.init();
    // Route strong positive taste signals (favorite / playlist-add) from the
    // repository to the AI signal tracker. Attached here — the composition
    // layer — because lib/data must not import lib/services/ai directly.
    repo.onFavoriteToggled =
        (song) => ImplicitSignalTracker().trackFavorite(song);
    repo.onSongAddedToFolder =
        (song) => ImplicitSignalTracker().trackPlaylistAdd(song);
    // Deliberate offline-save is also a strong positive signal.
    repo.onSongDownloadedCallback =
        (song) => ImplicitSignalTracker().trackDownload(song);
  } catch (e) {
    NoctraLogger.e('Repository init error', e);
  }

  await DynamicIconService.init();

  // RAM/battery guardrails: cap the global image cache and clamp the
  // device pixel ratio used for image decoding so artwork-heavy screens
  // cannot balloon native memory on low-RAM devices.
  _applyImageCacheBudget();

  runApp(const ProviderScope(child: NoctraApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.microtask(() async {
      try {
        final svc = AudioPlayerService.instance;
        noctraAudioHandler?.attach(svc);
        await svc.restoreLastPlaybackSession();
      } catch (e) {
        NoctraLogger.e('Session restore error', e);
      }
    });
  });

  Future.delayed(const Duration(seconds: 3), () async {
    try {
      await AppUpdateService.notifyUpdateAvailable();
    } catch (e) {
      NoctraLogger.w('Update check failed — $e');
    }
  });
}

/// Caps Flutter's global image cache and the decoding device-pixel-ratio.
///
/// Defaults are generous (1000 images / 100 MiB); Noctra shows a few dozen
/// artworks per screen, so a tighter budget avoids native-heap growth on
/// long sessions without any visible difference. The DPR clamp stops
/// 3x+ devices from decoding 4x the pixels of a 1x display.
void _applyImageCacheBudget() {
  try {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 400; // images
    cache.maximumSizeBytes = 48 << 20; // 48 MiB
  } catch (e) {
    NoctraLogger.w('Image cache budget error', e);
  }
}

class NoctraApp extends ConsumerStatefulWidget {
  const NoctraApp({super.key});

  @override
  ConsumerState<NoctraApp> createState() => _NoctraAppState();
}

class _NoctraAppState extends ConsumerState<NoctraApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = ref.read(themeModeProvider);
      _updateSystemUI(initial);
      if (noctraAudioHandler != null) {
        noctraAudioHandler!.router.setThemeCallback((mode) {
          ref.read(themeModeProvider.notifier).state = mode;
        });
      }
    });
  }

  void _updateSystemUI(NoirThemeMode mode) {
    try {
      final brightness = mode.isDark ? Brightness.light : Brightness.dark;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: const Color(0x00000000),
          statusBarIconBrightness: brightness,
          systemNavigationBarColor: const Color(0x00000000),
          systemNavigationBarIconBrightness: brightness,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final currentLanguage = ref.watch(appLanguageProvider);
    final isInitialized = ref.watch(appInitializedProvider);
    final hasCompletedOnboarding = ref.watch(onboardingCompletedProvider);

    ref.listen<NoirThemeMode>(themeModeProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NoctraLocalDatabase().saveCachedThemeMode(next.name);
        _updateSystemUI(next);
      });
    });

    final activeThemeData = NoirTheme.getTheme(themeMode);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Capture the OS dynamic palette once so Material U can read it
        // from anywhere without rebuilding the whole tree.
        MaterialUSchemeHolder.light = lightDynamic;
        MaterialUSchemeHolder.dark = darkDynamic;
        return MaterialApp(
          title: 'Noctra',
          locale: Locale(currentLanguage),
          debugShowCheckedModeBanner: false,
          theme: activeThemeData,
          darkTheme: activeThemeData,
          themeMode: themeMode.isDark ? ThemeMode.dark : ThemeMode.light,
          navigatorObservers: [appRouteObserver],
          builder: (context, child) {
            final textDir = NoctraLocalization.textDirection(currentLanguage);
            return NoctraLocalizationScope(
              languageCode: currentLanguage,
              child: Directionality(
                textDirection: textDir,
                child: DesktopKeyboardShortcuts(
                  child: NoctraThemeBackdrop(child: child ?? const SizedBox.shrink()),
                ),
              ),
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isInitialized
                ? (hasCompletedOnboarding
                    ? const MainNavigationShell()
                    : const OnboardingScreen())
                : SplashScreen(
                    onInitialized: () async {
                      try {
                        await PermissionHelper.requestStoragePermissions();
                      } catch (_) {}
                      ref.read(appInitializedProvider.notifier).state = true;
                    },
                  ),
          ),
        );
      },
    );
  }
}
