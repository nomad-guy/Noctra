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
    final isOffline = ref.watch(isOfflineModeProvider);
    final isDark = widget.isDark;
    final themeMode = widget.themeMode;
    final tokens = context.noctraTokens;
    final isDesktop = MediaQuery.sizeOf(context).width >= 720;

    return SliverAppBar(
      floating: !isDesktop,
      snap: !isDesktop,
      pinned: isDesktop,
      elevation: 0,
      backgroundColor: themeMode.isLiquidGlass
          ? Colors.transparent
          : (isDark ? const Color(0xDD0A0A0A) : const Color(0xDDFAFAFA)),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: isDesktop ? 62 : 54,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: RepaintBoundary(
        child: themeMode.isLiquidGlass
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: .58),
                      border: isDesktop
                          ? Border(
                              bottom: BorderSide(color: tokens.subtleBorder))
                          : null,
                    ),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xF20A0A0A)
                      : const Color(0xF2FAFAFA),
                  border: isDesktop
                      ? Border(
                          bottom: BorderSide(color: tokens.subtleBorder))
                      : null,
                ),
              ),
      ),
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Section
            if (!isDesktop)
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
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: tokens.subtleBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_rounded,
                            size: 16, color: tokens.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Discover Feed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: isDark
                                ? NoirColors.blackTextPrimary
                                : NoirColors.whiteTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(currentNavigationIndexProvider.notifier)
                          .state = 1;
                    },
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x12FFFFFF)
                            : const Color(0x08000000),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tokens.subtleBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 16,
                              color: isDark ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search songs, artists, albums...',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x14000000),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ctrl+K',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            // Right Section
            Row(
              children: [
                _offlineModeButton(context, isOffline, isDark, isDesktop),
                if (isDesktop) const SizedBox(width: 4),
                _topBarIcon(
                  Icons.podcasts_rounded,
                  context.tr(L10nKeys.partyMode),
                  isDark,
                  active: syncService.isHost || syncService.isClient,
                  isDesktop: isDesktop,
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
                if (isDesktop) const SizedBox(width: 4),
                _refreshButton(context, isDark, isDesktop),
                if (isDesktop) const SizedBox(width: 6),
                _themeMenuButton(context, ref, themeMode, isDark, isDesktop),
                if (isDesktop) const SizedBox(width: 4),
                _topBarIcon(
                  Icons.tune_rounded,
                  context.tr(L10nKeys.settings),
                  isDark,
                  isDesktop: isDesktop,
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

  Widget _offlineModeButton(
      BuildContext context, bool isOffline, bool isDark, bool isDesktop) {
    if (isDesktop && isOffline) {
      return GestureDetector(
        onTap: () {
          toggleOfflineMode(ref);
          ref.invalidate(dynamicTrendingFeedProvider);
          ref.invalidate(dynamicVibeTracksProvider);
          ref.invalidate(dynamicSpotifyChartsProvider);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x2400E5FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x8000E5FF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 15, color: Color(0xFF00E5FF)),
              SizedBox(width: 6),
              Text(
                'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      tooltip: isOffline ? 'Offline Mode (Active)' : 'Downloads Only (Offline)',
      iconSize: 20,
      constraints: BoxConstraints(
          minWidth: isDesktop ? 38 : 36, minHeight: isDesktop ? 38 : 36),
      icon: Container(
        padding: isDesktop ? const EdgeInsets.all(7) : EdgeInsets.zero,
        decoration: isDesktop
            ? BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                shape: BoxShape.circle,
                border: Border.all(color: context.noctraTokens.subtleBorder),
              )
            : null,
        child: Icon(
          isOffline ? Icons.cloud_off_rounded : Icons.cloud_queue_rounded,
          size: 18,
          color: isOffline
              ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF007A87))
              : (isDark ? Colors.white60 : Colors.black54),
        ),
      ),
      onPressed: () {
        toggleOfflineMode(ref);
        ref.invalidate(dynamicTrendingFeedProvider);
        ref.invalidate(dynamicVibeTracksProvider);
        ref.invalidate(dynamicSpotifyChartsProvider);
      },
    );
  }

  Widget _topBarIcon(IconData icon, String tooltip, bool isDark,
      {bool active = false,
      bool isDesktop = false,
      required VoidCallback onPressed}) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      constraints: BoxConstraints(
          minWidth: isDesktop ? 38 : 36, minHeight: isDesktop ? 38 : 36),
      icon: Container(
        padding: isDesktop ? const EdgeInsets.all(7) : EdgeInsets.zero,
        decoration: isDesktop
            ? BoxDecoration(
                color: active
                    ? (isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x1A000000))
                    : (isDark
                        ? const Color(0x14FFFFFF)
                        : const Color(0x0A000000)),
                shape: BoxShape.circle,
                border: Border.all(
                    color: active
                        ? context.noctraTokens.accent
                        : context.noctraTokens.subtleBorder),
              )
            : null,
        child: Icon(
          icon,
          size: 18,
          color: active
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white60 : Colors.black54),
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _refreshButton(BuildContext context, bool isDark, bool isDesktop) {
    return IconButton(
      tooltip: context.tr(L10nKeys.refreshFeed),
      iconSize: 20,
      constraints: BoxConstraints(
          minWidth: isDesktop ? 38 : 36, minHeight: isDesktop ? 38 : 36),
      icon: Container(
        padding: isDesktop ? const EdgeInsets.all(7) : EdgeInsets.zero,
        decoration: isDesktop
            ? BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                shape: BoxShape.circle,
                border: Border.all(color: context.noctraTokens.subtleBorder),
              )
            : null,
        child: RotationTransition(
          turns: _animController,
          child: Icon(
            Icons.refresh_rounded,
            size: 18,
            color: _isRefreshing
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
      onPressed: _handleRefresh,
    );
  }

  Widget _themeMenuButton(BuildContext context, WidgetRef ref,
      NoirThemeMode current, bool isDark, bool isDesktop) {
    final themes = [
      NoirThemeMode.noirBlack,
      NoirThemeMode.noirWhite,
      NoirThemeMode.liquidGlass
    ];
    NoirThemeMode nextTheme() {
      final idx = themes.indexOf(current);
      return themes[(idx + 1) % themes.length];
    }

    final themeName = current == NoirThemeMode.liquidGlass
        ? 'Liquid Glass'
        : current == NoirThemeMode.noirWhite
            ? 'Noir White'
            : 'Noir Black';

    final icon = current == NoirThemeMode.liquidGlass
        ? GlassShardIcon(
            size: 16, color: context.noctraTokens.accent, isActive: true)
        : current == NoirThemeMode.noirWhite
            ? Icon(Icons.light_mode_outlined,
                size: 16, color: isDark ? Colors.white70 : Colors.black87)
            : Icon(Icons.dark_mode_outlined,
                size: 16, color: isDark ? Colors.white70 : Colors.black87);

    if (isDesktop) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).state = nextTheme();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.noctraTokens.subtleBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 7),
              Text(
                themeName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: isDark
                      ? NoirColors.blackTextPrimary
                      : NoirColors.whiteTextPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
