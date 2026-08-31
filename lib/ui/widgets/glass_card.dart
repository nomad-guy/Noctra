import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';

class GlassCard extends ConsumerWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isHighlighted;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final isAmoled = themeMode.isAmoled;

    Widget content = Container(
      decoration: BoxDecoration(
        color: isDark
            ? (isAmoled
                ? (isHighlighted ? const Color(0xFF141414) : const Color(0xFF080808))
                : (isHighlighted ? const Color(0xFF1C1C1E) : const Color(0xFF141416)))
            : (isHighlighted ? const Color(0xFFEBEBEF) : const Color(0xFFF4F4F6)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? (isHighlighted ? Colors.white38 : (isAmoled ? Colors.white12 : Colors.white10))
              : (isHighlighted ? Colors.black38 : Colors.black12),
          width: isHighlighted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            Colors.transparent,
                            Colors.white.withValues(alpha: isHighlighted ? 0.35 : 0.15),
                            Colors.transparent,
                          ]
                        : [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }
    return content;
  }
}
