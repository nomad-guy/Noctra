import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/audio_output_cast_sheet.dart';
import '../../widgets/equalizer_sheet.dart';
import '../../widgets/playback_speed_sheet.dart';
import '../../widgets/queue_sheet.dart';
import '../../widgets/sleep_timer_sheet.dart';
import '../../widgets/stem_separation_sheet.dart';
import '../../widgets/stream_quality_sheet.dart';
import '../jam_studio_sheet.dart';

class PlayerHeader extends ConsumerWidget {
  final bool isDark;

  const PlayerHeader({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.noctraTokens;
    final audioPlayerService = ref.watch(audioPlayerServiceProvider);
    final foreground = tokens.primaryText;

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      return Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 28, color: foreground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.tr(L10nKeys.nowPlaying),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: tokens.secondaryText,
            ),
          ),
        ),
        _iconBtn(
          Icons.queue_music_rounded,
          foreground,
          context.tr(L10nKeys.queue),
          () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => const QueueSheet(),
          ),
        ),
        _iconBtn(
          audioPlayerService.sleepTimerRemainingMinutes != null
              ? Icons.bedtime_rounded
              : Icons.bedtime_outlined,
          audioPlayerService.sleepTimerRemainingMinutes != null
              ? Colors.cyanAccent
              : foreground,
          context.tr(L10nKeys.sleepTimer),
          () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => const SleepTimerSheet(),
          ),
        ),
        if (compact)
          _playerMoreMenu(context, ref, isDark)
        else ...[
          _iconBtn(
            Icons.speaker_group_rounded,
            foreground,
            context.tr(L10nKeys.audioOutput),
            () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (c) => AudioOutputCastSheet(isDark: isDark),
            ),
          ),
          _iconBtn(
            Icons.podcasts_rounded,
            foreground,
            context.tr(L10nKeys.jamRoom),
            () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (c) => const JamStudioSheet(),
            ),
          ),
          _iconBtn(
            Icons.equalizer_rounded,
            foreground,
            context.tr(L10nKeys.equalizer),
            () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (c) => const EqualizerSheet(),
            ),
          ),
        ],
      ]);
    });
  }

  Widget _iconBtn(
          IconData icon, Color color, String tooltip, VoidCallback onTap) =>
      IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        tooltip: tooltip,
        icon: Icon(icon, size: 19, color: color),
        onPressed: onTap,
      );

  Widget _playerMoreMenu(BuildContext context, WidgetRef ref, bool isDark) {
    final song = ref.watch(currentSongStreamProvider).value;
    return PopupMenuButton<String>(
      tooltip: context.tr(L10nKeys.morePlayerActions),
      icon: Icon(Icons.more_horiz_rounded,
          color: isDark ? Colors.white : Colors.black),
      onSelected: (value) {
        switch (value) {
          case 'output':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AudioOutputCastSheet(isDark: isDark),
            );
          case 'jam':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const JamStudioSheet(),
            );
          case 'equalizer':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const EqualizerSheet(),
            );
          case 'speed':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const PlaybackSpeedSheet(),
            );
          case 'stems':
            if (song != null) {
               showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => StemSeparationSheet(song: song),
              );
            }
          case 'quality':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const StreamQualitySheet(),
            );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'output', child: Text(context.tr(L10nKeys.audioOutput))),
        PopupMenuItem(value: 'jam', child: Text(context.tr(L10nKeys.jamRoom))),
        PopupMenuItem(value: 'speed', child: const Text('Speed & FX (Slowed / Nightcore)')),
        PopupMenuItem(value: 'equalizer', child: Text(context.tr(L10nKeys.equalizer))),
        PopupMenuItem(value: 'quality', child: Text(context.tr(L10nKeys.codecResolution))),
        PopupMenuItem(value: 'stems', child: Text(context.tr(L10nKeys.audioStems))),
      ],
    );
  }
}
