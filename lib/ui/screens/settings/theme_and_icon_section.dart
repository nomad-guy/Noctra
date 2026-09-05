import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/noctra_localization.dart';
import '../../../services/platform/dynamic_icon_service.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';

class ThemeAndIconSection extends ConsumerWidget {
  final bool isDark;

  const ThemeAndIconSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NoctraLocalization.tr('theme').toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _themeChip(context, ref, 'Noir Black',
                    NoirThemeMode.noirBlack, themeMode),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _themeChip(context, ref, 'Noir White',
                    NoirThemeMode.noirWhite, themeMode),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _themeChip(context, ref, 'Liquid Glass',
                    NoirThemeMode.liquidGlass, themeMode),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'APP ICON',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _iconChip(context, ref, 'Default',
                    NoctraAppIcon.defaultIcon),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _iconChip(context, ref, 'Noir Black',
                    NoctraAppIcon.noirBlack),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _iconChip(context, ref, 'Noir White',
                    NoctraAppIcon.noirWhite),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _iconChip(context, ref, 'Liquid Glass',
                    NoctraAppIcon.liquidGlass),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Theme and icon are independent. You can mix any theme with any icon.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _themeChip(BuildContext context, WidgetRef ref, String title,
      NoirThemeMode mode, NoirThemeMode current) {
    final isSelected = current == mode;
    final tokens = context.noctraTokens;

    return GestureDetector(
      onTap: () {
        ref.read(themeModeProvider.notifier).state = mode;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? tokens.canvas : tokens.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _iconChip(BuildContext context, WidgetRef ref, String title,
      NoctraAppIcon icon) {
    final currentIcon = ref.watch(appIconProvider);
    final isSelected = currentIcon == icon;
    final tokens = context.noctraTokens;

    return GestureDetector(
      onTap: () => _confirmAndSetIcon(context, ref, icon, title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? tokens.canvas : tokens.secondaryText,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSetIcon(BuildContext context, WidgetRef ref,
      NoctraAppIcon icon, String title) async {
    final currentIcon = ref.read(appIconProvider);
    if (currentIcon == icon) return;

    final tokens = context.noctraTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.subtleBorder),
        ),
        title: Text(
          'Change App Icon',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.primaryText,
          ),
        ),
        content: Text(
          'Changing the app icon to "$title" will close the app due to Android system requirements. You will need to reopen Noctra to continue.\n\nDo you want to apply this change?',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: tokens.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'No',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              foregroundColor: tokens.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Apply',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldApply == true) {
      await DynamicIconService.setIcon(icon);
      ref.read(appIconProvider.notifier).state =
          DynamicIconService.currentIcon;
    }
  }
}
