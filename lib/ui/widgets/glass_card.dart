import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/theme/noir_theme.dart';

class GlassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Container(
      decoration: BoxDecoration(
        color: tokens.glassBlurSigma > 0 ? null : (isHighlighted ? tokens.elevatedSurface : tokens.surfaceVariant),
        gradient: tokens.glassBlurSigma > 0
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.primaryText.withValues(alpha: isHighlighted ? 0.16 : 0.10),
                  (isHighlighted ? tokens.elevatedSurface : tokens.surfaceVariant).withValues(alpha: 0.84),
                  tokens.secondaryAccent.withValues(alpha: isHighlighted ? 0.18 : 0.08),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? (isHighlighted ? tokens.border : tokens.subtleBorder)
              : (isHighlighted ? tokens.border : tokens.subtleBorder),
          width: isHighlighted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? tokens.scrim
                : tokens.scrim.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: tokens.glassBlurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: tokens.glassBlurSigma, sigmaY: tokens.glassBlurSigma),
                child: _contentStack(tokens, isDark),
              )
            : _contentStack(tokens, isDark),
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

  Widget _contentStack(NoctraThemeTokens tokens, bool isDark) {
    return Stack(
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
                            tokens.primaryText.withValues(alpha: isHighlighted ? 0.35 : 0.15),
                            Colors.transparent,
                          ]
                        : [
                            Colors.transparent,
                            tokens.primaryText.withValues(alpha: 0.6),
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
    );
  }
}
