import 'package:flutter/material.dart';

/// A soft, animated replacement for [IndexedStack].
///
/// Crossfades between the active and previous child using an ease-out
/// curve and gentle vertical displacement while preserving the state,
/// scroll positions, and controllers of all tabs via [Visibility].
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _prevIndex = oldWidget.index;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final isAnimating = _controller.isAnimating;

        return Stack(
          fit: StackFit.expand,
          children: List<Widget>.generate(widget.children.length, (i) {
            final isCurrent = i == widget.index;
            final isPrevious = i == _prevIndex && isAnimating;

            if (isCurrent) {
              final opacity = isAnimating ? progress.clamp(0.0, 1.0) : 1.0;
              final offsetY = isAnimating ? (1.0 - progress) * 6.0 : 0.0;
              return Visibility(
                visible: true,
                maintainState: true,
                child: TickerMode(
                  enabled: true,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, offsetY),
                      child: widget.children[i],
                    ),
                  ),
                ),
              );
            }

            if (isPrevious) {
              final opacity = (1.0 - progress).clamp(0.0, 1.0);
              final offsetY = -progress * 6.0;
              return Visibility(
                visible: true,
                maintainState: true,
                child: TickerMode(
                  enabled: false,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, offsetY),
                      child: widget.children[i],
                    ),
                  ),
                ),
              );
            }

            return Visibility(
              visible: false,
              maintainState: true,
              child: TickerMode(
                enabled: false,
                child: widget.children[i],
              ),
            );
          }),
        );
      },
    );
  }
}
