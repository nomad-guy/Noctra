import 'dart:ui';
import 'package:flutter/material.dart';

class AmbientGlowArt extends StatefulWidget {
  final String? imageUrl;
  final bool isPlaying;
  final bool isDark;
  final double size;
  final double radius;

  const AmbientGlowArt({
    super.key,
    required this.imageUrl,
    required this.isPlaying,
    required this.isDark,
    this.size = 220,
    this.radius = 24,
  });

  @override
  State<AmbientGlowArt> createState() => _AmbientGlowArtState();
}

class _AmbientGlowArtState extends State<AmbientGlowArt> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowScale;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _glowScale = Tween<double>(begin: 0.96, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );

    _glowOpacity = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );

    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AmbientGlowArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animController.repeat(reverse: true);
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSize = widget.size;

    return Center(
      child: SizedBox(
        width: effectiveSize,
        height: effectiveSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Dynamic Ambient Backlight Luminescence Aura
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isPlaying ? _glowScale.value : 1.0,
                  child: Container(
                    width: effectiveSize * 0.95,
                    height: effectiveSize * 0.95,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius * 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: widget.isPlaying ? _glowOpacity.value * 0.22 : 0.08)
                              : Colors.black.withValues(alpha: widget.isPlaying ? _glowOpacity.value * 0.18 : 0.06),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Blurred Backdrop Artwork for Rich Chromatic Radiance
            if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius * 1.2),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Opacity(
                      opacity: widget.isDark ? 0.35 : 0.25,
                      child: Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),

            // Sharp Foreground Artwork with Liquid Frosted Border
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: Container(
                width: effectiveSize,
                height: effectiveSize,
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB),
                  border: Border.all(
                    color: widget.isDark ? Colors.white24 : Colors.black12,
                    width: 1.2,
                  ),
                ),
                child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                    ? Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: effectiveSize * 0.35,
                            color: widget.isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: effectiveSize * 0.4,
                          color: widget.isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
