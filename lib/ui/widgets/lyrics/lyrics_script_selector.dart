import 'package:flutter/material.dart';
import '../../../services/lyrics/universal_lyrics_transliteration_engine.dart';

class LyricsScriptSelector extends StatelessWidget {
  final List<ScriptOption> options;
  final String selectedScript;
  final bool isDark;
  final ValueChanged<String> onSelectScript;

  const LyricsScriptSelector({
    super.key,
    required this.options,
    required this.selectedScript,
    required this.isDark,
    required this.onSelectScript,
  });

  @override
  Widget build(BuildContext context) {
    if (options.length <= 1) return const SizedBox.shrink();

    return Positioned(
      top: 10,
      right: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final sel = selectedScript == opt.code;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => onSelectScript(opt.code),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sel
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                          ? const Color(0x33FFFFFF)
                          : const Color(0x1F000000)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sel
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class LyricsSyncFloatingButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const LyricsSyncFloatingButton({
    super.key,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.92)
                  : Colors.black.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.vertical_align_center_rounded,
                  size: 14,
                  color: isDark ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sync with Song',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
