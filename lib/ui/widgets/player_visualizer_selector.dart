import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/player_sheet.dart';

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
            label: 'Artwork',
            icon: Icons.album_rounded,
            isActive: currentMode == PlayerDisplayMode.artwork,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.artwork,
          ),
          const SizedBox(width: 6),
          _pillButton(
            label: 'Spectrum',
            icon: Icons.bar_chart_rounded,
            isActive: currentMode == PlayerDisplayMode.spectrumBars,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.spectrumBars,
          ),
          const SizedBox(width: 6),
          _pillButton(
            label: 'Circle',
            icon: Icons.circle_outlined,
            isActive: currentMode == PlayerDisplayMode.radialCircle,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.radialCircle,
          ),
          const SizedBox(width: 6),
          _pillButton(
            label: 'Synthwave',
            icon: Icons.grid_goldenratio_rounded,
            isActive: currentMode == PlayerDisplayMode.synthwaveGrid,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.synthwaveGrid,
          ),
          const SizedBox(width: 6),
          _pillButton(
            label: 'Lyrics',
            icon: Icons.lyrics_rounded,
            isActive: currentMode == PlayerDisplayMode.lyrics,
            onTap: () => ref.read(playerDisplayModeProvider.notifier).state = PlayerDisplayMode.lyrics,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF141414) : const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 4.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
