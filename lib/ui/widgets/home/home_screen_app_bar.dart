import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../providers/app_providers.dart';
import '../synccast_sheet.dart';
import '../noctra_app_logo.dart';
import '../glass_shard_icon.dart';
import '../../screens/settings_sheet.dart';

/// Collapsing / Expanding floating glass header for the home screen.
///
/// Owns the sidebar menu, SyncCast, feed refresh, theme cycling and
/// settings buttons with tactile haptic feedback and smooth refresh spin.
class HomeScreenAppBar extends ConsumerStatefulWidget {
  final bool isDark;
  final NoirThemeMode themeMode;

  const HomeScreenAppBar({
    super.key,
    required this.isDark,
    required this.themeMode,
  });

  @override
  ConsumerState<HomeScreenAppBar> createState() => _HomeScreenAppBarState();
}

class _HomeScreenAppBarState extends ConsumerState<HomeScreenAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    _animController.repeat();
    try {
      await refreshHomeFeeds(ref);
      await Future.delayed(const Duration(milliseconds: 650));
    } finally {
      if (mounted) {
        _animController.stop();
        _animController.reset();
        setState(() => _isRefreshing = false);
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(p2pSyncServiceProvider);
    final isDark = widget.isDark;
    final themeMode = widget.themeMode;

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      backgroundColor: themeMode.isLiquidGlass
          ? Colors.transparent
          : (isDark ? const Color(0xDD0A0A0A) : const Color(0xDDFAFAFA)),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 54,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: RepaintBoundary(
        child: themeMode.isLiquidGlass
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: context.noctraTokens.surface.withValues(alpha: .54),
                  ),
                ),
              )
            : Container(
                color: isDark
                    ? const Color(0xF20A0A0A)
                    : const Color(0xF2FAFAFA),
              ),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.menu_rounded,
                      color: isDark ? Colors.white : Colors.black, size: 22),
                  tooltip: context.tr(L10nKeys.openSidebar),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(rootScaffoldKeyProvider)
                        .currentState
                        ?.openDrawer();
                  },
                ),
                NoctraAppLogo(size: 24, radius: 6, isDark: isDark),
                const SizedBox(width: 6),
                Text(
                  'NOCTRA',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: isDark
                        ? NoirColors.blackTextPrimary
                        : NoirColors.whiteTextPrimary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _topBarIcon(
                  Icons.podcasts_rounded,
                  context.tr(L10nKeys.partyMode),
                  isDark,
                  active: syncService.isHost || syncService.isClient,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SyncCastSheet(),
                    );
                  },
                ),
                _refreshButton(context, isDark),
                _themeMenuButton(context, ref, themeMode, isDark),
                _topBarIcon(
                  Icons.tune_rounded,
                  context.tr(L10nKeys.settings),
                  isDark,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SettingsSheet(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBarIcon(IconData icon, String tooltip, bool isDark,
      {bool active = false, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon,
          color: active
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white60 : Colors.black54)),
      onPressed: onPressed,
    );
  }

  Widget _refreshButton(BuildContext context, bool isDark) {
    return IconButton(
      tooltip: context.tr(L10nKeys.refreshFeed),
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: RotationTransition(
        turns: _animController,
        child: Icon(
          Icons.refresh_rounded,
          color: _isRefreshing
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white60 : Colors.black54),
        ),
      ),
      onPressed: _handleRefresh,
    );
  }

  Widget _themeMenuButton(
      BuildContext context, WidgetRef ref, NoirThemeMode current, bool isDark) {
    final themes = [
      NoirThemeMode.noirBlack,
      NoirThemeMode.noirWhite,
      NoirThemeMode.liquidGlass
    ];
    NoirThemeMode nextTheme() {
      final idx = themes.indexOf(current);
      return themes[(idx + 1) % themes.length];
    }

    final icon = current == NoirThemeMode.liquidGlass
        ? GlassShardIcon(
            size: 20, color: context.noctraTokens.accent, isActive: true)
        : current == NoirThemeMode.noirWhite
            ? Icon(Icons.light_mode_outlined,
                color: isDark ? Colors.white60 : Colors.black54)
            : Icon(Icons.dark_mode_outlined,
                color: isDark ? Colors.white60 : Colors.black54);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(themeModeProvider.notifier).state = nextTheme();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        child: icon,
      ),
    );
  }
}
