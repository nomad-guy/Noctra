import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Semantic design tokens shared by every surface in the app. Widgets should
/// read these from Theme.of(context) instead of branching on raw black/white
/// colors. Adding a theme only requires supplying another token set here.
@immutable
class NoctraThemeTokens extends ThemeExtension<NoctraThemeTokens> {
  final Color canvas;
  final Color surface;
  final Color surfaceVariant;
  final Color elevatedSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color border;
  final Color subtleBorder;
  final Color accent;
  final Color secondaryAccent;
  final Color tertiaryAccent;
  final Color scrim;
  final double glassBlurSigma;

  const NoctraThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceVariant,
    required this.elevatedSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.border,
    required this.subtleBorder,
    required this.accent,
    required this.secondaryAccent,
    required this.tertiaryAccent,
    required this.scrim,
    this.glassBlurSigma = 0,
  });

  @override
  NoctraThemeTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceVariant,
    Color? elevatedSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? border,
    Color? subtleBorder,
    Color? accent,
    Color? secondaryAccent,
    Color? tertiaryAccent,
    Color? scrim,
    double? glassBlurSigma,
  }) =>
      NoctraThemeTokens(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        elevatedSurface: elevatedSurface ?? this.elevatedSurface,
        primaryText: primaryText ?? this.primaryText,
        secondaryText: secondaryText ?? this.secondaryText,
        tertiaryText: tertiaryText ?? this.tertiaryText,
        border: border ?? this.border,
        subtleBorder: subtleBorder ?? this.subtleBorder,
        accent: accent ?? this.accent,
        secondaryAccent: secondaryAccent ?? this.secondaryAccent,
        tertiaryAccent: tertiaryAccent ?? this.tertiaryAccent,
        scrim: scrim ?? this.scrim,
        glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      );

  @override
  NoctraThemeTokens lerp(ThemeExtension<NoctraThemeTokens>? other, double t) {
    if (other is! NoctraThemeTokens) return this;
    return NoctraThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      tertiaryAccent: Color.lerp(tertiaryAccent, other.tertiaryAccent, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      glassBlurSigma: lerpDouble(glassBlurSigma, other.glassBlurSigma, t)!,
    );
  }
}

extension NoctraThemeContext on BuildContext {
  NoctraThemeTokens get noctraTokens {
    final theme = Theme.of(this);
    return theme.extension<NoctraThemeTokens>() ??
        NoctraThemeTokens(
          canvas: theme.scaffoldBackgroundColor,
          surface: theme.colorScheme.surface,
          surfaceVariant: theme.colorScheme.surfaceContainerHighest,
          elevatedSurface: theme.colorScheme.surfaceContainerHigh,
          primaryText: theme.colorScheme.onSurface,
          secondaryText: theme.colorScheme.onSurfaceVariant,
          tertiaryText: theme.colorScheme.onSurfaceVariant,
          border: theme.colorScheme.outline,
          subtleBorder: theme.colorScheme.outlineVariant,
          accent: theme.colorScheme.primary,
          secondaryAccent: theme.colorScheme.secondary,
          tertiaryAccent: theme.colorScheme.tertiary,
          scrim: theme.colorScheme.scrim,
        );
  }
}
