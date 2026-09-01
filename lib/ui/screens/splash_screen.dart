import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/noctra_app_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final VoidCallback onInitialized;

  const SplashScreen({super.key, required this.onInitialized});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _logoScale;
  late Animation<double> _glowOpacity;

  int _bootStep = 0;
  final List<String> _bootLogs = [
    'Calibrating 32-Axis Neural Graph',
    'Decrypting 320kbps CD Sound Engine',
    'Synthesizing Local P2P Audio Mesh',
    'Tuning Liquid Glass Acoustic Refraction',
    'Neural Architecture Ready'
  ];

  Timer? _bootTimer;

  @override
  void initState() {
    super.initState();
    // Continuous smooth orbital rotation around the logo
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Subtle breathing pulse for the central emblem
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.95, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _glowOpacity = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _runBootSequence();
  }

  void _runBootSequence() {
    _bootTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_bootStep < _bootLogs.length - 1) {
        setState(() {
          _bootStep++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            widget.onInitialized();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;

    final tokens = context.noctraTokens;
    final primaryColor = tokens.primaryText;
    final secondaryColor = tokens.secondaryText;
    final trackColor = tokens.subtleBorder;
    final backgroundColor = tokens.canvas;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background Atmospheric Light Pool
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.06 * _glowOpacity.value),
                              Colors.transparent,
                            ]
                          : [
                              Colors.black.withValues(alpha: 0.04 * _glowOpacity.value),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Central Minimalist Composition
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo & Orbital Circular Spinner Ring
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Orbital Rotating Ring around the Logo
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(136, 136),
                              painter: _OrbitalSpinnerPainter(
                                color: primaryColor,
                                trackColor: trackColor,
                                progress: (_bootStep + 1) / _bootLogs.length,
                              ),
                            ),
                          );
                        },
                      ),

                      // Central Official Noctra App Logo (Inverts with Theme)
                      ScaleTransition(
                        scale: _logoScale,
                        child: NoctraAppLogo(
                          size: 80,
                          radius: 20,
                          isDark: isDark,
                          showGlow: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Brand Name
                Text(
                  'NOCTRA',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 9.0,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'AUTONOMOUS MUSIC INTELLIGENCE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: secondaryColor,
                  ),
                ),

                const SizedBox(height: 24),

                // Discrete Monospace Bootloader Diagnostics (No bottom bar)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Row(
                    key: ValueKey<int>(_bootStep),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _bootLogs[_bootStep],
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white70 : const Color(0xBF000000),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the Smooth Circular Orbital Spinner around the Logo
class _OrbitalSpinnerPainter extends CustomPainter {
  final Color color;
  final Color trackColor;
  final double progress;

  _OrbitalSpinnerPainter({
    required this.color,
    required this.trackColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // 1. Subtle Inactive Background Track Circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Dynamic Luminous Arc Spinning Around the Logo
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    const sweepAngle = math.pi * 0.75;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      sweepAngle,
      false,
      activePaint,
    );

    // 3. Orbital Leading Particle Satellite Dot
    final dotAngle = sweepAngle;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalSpinnerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progress != progress;
  }
}
