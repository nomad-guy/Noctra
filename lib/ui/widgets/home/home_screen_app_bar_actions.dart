import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../providers/app_providers.dart';
import '../../screens/settings_sheet.dart';
import '../synccast_sheet.dart';
import 'theme_cycle_button.dart';

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
    final t = context.noctraTokens;
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
      iconSize: 18,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
          minWidth: isDesktop ? 38 : 30, minHeight: isDesktop ? 38 : 30),
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
              : (t.secondaryText),
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
    final t = context.noctraTokens;
    return IconButton(
      tooltip: tooltip,
      iconSize: 18,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
          minWidth: isDesktop ? 38 : 30, minHeight: isDesktop ? 38 : 30),
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
              ? (t.primaryText)
              : (t.secondaryText),
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _refreshButton(BuildContext context) {
    final t = context.noctraTokens;
    return IconButton(
      tooltip: context.tr(L10nKeys.refreshFeed),
      iconSize: 18,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
          minWidth: isDesktop ? 38 : 30, minHeight: isDesktop ? 38 : 30),
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
                ? (t.primaryText)
                : (t.secondaryText),
          ),
        ),
      ),
      onPressed: onRefresh,
    );
  }

  Widget _themeMenuButton(BuildContext context, WidgetRef ref) {
    return ThemeCycleButton(themeMode: themeMode, isDesktop: isDesktop);
  }
}
