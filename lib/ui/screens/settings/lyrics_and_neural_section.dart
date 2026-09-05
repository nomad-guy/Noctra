import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/neural_recommender_engine.dart';
import '../../../data/repositories/taste_vector_engine.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../widgets/neural_mini_chart.dart';

class LyricsAndNeuralSection extends ConsumerWidget {
  final bool isDark;

  const LyricsAndNeuralSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              _lyricsRadio(
                  'English / Global (Standard)', lyricsPref, ref, isDark),
              const Divider(height: 4),
              _lyricsRadio(
                  'Romanized Hindi/Punjabi (LRC)', lyricsPref, ref, isDark),
              const Divider(height: 4),
              _lyricsRadio(
                  'Devanagari Transliteration', lyricsPref, ref, isDark),
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
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _nnStat('Training Steps',
                  '${NeuralRecommenderEngine.totalTrainSteps}', isDark),
              const SizedBox(height: 6),
              _nnStat(
                  'Running Accuracy',
                  '${(NeuralRecommenderEngine.accuracy * 100).toStringAsFixed(1)}%',
                  isDark),
              const SizedBox(height: 6),
              _nnStat(
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
                  color: isDark ? Colors.white38 : Colors.black38,
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
                        color: isDark ? Colors.white60 : Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'Your Profile: ${TasteVectorEngine.calculateArchetype(ref.read(musicRepositoryProvider).userTasteVector)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
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
      String value, String current, WidgetRef ref, bool isDark) {
    final isSelected = value == current;
    return InkWell(
      onTap: () => ref.read(lyricsPreferenceProvider.notifier).state = value,
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
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nnStat(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}
