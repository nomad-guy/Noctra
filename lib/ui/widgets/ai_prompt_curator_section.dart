import 'package:flutter/material.dart';
import '../../core/theme/noir_theme.dart';
import '../../shared/widgets/glass_card.dart';


class AIPromptCuratorSection extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final Function(String) onSubmit;

  const AIPromptCuratorSection({
    super.key,
    required this.isDark,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt Input Card
        GlassCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'Describe your desired sonic vibe',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(
                  color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., something like Nujabes but darker and moody...',
                  hintStyle: TextStyle(
                    color: isDark ? NoirColors.blackTextTertiary : NoirColors.whiteTextTertiary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: onSubmit,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Curate Mix with Agent', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => onSubmit(controller.text),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Quick Tuning Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Quick Tuning Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Quick Action Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _actionChip('Darker Vibe', Icons.nights_stay_outlined, () {
                controller.text = 'darker moody heavy bass';
                onSubmit('darker moody heavy bass');
              }),
              _actionChip('High Energy', Icons.electric_bolt_outlined, () {
                controller.text = 'fast energetic hype tempo';
                onSubmit('fast energetic hype tempo');
              }),
              _actionChip('Calmer Ambient', Icons.spa_outlined, () {
                controller.text = 'calm peaceful ambient relaxation';
                onSubmit('calm peaceful ambient relaxation');
              }),
              _actionChip('Acoustic Strings', Icons.audiotrack_outlined, () {
                controller.text = 'acoustic guitar warm analog';
                onSubmit('acoustic guitar warm analog');
              }),
              _actionChip('Surprise Discovery', Icons.shuffle_rounded, () {
                controller.text = 'cinematic electronic discovery';
                onSubmit('cinematic electronic discovery');
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
