import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/playback_fx_provider.dart';

class PlaybackSpeedSheet extends ConsumerWidget {
  const PlaybackSpeedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSpeed = ref.watch(playbackSpeedStateProvider);
    final accent = context.noctraTokens.accent;

    return RepaintBoundary(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF2000000) : const Color(0xF2FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLAYBACK SPEED & FX',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Acoustic Tempo & Resampling',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Active Speed Readout
                Center(
                  child: Column(
                    children: [
                      Text(
                        '${currentSpeed.toStringAsFixed(2)}x',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSpeedLabel(currentSpeed),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: kPlaybackSpeedPresets.map((preset) {
                      final isSelected =
                          (currentSpeed - preset.speed).abs() < 0.02;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${preset.label} (${preset.speed}x)'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setAppPlaybackSpeed(ref, preset.speed);
                            }
                          },
                          backgroundColor: isDark
                              ? const Color(0xFF141414)
                              : const Color(0xFFEBEBEB),
                          selectedColor: accent.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? accent
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? accent
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Slider
                Row(
                  children: [
                    Text('0.5x',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54)),
                    Expanded(
                      child: Slider(
                        value: currentSpeed.clamp(0.5, 2.0),
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        activeColor: accent,
                        inactiveColor: isDark ? Colors.white12 : Colors.black12,
                        onChanged: (val) {
                          setAppPlaybackSpeed(ref, val);
                        },
                      ),
                    ),
                    Text('2.0x',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
                const SizedBox(height: 16),

                // Reset Button
                if ((currentSpeed - 1.0).abs() > 0.02)
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Reset to Normal (1.0x)'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () => setAppPlaybackSpeed(ref, 1.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _getSpeedLabel(double speed) {
    if ((speed - 0.85).abs() < 0.02) return 'Slowed + Reverb Vibe';
    if ((speed - 0.90).abs() < 0.02) return 'Chill Ambient Flow';
    if ((speed - 1.0).abs() < 0.02) return 'Standard Studio Speed';
    if ((speed - 1.25).abs() < 0.02) return 'Nightcore Fast Tempo';
    if ((speed - 1.50).abs() < 0.02) return 'Rapid 1.5x Playback';
    if (speed < 1.0) return 'Slowed Resampling';
    return 'Accelerated Playback';
  }
}
