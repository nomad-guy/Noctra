import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/playback_settings_store.dart';
import '../../../data/repositories/neural_recommender_engine.dart';
import '../../../data/repositories/taste_vector_engine.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../widgets/neural_mini_chart.dart';
import '../../../core/theme/noir_theme.dart';

class LyricsAndNeuralSection extends ConsumerWidget {
  final bool isDark;

  const LyricsAndNeuralSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.noctraTokens;
    final lyricsPref = ref.watch(lyricsPreferenceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYNCHRONIZED LYRICS ENGINE',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              _lyricsRadio(
                  'English / Global (Standard)', lyricsPref, context, ref, isDark),
              const Divider(height: 4),
              _lyricsRadio(
                  'Romanized Hindi/Punjabi (LRC)', lyricsPref, context, ref, isDark),
              const Divider(height: 4),
              _lyricsRadio(
                  'Devanagari Transliteration', lyricsPref, context, ref, isDark),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'NEURAL RECOMMENDATION ENGINE',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _nnStat(context, 'Training Steps',
                  '${NeuralRecommenderEngine.totalTrainSteps}', isDark),
              const SizedBox(height: 6),
              _nnStat(
                  context,
                  'Running Accuracy',
                  '${(NeuralRecommenderEngine.accuracy * 100).toStringAsFixed(1)}%',
                  isDark),
              const SizedBox(height: 6),
              _nnStat(
                  context,
                  'Average Loss',
                  NeuralRecommenderEngine.averageLoss.toStringAsFixed(4),
                  isDark),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: NeuralMiniChart(
                  lossHistory: NeuralRecommenderEngine.lossHistory,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The neural network learns from your listening patterns in real-time. '
                'More training steps = better recommendations.',
                style: TextStyle(
                  fontSize: 11,
                  color: t.tertiaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x0D000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_rounded,
                        size: 14,
                        color: t.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Your Profile: ${TasteVectorEngine.calculateArchetype(ref.read(musicRepositoryProvider).userTasteVector)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lyricsRadio(
      String value, String current, BuildContext context, WidgetRef ref, bool isDark) {
    final t = context.noctraTokens;
    final isSelected = value == current;
    return InkWell(
      onTap: () {
        ref.read(lyricsPreferenceProvider.notifier).state = value;
        PlaybackSettingsStore.instance.save(lyricsPreference: value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: t.primaryText,
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected
                  ? (t.primaryText)
                  : (t.tertiaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nnStat(BuildContext context, String label, String value, bool isDark) {
    final t = context.noctraTokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: t.secondaryText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: t.primaryText,
          ),
        ),
      ],
    );
  }
}
