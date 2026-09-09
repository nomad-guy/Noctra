import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../providers/app_providers.dart';
import '../noctra_app_logo.dart';
import 'home_screen_app_bar_actions.dart';
import 'home_screen_app_bar_desktop_search.dart';

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
    final isDark = widget.isDark;
    final themeMode = widget.themeMode;
    final tokens = context.noctraTokens;
    final totalWidth = MediaQuery.sizeOf(context).width;
    final isWide = totalWidth >= 720;
    final isLargeDesktop = totalWidth >= 1050;

    return SliverAppBar(
      floating: !isWide,
      snap: !isWide,
      pinned: isWide,
      elevation: 0,
      backgroundColor: themeMode.isLiquidGlass
          ? Colors.transparent
          : (isDark ? const Color(0xDD0A0A0A) : const Color(0xDDFAFAFA)),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: isWide ? 62 : 54,
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
                      border: isWide
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
                  border: isWide
                      ? Border(
                          bottom: BorderSide(color: tokens.subtleBorder))
                      : null,
                ),
              ),
      ),
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 16 : 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isLargeDesktop)
              HomeScreenAppBarDesktopSearch(isDark: isDark)
            else
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isWide)
                      IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        icon: Icon(Icons.menu_rounded,
                            color: isDark ? Colors.white : Colors.black,
                            size: 22),
                        tooltip: context.tr(L10nKeys.openSidebar),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(rootScaffoldKeyProvider)
                              .currentState
                              ?.openDrawer();
                        },
                      ),
                    const SizedBox(width: 4),
                    NoctraAppLogo(size: 22, radius: 6, isDark: isDark),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'NOCTRA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: isDark
                              ? NoirColors.blackTextPrimary
                              : NoirColors.whiteTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            HomeScreenAppBarActions(
              isDark: isDark,
              themeMode: themeMode,
              isDesktop: isLargeDesktop,
              refreshTurns: _animController,
              isRefreshing: _isRefreshing,
              onRefresh: _handleRefresh,
            ),
          ],
        ),
      ),
    );
  }
}
