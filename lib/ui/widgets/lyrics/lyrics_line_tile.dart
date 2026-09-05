import 'package:flutter/material.dart';
import '../../../services/lyrics/lyrics_service.dart';

class LyricsLineTile extends StatelessWidget {
  final LyricLine line;
  final int index;
  final bool isActive;
  final bool isPast;
  final bool isDark;
  final GlobalKey lineKey;
  final VoidCallback onTap;

  const LyricsLineTile({
    super.key,
    required this.line,
    required this.index,
    required this.isActive,
    required this.isPast,
    required this.isDark,
    required this.lineKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: lineKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.transparent,
            width: 1,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.4,
            color: isActive
                ? (isDark ? Colors.white : Colors.black)
                : (isDark
                    ? Colors.white.withValues(alpha: isPast ? 0.32 : 0.60)
                    : Colors.black.withValues(alpha: isPast ? 0.26 : 0.50)),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: isActive ? 1.0 : (isPast ? 0.72 : 0.9),
            child: Text(line.text),
          ),
        ),
      ),
    );
  }
}
