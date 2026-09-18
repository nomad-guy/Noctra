import 'package:flutter/material.dart';

import '../../../core/utils/playback_settings_store.dart';
import '../../../shared/widgets/glass_card.dart';
import '../home_screen.dart';
import '../../../core/theme/noir_theme.dart';

/// Settings section: Home Layout — toggle each home-screen section.
/// Hidden sections are never built, cutting both visual clutter and the
/// network requests their providers fire on startup.
class HomeLayoutSection extends StatefulWidget {
  final bool isDark;

  const HomeLayoutSection({super.key, required this.isDark});

  @override
  State<HomeLayoutSection> createState() => _HomeLayoutSectionState();
}

class _HomeLayoutSectionState extends State<HomeLayoutSection> {
  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    final store = PlaybackSettingsStore.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOME LAYOUT',
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              for (final entry in kHomeSectionIds.entries)
                // Material wrapper: GlassCard's DecoratedBox paints on the
                // card ancestor, so a bare ListTile's ink/background would be
                // hidden (asserted in widget tests).
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        store.setHomeSectionVisible(entry.key,
                            !store.isHomeSectionVisible(entry.key));
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    minLeadingWidth: 0,
                    horizontalTitleGap: 12,
                    leading: Icon(
                      store.isHomeSectionVisible(entry.key)
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 18,
                      color: store.isHomeSectionVisible(entry.key)
                          ? (t.primaryText)
                          : (t.tertiaryText),
                    ),
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: store.isHomeSectionVisible(entry.key)
                            ? (t.primaryText)
                            : (t.tertiaryText),
                      ),
                    ),
                    trailing: Switch(
                      value: store.isHomeSectionVisible(entry.key),
                      onChanged: (v) {
                        setState(() {
                          store.setHomeSectionVisible(entry.key, v);
                        });
                      },
                      activeThumbColor: t.primaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
