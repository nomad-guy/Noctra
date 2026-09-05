import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../core/utils/time_of_day_greeting.dart';
import '../live_audio_wave.dart';

/// Spotify-style greeting row with a READY/PLAYING live badge.
/// Extracted from HomeScreen to keep the screen file small.
class HomeGreetingSection extends StatelessWidget {
  final bool isDark;
  final bool isPlaying;

  const HomeGreetingSection({
    super.key,
    required this.isDark,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              timeOfDayGreeting(context),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark
                    ? NoirColors.blackTextPrimary
                    : NoirColors.whiteTextPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                 mainAxisSize: MainAxisSize.min,
                children: [
                  LiveAudioWave(
                      isPlaying: isPlaying,
                      color: isDark ? Colors.white : Colors.black,
                      height: 11,
                      barCount: 3),
                  const SizedBox(width: 5),
                  Text(
                    isPlaying ? context.tr(L10nKeys.playing).toUpperCase() : context.tr(L10nKeys.ready),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
