import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/noir_theme.dart';
import '../../../providers/app_providers.dart';
import '../glass_shard_icon.dart';

/// The home app-bar theme cycle button.
///
/// Tap cycles Noir Black → Noir White → Liquid Glass → Material U.
/// On desktop the active theme name is shown beside the icon.
class ThemeCycleButton extends ConsumerWidget {
  final NoirThemeMode themeMode;
  final bool isDesktop;

  static const List<NoirThemeMode> _themeCycle = [
    NoirThemeMode.noirBlack,
    NoirThemeMode.noirWhite,
    NoirThemeMode.liquidGlass,
    NoirThemeMode.materialU,
  ];

  const ThemeCycleButton({
    super.key,
    required this.themeMode,
    required this.isDesktop,
  });

  void _cycle(WidgetRef ref) {
    final idx = _themeCycle.indexOf(themeMode);
    ref.read(themeModeProvider.notifier).state =
        _themeCycle[(idx + 1) % _themeCycle.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.noctraTokens;

    final themeName = switch (themeMode) {
      NoirThemeMode.liquidGlass => 'Liquid Glass',
      NoirThemeMode.noirWhite => 'Noir White',
      NoirThemeMode.materialU => 'Material U',
      NoirThemeMode.noirBlack => 'Noir Black',
    };

    final icon = switch (themeMode) {
      NoirThemeMode.liquidGlass =>
        GlassShardIcon(size: 16, color: t.accent, isActive: true) as Widget,
      NoirThemeMode.materialU => Icon(Icons.palette_outlined,
          size: 16, color: t.secondaryText),
      _ => Icon(
          themeMode.isWhite
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          size: 16,
          color: t.secondaryText),
    };

    if (isDesktop) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _cycle(ref);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: themeMode.isDark
                ? const Color(0x14FFFFFF)
                : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.subtleBorder),
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
                  color: themeMode.isDark
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
        _cycle(ref);
      },
      child: Container(
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        child: icon,
      ),
    );
  }
}
