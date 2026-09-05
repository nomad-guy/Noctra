import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';

class SidebarThemeCard extends ConsumerWidget {
  final NoctraThemeTokens tokens;

  const SidebarThemeCard({super.key, required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () {
          final next = switch (themeMode) {
            NoirThemeMode.noirBlack => NoirThemeMode.noirWhite,
            NoirThemeMode.noirWhite => NoirThemeMode.liquidGlass,
            NoirThemeMode.liquidGlass => NoirThemeMode.noirBlack,
          };
          ref.read(themeModeProvider.notifier).state = next;
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          radius: 14,
          child: Row(
            children: [
              Icon(
                themeMode.isDark
                    ? Icons.nightlight_round
                    : Icons.light_mode_rounded,
                size: 18,
                color: tokens.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THEME',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: tokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      switch (themeMode) {
                        NoirThemeMode.noirBlack => 'Noir Black',
                        NoirThemeMode.noirWhite => 'Noir White',
                        NoirThemeMode.liquidGlass => 'Liquid Glass',
                      },
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: tokens.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
