import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../screens/ai_studio_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import 'custom_bottom_nav_bar.dart';
import 'noir_mini_player.dart';
import 'noir_sidebar.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with RouteAware {
  /// Lazy tab instantiation: each screen is created only on its first visit
  /// (then kept alive inside the IndexedStack so its state survives tab
  /// switches). Avoids eagerly booting Search/Library/AI Studio — and their
  /// network fetches — at app startup for users who never open those tabs.
  final List<Widget?> _screens = List<Widget?>.filled(4, null);
  final Set<int> _visitedTabs = {0};

  /// True while a child route (e.g. ArtistScreen, FolderDetailView) is pushed
  /// on top of this shell. When true, [canPop] is set to `true` ahead of time
  /// so the system-back handler / predictive back engine pops the child route
  /// natively without any imperative Navigator.pop() call from the shell.
  bool _isCoveredByRoute = false;

  Widget _screenFor(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const SearchScreen();
      case 2:
        return const LibraryScreen();
      case 3:
        return const AIStudioScreen();
    }
    return const SizedBox.shrink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when a new route is pushed on top of this shell.
  @override
  void didPushNext() {
    if (!_isCoveredByRoute) setState(() => _isCoveredByRoute = true);
  }

  /// Called when the route above this shell is popped.
  @override
  void didPopNext() {
    if (_isCoveredByRoute) setState(() => _isCoveredByRoute = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final scaffoldKey = ref.watch(rootScaffoldKeyProvider);
    final themeMode = ref.watch(themeModeProvider);

    if (!_visitedTabs.contains(currentIndex)) {
      _visitedTabs.add(currentIndex);
      _screens[currentIndex] = _screenFor(currentIndex);
    }
    // IMPORTANT: IndexedStack.index is an index INTO [children], not a tab
    // id. The list must therefore stay tab-aligned (fixed length 4) so any
    // tab id is always a valid list index. Unvisited slots are trivial
    // SizedBox placeholders so the lazy guarantee holds.
    final children = <Widget>[
      for (var i = 0; i < _screens.length; i++)
        _visitedTabs.contains(i)
            ? (_screens[i] ??= _screenFor(i))
            : const SizedBox.shrink(),
    ];

    // When covered by a child route (_isCoveredByRoute), canPop=true so the
    // native back engine pops the child without any imperative call here.
    // At the root shell: allow exit only when on tab 0 with no drawer open.
    final canPop = _isCoveredByRoute ||
        (currentIndex == 0 &&
            !(scaffoldKey.currentState?.isDrawerOpen ?? false));

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        // If the pop was handled natively (child route), or we're covered —
        // do nothing. Never call Navigator.pop() imperatively from the shell.
        if (didPop || _isCoveredByRoute) return;
        if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
          scaffoldKey.currentState?.closeDrawer();
        } else if (currentIndex != 0) {
          ref.read(bottomNavIndexProvider.notifier).state = 0;
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          if (isWide) {
            return Scaffold(
              key: scaffoldKey,
              backgroundColor: themeMode.isLiquidGlass
                  ? Colors.transparent
                  : context.noctraTokens.canvas,
              body: Row(
                children: [
                  const NoirSidebar(),
                  Expanded(
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: IndexedStack(
                            index: currentIndex,
                            children: children,
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SafeArea(
                            top: false,
                            child: NoirMiniPlayer(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            key: scaffoldKey,
            backgroundColor: themeMode.isLiquidGlass
                ? Colors.transparent
                : context.noctraTokens.canvas,
            drawer: const NoirSidebar(),
            body: Stack(
              children: [
                RepaintBoundary(
                  child: IndexedStack(
                    index: currentIndex,
                    children: children,
                  ),
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
          );
        },
      ),
    );
  }
}
