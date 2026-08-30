import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/theme/noir_theme.dart';
import 'core/utils/permission_helper.dart';
import 'data/repositories/music_repository.dart';
import 'data/sources/noctra_local_database.dart';
import 'providers/app_providers.dart';
import 'services/audio/audio_player_service.dart';
import 'ui/screens/ai_studio_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/noir_mini_player.dart';
import 'ui/widgets/noir_sidebar.dart';

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

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.nomadguy.noctra.channel.audio',
    androidNotificationChannelName: 'Noctra Playback',
    androidNotificationOngoing: true,
  );

  await NoctraLocalDatabase().init();
  await MusicRepository().init();
  await AudioPlayerService().restoreLastPlaybackSession();

  runApp(const ProviderScope(child: NoctraApp()));
}

class NoctraApp extends ConsumerWidget {
  const NoctraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isInitialized = ref.watch(appInitializedProvider);

    return MaterialApp(
      title: 'Noctra',
      debugShowCheckedModeBanner: false,
      theme: NoirTheme.getTheme(themeMode),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: isInitialized
            ? const MainNavigationShell()
            : SplashScreen(
                onInitialized: () {
                  PermissionHelper.requestStoragePermissions();
                  ref.read(appInitializedProvider.notifier).state = true;
                },
              ),
      ),
    );
  }
}

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  static final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const LibraryScreen(),
    const AIStudioScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final scaffoldKey = ref.watch(rootScaffoldKeyProvider);

    return Scaffold(
      key: scaffoldKey,
      drawer: const NoirSidebar(),
      backgroundColor: isDark ? (themeMode.isAmoled ? const Color(0xFF000000) : const Color(0xFF070709)) : const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  NoirMiniPlayer(),
                  _CustomBottomNavBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomBottomNavBar extends ConsumerWidget {
  const _CustomBottomNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: isDark ? (themeMode.isAmoled ? const Color(0xFF000000) : const Color(0xF2080808)) : const Color(0xF2FFFFFF),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, ref, 0, Icons.home_filled, Icons.home_outlined, 'Home', currentIndex == 0, isDark),
          _navItem(context, ref, 1, Icons.search_rounded, Icons.search_rounded, 'Search', currentIndex == 1, isDark),
          _navItem(context, ref, 2, Icons.library_music_rounded, Icons.library_music_outlined, 'Library', currentIndex == 2, isDark),
          _navItem(context, ref, 3, Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, 'AI Studio', currentIndex == 3, isDark),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    bool isSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => ref.read(bottomNavIndexProvider.notifier).state = index,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              size: 24,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
