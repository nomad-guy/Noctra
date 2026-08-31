import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../providers/app_providers.dart';
import '../../services/updater/app_update_service.dart';
import '../screens/settings_sheet.dart';
import 'developer_panel_sheet.dart';
import 'equalizer_sheet.dart';
import 'glass_card.dart';
import 'synccast_sheet.dart';
import 'recently_played_sheet.dart';
import 'noctra_app_logo.dart';

class NoirSidebar extends ConsumerWidget {
  final VoidCallback? onClose;
  const NoirSidebar({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final currentIndex = ref.watch(currentNavigationIndexProvider);
    final repo = ref.watch(musicRepositoryProvider);

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF80A0A0A) : const Color(0xF8F9F9F9),
        border: Border(right: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
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
                          color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, size: 26, color: isDark ? Colors.white70 : Colors.black87),
                      tooltip: 'Close Sidebar',
                      onPressed: onClose,
                    ),
                ],
              ),
            ),

            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
            const SizedBox(height: 12),

            // Navigation
            _sidebarItem(
              icon: Icons.home_filled,
              label: 'Home',
              isSelected: currentIndex == 0,
              isDark: isDark,
              onTap: () {
                ref.read(currentNavigationIndexProvider.notifier).state = 0;
                onClose?.call();
              },
            ),
            _sidebarItem(
              icon: Icons.search_rounded,
              label: NoctraLocalization.tr('search_explore'),
              isSelected: currentIndex == 1,
              isDark: isDark,
              onTap: () {
                ref.read(currentNavigationIndexProvider.notifier).state = 1;
                onClose?.call();
              },
            ),
            _sidebarItem(
              icon: Icons.my_library_music_rounded,
              label: NoctraLocalization.tr('library_title'),
              isSelected: currentIndex == 2,
              isDark: isDark,
              onTap: () {
                ref.read(currentNavigationIndexProvider.notifier).state = 2;
                onClose?.call();
              },
            ),
            _sidebarItem(
              icon: Icons.auto_awesome_rounded,
              label: NoctraLocalization.tr('ai_studio_title'),
              isSelected: currentIndex == 3,
              isDark: isDark,
              onTap: () {
                ref.read(currentNavigationIndexProvider.notifier).state = 3;
                onClose?.call();
              },
            ),

            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
            const SizedBox(height: 12),

            _sidebarItem(
              icon: Icons.history_rounded,
              label: 'Recently Played',
              isSelected: false,
              isDark: isDark,
              onTap: () {
                onClose?.call();
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const RecentlyPlayedSheet());
              },
            ),
            _sidebarItem(
              icon: Icons.podcasts_rounded,
              label: NoctraLocalization.tr('party_mode'),
              isSelected: false,
              isDark: isDark,
              onTap: () {
                onClose?.call();
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const SyncCastSheet());
              },
            ),
            _sidebarItem(
              icon: Icons.equalizer_rounded,
              label: 'Equalizer FX',
              isSelected: false,
              isDark: isDark,
              onTap: () {
                onClose?.call();
                showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => const EqualizerSheet());
              },
            ),
            _sidebarItem(
              icon: Icons.terminal_rounded,
              label: 'Developer Suite',
              isSelected: false,
              isDark: isDark,
              onTap: () {
                onClose?.call();
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const DeveloperPanelSheet());
              },
            ),
            _sidebarItem(
              icon: Icons.tune_rounded,
              label: NoctraLocalization.tr('settings'),
              isSelected: false,
              isDark: isDark,
              onTap: () {
                onClose?.call();
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const SettingsSheet());
              },
            ),
            _sidebarItem(
              icon: Icons.system_update_rounded,
              label: 'Check for Updates',
              isSelected: false,
              isDark: isDark,
              onTap: () {
                onClose?.call();
                AppUpdateService.checkForUpdateManually(context);
              },
            ),

            const Spacer(),

            // Theme Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                radius: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: isDark ? Colors.white : Colors.black),
                        const SizedBox(width: 8),
                        Text(isDark ? 'Noir Black' : 'Noir White', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                    Switch(
                      value: isDark,
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF2C2C2E),
                      inactiveThumbColor: Colors.black,
                      inactiveTrackColor: const Color(0xFFE5E5EA),
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).state = val ? NoirThemeMode.noirBlack : NoirThemeMode.noirWhite;
                      },
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Text(
                'On-Device Knowledge Graph • ${repo.localLibrary.length} tracks cached',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
