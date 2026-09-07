import 'package:flutter/material.dart';
import '../../shared/widgets/glass_card.dart';

Widget insightsSectionTitle(String title, bool isDark) {
  return Text(
    title,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: isDark ? Colors.white38 : Colors.black38,
    ),
  );
}

Widget insightsMetricCard(String label, String value, bool isDark) {
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
              color: isDark ? Colors.white54 : Colors.black54,
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
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget insightsEmptyState(String text, bool isDark) {
  return GlassCard(
    radius: 14,
    padding: const EdgeInsets.all(16),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    ),
  );
}
