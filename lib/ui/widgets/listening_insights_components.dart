import 'package:flutter/material.dart';
import '../../shared/widgets/glass_card.dart';
import '../../core/theme/noir_theme.dart';

Widget insightsSectionTitle(BuildContext context, String title, bool isDark) {
  final t = context.noctraTokens;
  return Text(
    title,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: t.tertiaryText,
    ),
  );
}

Widget insightsMetricCard(BuildContext context, String label, String value, bool isDark) {
  final t = context.noctraTokens;
  return Expanded(
    child: GlassCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: t.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: t.primaryText,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget insightsEmptyState(BuildContext context, String text, bool isDark) {
  final t = context.noctraTokens;
  return GlassCard(
    radius: 14,
    padding: const EdgeInsets.all(16),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: t.tertiaryText,
        ),
      ),
    ),
  );
}
