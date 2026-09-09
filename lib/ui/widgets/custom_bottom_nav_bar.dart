import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../providers/app_providers.dart';

class CustomBottomNavBar extends ConsumerWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;

    final navContent = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 58,
      decoration: BoxDecoration(
        color: themeMode.isLiquidGlass
            ? null
            : (isDark ? const Color(0xF2080808) : const Color(0xF2FFFFFF)),
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
              NoctraLocalization.tr('home'), currentIndex == 0, isDark),
          _navItem(context, ref, 1, Icons.search_rounded, Icons.search_rounded,
              NoctraLocalization.tr('search'), currentIndex == 1, isDark),
          _navItem(
              context,
              ref,
              2,
              Icons.library_music_rounded,
              Icons.library_music_outlined,
              NoctraLocalization.tr('library'),
              currentIndex == 2,
              isDark),
          _navItem(
              context,
              ref,
              3,
              Icons.auto_awesome_rounded,
              Icons.auto_awesome_outlined,
              NoctraLocalization.tr('ai_studio'),
              currentIndex == 3,
              isDark),
        ],
      ),
    );

    return RepaintBoundary(
      child: themeMode.isLiquidGlass
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: navContent,
              ),
            )
          : navContent,
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
