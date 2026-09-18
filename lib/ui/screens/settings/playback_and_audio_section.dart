import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../widgets/stream_quality_sheet.dart';
import '../../../core/theme/noir_theme.dart';

class PlaybackAndAudioSection extends ConsumerWidget {
  final bool isDark;

  const PlaybackAndAudioSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.noctraTokens;
    final audioPlayer = ref.watch(audioPlayerServiceProvider);
    final sleepTimerAsync = ref.watch(sleepTimerStreamProvider);
    final sleepRemaining =
        sleepTimerAsync.asData?.value ?? audioPlayer.sleepTimerRemainingMinutes;
    final audioFade = ref.watch(audioFadeTransitionProvider);
    final autoplayDelay = ref.watch(autoplayDelayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SLEEP TIMER & AUTO FADE-OUT',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playback Sleep Timer',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sleepRemaining != null
                        ? 'Active: $sleepRemaining min remaining'
                        : 'Disabled (Continuous playback)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: sleepRemaining != null
                          ? Colors.amber
                          : (t.secondaryText),
                    ),
                  ),
                ],
              ),
              DropdownButton<int>(
                value: [0, 15, 30, 45, 60, 90].contains(sleepRemaining)
                    ? sleepRemaining
                    : (sleepRemaining != null
                        ? [0, 15, 30, 45, 60, 90].reduce((a, b) =>
                            (a - sleepRemaining).abs() <
                                    (b - sleepRemaining).abs()
                                ? a
                                : b)
                        : 0),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                  fontSize: 13,
                  color: t.primaryText,
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Off')),
                  DropdownMenuItem(value: 15, child: Text('15 min')),
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 45, child: Text('45 min')),
                  DropdownMenuItem(value: 60, child: Text('60 min')),
                  DropdownMenuItem(value: 90, child: Text('90 min')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    if (val == 0) {
                      audioPlayer.cancelSleepTimer();
                    } else {
                      audioPlayer.setSleepTimer(val);
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'PLAYBACK & QUEUE BEHAVIOR',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gapless Fade Transitions',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.primaryText,
                    ),
                  ),
                  Switch(
                    value: audioFade,
                    activeThumbImage: null,
                    onChanged: (v) {
                      ref
                          .read(audioFadeTransitionProvider.notifier)
                          .state = v;
                      audioPlayer.toggleFade(v);
                    },
                  ),
                ],
              ),
              const Divider(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Autoplay Delay (Radio)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.primaryText,
                    ),
                  ),
                  Text(
                    '${autoplayDelay}s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.primaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'CODEC & STREAM QUALITY',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (c) => const StreamQualitySheet(),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.equalizer_rounded,
                        size: 18,
                        color: t.secondaryText),
                    const SizedBox(width: 10),
                    Text(
                      'Audio Quality & Codec Settings',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: t.primaryText,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right_rounded,
                    color: t.tertiaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
