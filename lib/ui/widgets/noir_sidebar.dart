import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../providers/app_providers.dart';
import '../../services/updater/app_update_service.dart';
import '../screens/settings_sheet.dart';
import 'developer_panel_sheet.dart';
import 'equalizer_sheet.dart';
import 'noctra_app_logo.dart';
import 'recently_played_sheet.dart';
import 'sidebar/sidebar_item.dart';
import 'sidebar/sidebar_theme_card.dart';
import 'synccast_sheet.dart';

class NoirSidebar extends ConsumerWidget {
  final VoidCallback? onClose;
  const NoirSidebar({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;
    final currentIndex = ref.watch(currentNavigationIndexProvider);
    final repo = ref.watch(musicRepositoryProvider);

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: themeMode.isLiquidGlass
            ? tokens.surface.withValues(alpha: .72)
            : (isDark ? const Color(0xF80A0A0A) : const Color(0xF8F9F9F9)),
        border:
            Border(right: BorderSide(color: tokens.subtleBorder, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      NoctraAppLogo(size: 28, radius: 8, isDark: isDark),
                      const SizedBox(width: 10),
                      Text(
                        NoctraLocalization.tr('app_name'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: isDark
                              ? NoirColors.blackTextPrimary
                              : NoirColors.whiteTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        size: 26,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      tooltip: 'Close Sidebar',
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
            Divider(
                color: isDark ? Colors.white10 : Colors.black12, height: 1),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SidebarItem(
                      icon: Icons.home_filled,
                      label: NoctraLocalization.tr('home'),
                      isSelected: currentIndex == 0,
                      isDark: isDark,
                      onTap: () {
                        ref
                            .read(currentNavigationIndexProvider.notifier)
                            .state = 0;
                        onClose?.call();
                      },
                    ),
                    SidebarItem(
                      icon: Icons.search_rounded,
                      label: NoctraLocalization.tr('search_explore'),
                      isSelected: currentIndex == 1,
                      isDark: isDark,
                      onTap: () {
                        ref
                            .read(currentNavigationIndexProvider.notifier)
                            .state = 1;
                        onClose?.call();
                      },
                    ),
                    SidebarItem(
                      icon: Icons.my_library_music_rounded,
                      label: NoctraLocalization.tr('library_title'),
                      isSelected: currentIndex == 2,
                      isDark: isDark,
                      onTap: () {
                        ref
                            .read(currentNavigationIndexProvider.notifier)
                            .state = 2;
                        onClose?.call();
                      },
                    ),
                    SidebarItem(
                      icon: Icons.auto_awesome_rounded,
                      label: NoctraLocalization.tr('ai_studio_title'),
                      isSelected: currentIndex == 3,
                      isDark: isDark,
                      onTap: () {
                        ref
                            .read(currentNavigationIndexProvider.notifier)
                            .state = 3;
                        onClose?.call();
                      },
                    ),
                    const SizedBox(height: 8),
                    Divider(
                        color: isDark ? Colors.white10 : Colors.black12,
                        height: 1),
                    const SizedBox(height: 8),
                    SidebarItem(
                      icon: Icons.history_rounded,
                      label: NoctraLocalization.tr('recently_played'),
                      isSelected: false,
                      isDark: isDark,
                      onTap: () {
                        onClose?.call();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const RecentlyPlayedSheet(),
                        );
                      },
                    ),
                    SidebarItem(
                      icon: Icons.podcasts_rounded,
                      label: NoctraLocalization.tr('party_mode'),
                      isSelected: false,
                      isDark: isDark,
                      onTap: () {
                        onClose?.call();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const SyncCastSheet(),
                        );
                      },
                    ),
                    SidebarItem(
                      icon: Icons.equalizer_rounded,
                      label: NoctraLocalization.tr('equalizer'),
                      isSelected: false,
                      isDark: isDark,
                      onTap: () {
                        onClose?.call();
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const EqualizerSheet(),
                        );
                      },
                    ),
                    SidebarItem(
                      icon: Icons.terminal_rounded,
                      label: NoctraLocalization.tr('developer_suite'),
                      isSelected: false,
                      isDark: isDark,
                      onTap: () {
                        onClose?.call();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const DeveloperPanelSheet(),
                        );
                      },
                    ),
                    SidebarItem(
                      icon: Icons.tune_rounded,
                      label: NoctraLocalization.tr('settings'),
                      isSelected: false,
                      isDark: isDark,
                      onTap: () {
                        onClose?.call();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const SettingsSheet(),
                        );
                      },
                    ),
                    SidebarItem(
                      icon: Icons.system_update_rounded,
                      label: NoctraLocalization.tr('check_updates'),
                      isSelected: false,
                      isDark: isDark,
                      onTap: () {
                        onClose?.call();
                        AppUpdateService.checkForUpdateManually(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
            SidebarThemeCard(tokens: tokens),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                'On-Device Knowledge Graph • ${repo.downloads.length + repo.favorites.length + repo.recentlyPlayed.length} tracks',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
