import 'package:flutter/material.dart';
import '../../core/theme/noir_theme.dart';
import '../../shared/widgets/glass_card.dart';


class AIArchetypeCard extends StatelessWidget {
  final bool isDark;
  final String archetype;
  final List<Map<String, dynamic>> dominantAxes;

  const AIArchetypeCard({
    super.key,
    required this.isDark,
    required this.archetype,
    required this.dominantAxes,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      isHighlighted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white : Colors.black,
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  size: 22,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Musical Persona',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      archetype,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Dominant Acoustic Dimensions (16-Axis Model):',
            style: TextStyle(fontSize: 11.5, color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: dominantAxes.take(4).map((axis) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Text(
                  '${axis['name']} • ${axis['percentage']}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
