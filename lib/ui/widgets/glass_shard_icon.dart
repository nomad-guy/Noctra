import 'package:flutter/material.dart';

/// The Liquid Glass shard identity mark, used as the theme toggle icon.
/// Smooths the pixel-art reference and adds an aurora glow when active.
class GlassShardIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool isActive;

  const GlassShardIcon({
    super.key,
    this.size = 20,
    this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final shard = SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/images/liquid_glass_shard.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        color: color,
        colorBlendMode: color != null ? BlendMode.srcIn : null,
      ),
    );

    if (!isActive) return shard;

    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8ED0FF).withValues(alpha: 0.35),
            blurRadius: size * 0.5,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: shard,
    );
  }
}
