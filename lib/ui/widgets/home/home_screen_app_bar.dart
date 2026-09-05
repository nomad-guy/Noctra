import 'dart:ui';
import 'package:flutter/material.dart';
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
/// settings buttons. Extracted from HomeScreen so the screen file stays
/// small and the header can be rebuilt/tested independently.
class HomeScreenAppBar extends ConsumerWidget {
  final bool isDark;
  final NoirThemeMode themeMode;

  const HomeScreenAppBar({
    super.key,
    required this.isDark,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(p2pSyncServiceProvider);

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
                  onPressed: () => ref
                      .read(rootScaffoldKeyProvider)
                      .currentState
                      ?.openDrawer(),
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
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SyncCastSheet(),
                  ),
                ),
                _refreshButton(context, isDark, () async {
                  ref.invalidate(dynamicTrendingFeedProvider);
                  ref.invalidate(dynamicVibeTracksProvider);
                  ref.invalidate(dynamicSpotifyChartsProvider);
                  await Future.delayed(const Duration(milliseconds: 600));
                }),
                _themeMenuButton(context, ref, themeMode, isDark),
                _topBarIcon(
                  Icons.tune_rounded,
                  context.tr(L10nKeys.settings),
                  isDark,
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SettingsSheet(),
                  ),
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

  Widget _refreshButton(BuildContext context, bool isDark, VoidCallback onPressed) {
    return IconButton(
      tooltip: context.tr(L10nKeys.refreshFeed),
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(Icons.refresh_rounded,
          color: isDark ? Colors.white60 : Colors.black54),
      onPressed: onPressed,
    );
  }

  Widget _themeMenuButton(
      BuildContext context, WidgetRef ref, NoirThemeMode current, bool isDark) {
    // Cycle: Noir Black → Noir White → Liquid Glass → Noir Black
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
