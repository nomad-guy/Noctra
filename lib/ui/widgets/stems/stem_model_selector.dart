import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../services/audio/audio_stem_separation_service.dart';
import '../../../shared/widgets/glass_card.dart';

class StemModelSelector extends StatelessWidget {
  final StemSeparationModel selectedModel;
  final ValueChanged<StemSeparationModel> onModelSelected;

  const StemModelSelector({
    super.key,
    required this.selectedModel,
    required this.onModelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEPARATION MODEL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: tokens.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: StemSeparationModel.values.map((model) {
                final isSelected = selectedModel == model;
                final labels = {
                  StemSeparationModel.light: ('Light', '~30s'),
                  StemSeparationModel.hq: ('HQ', '~2min'),
                  StemSeparationModel.karaoke: ('Karaoke', '~30s'),
                };
                final (label, time) = labels[model]!;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onModelSelected(model),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tokens.accent
                            : tokens.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? tokens.accent
                              : tokens.subtleBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? tokens.canvas
                                  : tokens.primaryText,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? tokens.canvas.withValues(alpha: 0.7)
                                  : tokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
