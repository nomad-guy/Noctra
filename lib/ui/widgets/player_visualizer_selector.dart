import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/player_sheet.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';

class PlayerVisualizerSelector extends ConsumerWidget {
  final bool isDark;
  final PlayerDisplayMode currentMode;

  const PlayerVisualizerSelector({
    super.key,
    required this.isDark,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pillButton(
            context: context,
            label: context.tr(L10nKeys.artwork),
            icon: Icons.album_rounded,
            isActive: currentMode == PlayerDisplayMode.artwork,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.artwork,
          ),
          const SizedBox(width: 6),
          _pillButton(
            context: context,
            label: context.tr(L10nKeys.spectrum),
            icon: Icons.bar_chart_rounded,
            isActive: currentMode == PlayerDisplayMode.spectrumBars,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.spectrumBars,
          ),
          const SizedBox(width: 6),
          _pillButton(
            context: context,
            label: context.tr(L10nKeys.circle),
            icon: Icons.circle_outlined,
            isActive: currentMode == PlayerDisplayMode.radialCircle,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.radialCircle,
          ),
          const SizedBox(width: 6),
          _pillButton(
            context: context,
            label: context.tr(L10nKeys.synthwave),
            icon: Icons.grid_goldenratio_rounded,
            isActive: currentMode == PlayerDisplayMode.synthwaveGrid,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.synthwaveGrid,
          ),
          const SizedBox(width: 6),
          _pillButton(
            context: context,
            label: context.tr(L10nKeys.lyrics),
            icon: Icons.lyrics_rounded,
            isActive: currentMode == PlayerDisplayMode.lyrics,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.lyrics,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final tokens = context.noctraTokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? tokens.accent : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? tokens.accent : tokens.subtleBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? tokens.canvas : tokens.secondaryText,
            ),
            const SizedBox(width: 4.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? tokens.canvas : tokens.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
