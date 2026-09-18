import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import 'music_preferences_sheet.dart';
import '../../widgets/audio_dna_sheet.dart';
import '../../../core/theme/noir_theme.dart';

/// Settings section displaying active music preferences with an editor action.
class MusicPreferencesSection extends ConsumerWidget {
  final bool isDark;

  const MusicPreferencesSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.noctraTokens;
    final repo = ref.watch(musicRepositoryProvider);
    final langs = repo.onboardedLanguages;
    final genres = repo.onboardedGenres;

    final summary = langs.isNotEmpty
        ? '${langs.take(3).join(', ')}${genres.isNotEmpty ? ' • ${genres.take(3).join(', ')}' : ''}'
        : 'Default Mix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MUSIC TASTE & PREFERENCES',
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Taste Profile',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.tune_rounded,
                    size: 20,
                    color: t.secondaryText),
                tooltip: 'Edit Preferences',
                onPressed: () =>
                    MusicPreferencesSheet.show(context, ref, isDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AudioDnaSheet(),
              );
            },
            child: Row(
              children: [
                Icon(Icons.fingerprint_rounded,
                    size: 22,
                    color: t.secondaryText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio DNA & Taste Radar',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: t.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live 32-axis geometric acoustic visualizer',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: t.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: t.tertiaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
