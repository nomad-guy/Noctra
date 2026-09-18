import 'package:flutter/material.dart';

/// Static design-token vocabulary: spacing, radius, typography weights, and
/// motion. Colors live in [NoctraThemeTokens] (they must lerp across theme
/// changes); everything here is theme-independent by definition.
///
/// Usage — instead of one-off paddings and magic durations:
/// ```dart
/// Padding(padding: EdgeInsets.all(NoctraSpacing.md))          // 16
/// SizedBox(height: NoctraSpacing.gapSection)                   // 32
/// duration: NoctraMotion.fast, curve: NoctraMotion.easeOut,    // 150ms
/// ```
abstract final class NoctraSpacing {
  /// 4 — icon/text micro-adjustments.
  static const double xs = 4;

  /// 8 — related element gap.
  static const double sm = 8;

  /// 12 — label ↔ content.
  static const double md = 12;

  /// 16 — card interior padding, list item gap.
  static const double lg = 16;

  /// 20 — section header ↔ content.
  static const double xl = 20;

  /// 32 — between distinct sections.
  static const double gapSection = 32;

  /// 48 — screen-edge padding for hero areas.
  static const double gapScreen = 48;

  /// Bottom inset clearing the floating mini player.
  static const double miniPlayerClearance = 160;

  /// Minimum interactive target (accessibility).
  static const double minTouchTarget = 48;
}

abstract final class NoctraRadius {
  /// 8 — chips, tiny tiles.
  static const double sm = 8;

  /// 12 — buttons, inputs.
  static const double md = 12;

  /// 16 — cards, sheets' inner surfaces.
  static const double lg = 16;

  /// 22 — hero cards, large sheets.
  static const double xl = 22;

  /// 999 — pills/avatars.
  static const double pill = 999;
}

abstract final class NoctraMotion {
  /// 120ms — switches, chips, small fades.
  static const Duration instant = Duration(milliseconds: 120);

  /// 180ms — hover, selection, ink.
  static const Duration fast = Duration(milliseconds: 180);

  /// 280ms — sheets, dialogs, cards.
  static const Duration normal = Duration(milliseconds: 280);

  /// 420ms — screen transitions, hero moves.
  static const Duration slow = Duration(milliseconds: 420);

  /// Signature ease-out: decelerating, confident, never bouncy.
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);

  /// Symmetric twin of [easeOut] for exit animations.
  static const Curve easeIn = Cubic(0.7, 0, 0.84, 0);

  /// Standard emphasized easing for layout shifts.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

abstract final class NoctraTypography {
  /// Section eyebrow labels ("MUSIC TASTE", "HOME LAYOUT").
  static const TextStyle eyebrow = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Song titles, list primary lines.
  static const TextStyle titleSm = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// Meta lines: artist, duration, subtitle.
  static const TextStyle meta = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
}

/// Applies a color to a token text style: `t.primaryText.titleSm` reads
/// naturally and keeps text styling centralized.
extension NoctraTextStyleColor on Color {
  TextStyle get eyebrow => NoctraTypography.eyebrow.copyWith(color: this);
  TextStyle get titleSm => NoctraTypography.titleSm.copyWith(color: this);
  TextStyle get meta => NoctraTypography.meta.copyWith(color: this);
}
