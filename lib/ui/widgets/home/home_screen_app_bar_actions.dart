import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../providers/app_providers.dart';
import '../../screens/settings_sheet.dart';
import '../glass_shard_icon.dart';
import '../synccast_sheet.dart';

class HomeScreenAppBarActions extends ConsumerWidget {
  final bool isDark;
  final NoirThemeMode themeMode;
  final bool isDesktop;
  final Animation<double> refreshTurns;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const HomeScreenAppBarActions({
    super.key,
    required this.isDark,
    required this.themeMode,
    required this.isDesktop,
    required this.refreshTurns,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(p2pSyncServiceProvider);
    final isOffline = ref.watch(isOfflineModeProvider);

    return Row(
      children: [
        _offlineModeButton(context, ref, isOffline),
        if (isDesktop) const SizedBox(width: 4),
        _topBarIcon(
          context,
          Icons.podcasts_rounded,
          context.tr(L10nKeys.partyMode),
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
        if (isDesktop) const SizedBox(width: 4),
        _refreshButton(context),
        if (isDesktop) const SizedBox(width: 6),
        _themeMenuButton(context, ref),
        if (isDesktop) const SizedBox(width: 4),
        _topBarIcon(
          context,
          Icons.tune_rounded,
          context.tr(L10nKeys.settings),
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
    );
  }

  Widget _offlineModeButton(
      BuildContext context, WidgetRef ref, bool isOffline) {
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

  Widget _topBarIcon(
    BuildContext context,
    IconData icon,
    String tooltip, {
    bool active = false,
    required VoidCallback onPressed,
  }) {
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

  Widget _refreshButton(BuildContext context) {
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
          turns: refreshTurns,
          child: Icon(
            Icons.refresh_rounded,
            size: 18,
            color: isRefreshing
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
      onPressed: onRefresh,
    );
  }

  Widget _themeMenuButton(BuildContext context, WidgetRef ref) {
    final themes = [
      NoirThemeMode.noirBlack,
      NoirThemeMode.noirWhite,
      NoirThemeMode.liquidGlass
    ];
    NoirThemeMode nextTheme() {
      final idx = themes.indexOf(themeMode);
      return themes[(idx + 1) % themes.length];
    }

    final themeName = themeMode == NoirThemeMode.liquidGlass
        ? 'Liquid Glass'
        : themeMode == NoirThemeMode.noirWhite
            ? 'Noir White'
            : 'Noir Black';

    final icon = themeMode == NoirThemeMode.liquidGlass
        ? GlassShardIcon(
            size: 16, color: context.noctraTokens.accent, isActive: true)
        : themeMode == NoirThemeMode.noirWhite
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
