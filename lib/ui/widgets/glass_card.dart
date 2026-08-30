import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';

class GlassCard extends ConsumerStatefulWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends ConsumerState<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == NoirThemeMode.noirBlack;
    final activeHighlight = widget.isHighlighted || _isHovered;

    Widget content = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isDark
              ? (activeHighlight ? const Color(0xFF1C1C1E) : const Color(0xFF141416))
              : (activeHighlight ? const Color(0xFFEBEBEF) : const Color(0xFFF4F4F6)),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: isDark
                ? (activeHighlight ? Colors.white38 : Colors.white10)
                : (activeHighlight ? Colors.black38 : Colors.black12),
            width: activeHighlight ? 1.2 : 1.0,
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
          borderRadius: BorderRadius.circular(widget.radius),
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
                              Colors.white.withValues(alpha: activeHighlight ? 0.35 : 0.15),
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
                padding: widget.padding ?? const EdgeInsets.all(16),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }
    return content;
  }
}
