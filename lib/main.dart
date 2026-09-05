import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/noir_theme.dart';
import 'services/platform/dynamic_icon_service.dart';
import 'core/utils/noctra_logger.dart';
import 'core/utils/permission_helper.dart';
import 'data/repositories/music_repository.dart';
import 'data/sources/noctra_local_database.dart';
import 'data/repositories/neural_recommender_engine.dart';
import 'providers/app_providers.dart';
import 'services/audio/audio_player_service.dart';
import 'services/audio/noctra_audio_handler.dart';
import 'services/assistant/infrastructure/assistant_intent_channel.dart';
import 'services/updater/app_update_service.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/main_navigation_shell.dart';

/// Media-session handler bridging playback to audio_service. Created during
/// [main] and attached to the playback service once it is constructed.
NoctraAudioHandler? noctraAudioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    } catch (e, st) {
      NoctraLogger.e('AudioService.init failed', e, st);
    }
  }

  try {
    await NoctraLocalDatabase().init();
  } catch (e) {
    NoctraLogger.e('Database init error', e);
  }
  try {
    await NeuralRecommenderEngine.restoreFromDatabase();
  } catch (e) {
    NoctraLogger.w('Neural model restore error', e);
  }
  try {
    await MusicRepository().init();
  } catch (e) {
    NoctraLogger.e('Repository init error', e);
  }

  await DynamicIconService.init();

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
        AssistantIntentChannel(router: noctraAudioHandler!.router).initialize();
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
    final isInitialized = ref.watch(appInitializedProvider);
    final hasCompletedOnboarding = ref.watch(onboardingCompletedProvider);

    ref.listen<NoirThemeMode>(themeModeProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NoctraLocalDatabase().saveCachedThemeMode(next.name);
        _updateSystemUI(next);
      });
    });

    final activeThemeData = NoirTheme.getTheme(themeMode);
    return MaterialApp(
      title: 'Noctra',
      debugShowCheckedModeBanner: false,
      theme: activeThemeData,
      darkTheme: activeThemeData,
      themeMode: themeMode.isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) =>
          NoctraThemeBackdrop(child: child ?? const SizedBox.shrink()),
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
  }
}
