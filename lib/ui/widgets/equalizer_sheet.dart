import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // Riverpod 3.x: StateProvider
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';


final eqBandsProvider = StateProvider<List<double>>((ref) => [0.0, 0.0, 0.0, 0.0, 0.0]);
final eqPresetProvider = StateProvider<String>((ref) => 'Harman IEM');
final bassBoostProvider = StateProvider<double>((ref) => 4.0);
final virtualizerProvider = StateProvider<double>((ref) => 2.5);

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

  static const List<String> bandLabels = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];
  static const Map<String, List<double>> presets = {
    'Harman IEM': [4.0, 2.5, 0.0, 3.5, 5.0],
    'Moondrop VDSF': [2.0, 1.0, 0.5, 4.0, 6.5],
    'Tangzu Wan\'er': [5.5, 3.0, -0.5, 2.0, 3.5],
    '7Hz Zero': [1.0, 0.0, 0.0, 3.0, 5.5],
    'Bass Heavy': [8.0, 6.0, 1.0, -2.0, 1.0],
    'Vocal Clarity': [-2.0, 1.0, 6.0, 4.0, 2.0],
    'Flat Monitor': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Synthwave FX': [7.0, 4.0, -2.0, 5.0, 8.0],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final currentBands = ref.watch(eqBandsProvider);
    final currentPreset = ref.watch(eqPresetProvider);
    final bassBoost = ref.watch(bassBoostProvider);
    final virtualizer = ref.watch(virtualizerProvider);
    final audioPlayer = ref.watch(audioPlayerServiceProvider);

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
                      'IEM Tuning & Equalizer FX',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Audiophile IEM Target Curves & 5-Band DSP',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Presets Selector (Audiophile IEM Profiles)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: presets.keys.map((presetName) {
                  final isSelected = currentPreset == presetName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(presetName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          final bands = List<double>.from(presets[presetName]!);
                          ref.read(eqPresetProvider.notifier).state = presetName;
                          ref.read(eqBandsProvider.notifier).state = bands;
                          audioPlayer.applyEqualizer(bands: bands, bassBoost: bassBoost, virtualizer: virtualizer);
                        }
                      },
                      backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB),
                      selectedColor: isDark ? Colors.white : Colors.black,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 5-Band Vertical Slider Grid
            GlassCard(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final gain = currentBands[index];
                  return Column(
                    children: [
                      Text(
                        '${gain > 0 ? "+" : ""}${gain.toInt()}dB',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 130,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: isDark ? Colors.white : Colors.black,
                              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                              thumbColor: isDark ? Colors.white : Colors.black,
                            ),
                            child: Slider(
                              value: gain,
                              min: -12.0,
                              max: 12.0,
                              onChanged: (val) {
                                final updated = List<double>.from(currentBands);
                                updated[index] = val;
                                ref.read(eqBandsProvider.notifier).state = updated;
                                ref.read(eqPresetProvider.notifier).state = 'Custom';
                                audioPlayer.applyEqualizer(bands: updated, bassBoost: bassBoost, virtualizer: virtualizer);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bandLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Bass Boost & 3D Spatializer Knobs
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bass Boost', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                            Text('+${bassBoost.toInt()}dB', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
                          ],
                        ),
                        Slider(
                          value: bassBoost,
                          min: 0.0,
                          max: 12.0,
                          activeColor: isDark ? Colors.white : Colors.black,
                          inactiveColor: isDark ? Colors.white12 : Colors.black12,
                          onChanged: (val) {
                            ref.read(bassBoostProvider.notifier).state = val;
                            audioPlayer.applyEqualizer(bands: currentBands, bassBoost: val, virtualizer: virtualizer);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('3D Virtualizer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                            Text('${(virtualizer * 10).toInt()}%', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
                          ],
                        ),
                        Slider(
                          value: virtualizer,
                          min: 0.0,
                          max: 10.0,
                          activeColor: isDark ? Colors.white : Colors.black,
                          inactiveColor: isDark ? Colors.white12 : Colors.black12,
                          onChanged: (val) {
                            ref.read(virtualizerProvider.notifier).state = val;
                            audioPlayer.applyEqualizer(bands: currentBands, bassBoost: bassBoost, virtualizer: val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    ),);
  }
}
