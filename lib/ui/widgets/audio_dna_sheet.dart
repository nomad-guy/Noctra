import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../screens/settings/music_preferences_sheet.dart';
import 'taste_radar_painter.dart';

class AudioDnaSheet extends ConsumerWidget {
  const AudioDnaSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taste = ref.watch(tasteVectorStateProvider);
    final accent = context.noctraTokens.accent;

    // Extract 8 primary visual axes from 32-dim vector
    final double energy = _safeAxis(taste, 2);
    final double ambient = _safeAxis(taste, 1);
    final double acoustic = _safeAxis(taste, 5);
    final double synth = (_safeAxis(taste, 6) + _safeAxis(taste, 9)) / 2;
    final double vocals = _safeAxis(taste, 7);
    final double bollywood = _safeAxis(taste, 19);
    final double lofi = _safeAxis(taste, 18);
    final double focus = _safeAxis(taste, 11);

    final radarAxes = [
      RadarAxisData(label: 'ENERGY', value: energy),
      RadarAxisData(label: 'AMBIENT', value: ambient),
      RadarAxisData(label: 'ACOUSTIC', value: acoustic),
      RadarAxisData(label: 'SYNTH', value: synth),
      RadarAxisData(label: 'VOCALS', value: vocals),
      RadarAxisData(label: 'BOLLYWOOD', value: bollywood),
      RadarAxisData(label: 'LO-FI', value: lofi),
      RadarAxisData(label: 'FOCUS', value: focus),
    ];

    final (archetypeTitle, archetypeDesc) = _deriveArchetype(
      energy: energy,
      synth: synth,
      bollywood: bollywood,
      lofi: lofi,
      acoustic: acoustic,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUDIO DNA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live 32-Axis Acoustic Taste Profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isDark ? Colors.white60 : Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Archetype Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fingerprint_rounded,
                            size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          archetypeTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      archetypeDesc,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Custom Painter Radar Chart
              SizedBox(
                height: 260,
                width: double.infinity,
                child: CustomPaint(
                  painter: TasteRadarPainter(
                    axes: radarAxes,
                    accentColor: accent,
                    gridColor: isDark ? Colors.white12 : Colors.black12,
                    textColor: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Trait Breakdown Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: radarAxes.map((a) {
                  final pct = (a.value * 100).toInt();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${a.label}: $pct%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Tune Preferences Action Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Tune Musical Preferences',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    MusicPreferencesSheet.show(context, ref, isDark);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _safeAxis(List<double> vector, int index) {
    if (index >= vector.length) return 0.5;
    return vector[index].clamp(0.05, 0.95);
  }

  static (String, String) _deriveArchetype({
    required double energy,
    required double synth,
    required double bollywood,
    required double lofi,
    required double acoustic,
  }) {
    if (synth > 0.65) {
      return (
        'CYBER SYNTH ARCHITECT',
        'Dominant analog synthesis, nocturnal tempo, and neon electronic textures.'
      );
    }
    if (bollywood > 0.65) {
      return (
        'CINEMATIC MELOPHILE',
        'Lush orchestral sweeps, emotive vocal harmonies, and rich melody.'
      );
    }
    if (lofi > 0.65) {
      return (
        'LO-FI DEEP THINKER',
        'Intimate tape textures, relaxed BPM, and contemplative ambient warmth.'
      );
    }
    if (energy > 0.65) {
      return (
        'HIGH-OCTANE FLOW',
        'Driving rhythmic velocity, punchy transient percussion, and peak kinetic drive.'
      );
    }
    if (acoustic > 0.65) {
      return (
        'ACOUSTIC SOUL WANDERER',
        'Raw organic instrumentation, intimate acoustics, and folk storytelling.'
      );
    }
    return (
      'ECLECTIC SONIC EXPLORER',
      'A versatile acoustic palate traversing synthwave, ambient depth, and world frequencies.'
    );
  }
}
