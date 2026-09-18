import 'package:flutter/material.dart';

import '../../core/theme/noir_theme.dart';

/// Shared state widgets: skeleton loaders, empty states, and error states.
///
/// Every screen should render one of these instead of ad-hoc spinners,
/// blank gaps, or raw exception text. They are theme-token driven, so they
/// look correct in all three themes with zero per-screen configuration.

/// Shimmering placeholder block. Composes into full-screen or row-sized
/// skeletons via [NoctraSkeletonList] / [NoctraSkeletonTile].
class NoctraSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const NoctraSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 6,
  });

  @override
  State<NoctraSkeleton> createState() => _NoctraSkeletonState();
}

class _NoctraSkeletonState extends State<NoctraSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Battery guardrail: when this skeleton is covered (e.g. the player
    // sheet opens over a loading list), stop the repeat so no frames are
    // ticked for invisible pixels. Visibility resumes automatically.
    final visible = TickerMode.getValuesNotifier(context).value.enabled;
    if (visible && !_c.isAnimating) {
      _c.repeat();
    } else if (!visible && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final phase = (_c.value * 2) % 1;
            return CustomPaint(
              painter: _ShimmerPainter(
                base: t.surfaceVariant,
                highlight: t.primaryText.withValues(alpha: 0.08),
                phase: phase,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final Color base;
  final Color highlight;
  final double phase;

  _ShimmerPainter({
    required this.base,
    required this.highlight,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final x = (phase * 2 - 0.5) * size.width;
    final rect = Rect.fromLTWH(x, 0, size.width * 0.5, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [highlight.withValues(alpha: 0), highlight, highlight.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.phase != phase;
}

/// Vertical list of song-row-shaped skeletons — the loading state for any
/// track/artist/album list.
class NoctraSkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const NoctraSkeletonList({super.key, this.count = 6, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            const NoctraSkeletonTile(),
            SizedBox(height: i == count - 1 ? 0 : NoctraSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// One song-row-shaped skeleton: square art + two text lines.
class NoctraSkeletonTile extends StatelessWidget {
  const NoctraSkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const NoctraSkeleton(width: 48, height: 48, radius: 8),
        const SizedBox(width: NoctraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              NoctraSkeleton(width: 180, height: 12),
              SizedBox(height: NoctraSpacing.sm),
              NoctraSkeleton(width: 120, height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

/// Designed empty state: icon, message, optional action. Replaces blank
/// gaps and bare "No results" text.
class NoctraEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const NoctraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoctraSpacing.gapSection),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: t.tertiaryText),
            const SizedBox(height: NoctraSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.primaryText.titleSm,
            ),
            if (message != null) ...[
              const SizedBox(height: NoctraSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: t.secondaryText.meta,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: NoctraSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Designed error state with a retry action. Replaces raw exception text
/// and dead-end blank screens.
class NoctraErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isOffline;

  const NoctraErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    return NoctraEmptyState(
      icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: isOffline ? 'You are offline' : 'Something went wrong',
      message: message,
      action: onRetry == null
          ? null
          : TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: t.accent),
            ),
    );
  }
}
