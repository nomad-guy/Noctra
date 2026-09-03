import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../screens/ai_studio_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import 'noir_mini_player.dart';
import 'noir_sidebar.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    AIStudioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final scaffoldKey = ref.watch(rootScaffoldKeyProvider);
    final themeMode = ref.watch(themeModeProvider);

    final canPop = currentIndex == 0 &&
        !(scaffoldKey.currentState?.isDrawerOpen ?? false);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
          scaffoldKey.currentState?.closeDrawer();
        } else if (currentIndex != 0) {
          ref.read(bottomNavIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: themeMode.isLiquidGlass
            ? Colors.transparent
            : context.noctraTokens.canvas,
        drawer: const NoirSidebar(),
        body: Stack(
          children: [
            IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NoirMiniPlayer(),
                    CustomBottomNavBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends ConsumerWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: themeMode.isLiquidGlass ? 22 : 0,
            sigmaY: themeMode.isLiquidGlass ? 22 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 58,
          decoration: BoxDecoration(
            color: themeMode.isLiquidGlass
                ? null
                : (isDark
                    ? const Color(0xF2080808)
                    : const Color(0xF2FFFFFF)),
            gradient: themeMode.isLiquidGlass
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                        tokens.surfaceVariant.withValues(alpha: .86),
                        tokens.surface.withValues(alpha: .80),
                        tokens.secondaryAccent.withValues(alpha: .18)
                      ])
                : null,
            border: Border(
              top: BorderSide(
                color: tokens.subtleBorder,
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, ref, 0, Icons.home_filled, Icons.home_outlined,
                  'Home', currentIndex == 0, isDark),
              _navItem(context, ref, 1, Icons.search_rounded,
                  Icons.search_rounded, 'Search', currentIndex == 1, isDark),
              _navItem(
                  context,
                  ref,
                  2,
                  Icons.library_music_rounded,
                  Icons.library_music_outlined,
                  'Library',
                  currentIndex == 2,
                  isDark),
              _navItem(
                  context,
                  ref,
                  3,
                  Icons.auto_awesome_rounded,
                  Icons.auto_awesome_outlined,
                  'AI Studio',
                  currentIndex == 3,
                  isDark),
            ],
          ),
        ),
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
      onTap: () {
        if (!isSelected) {
          HapticFeedback.selectionClick();
          ref.read(bottomNavIndexProvider.notifier).state = index;
        }
      },
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
