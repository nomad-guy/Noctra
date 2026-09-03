import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../providers/app_providers.dart';

enum StudioMasterMode { lossless320, spatial3d, concertReverb }

final studioMasterModeProvider =
    StateProvider<StudioMasterMode>((ref) => StudioMasterMode.lossless320);

class PlayerStudioChips extends ConsumerWidget {
  const PlayerStudioChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterMode = ref.watch(studioMasterModeProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: [
        _masterChip(
          context,
          ref,
          'Master 320k',
          StudioMasterMode.lossless320,
          Icons.album_rounded,
          masterMode,
        ),
        const SizedBox(width: 8),
        _masterChip(
          context,
          ref,
          'Spatial 3D',
          StudioMasterMode.spatial3d,
          Icons.surround_sound_rounded,
          masterMode,
        ),
        const SizedBox(width: 8),
        _masterChip(
          context,
          ref,
          'Concert Reverb',
          StudioMasterMode.concertReverb,
          Icons.stadium_rounded,
          masterMode,
        ),
      ]),
    );
  }

  Widget _masterChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    StudioMasterMode mode,
    IconData icon,
    StudioMasterMode current,
  ) {
    final isSel = current == mode;
    final tokens = context.noctraTokens;

    return InkWell(
      onTap: () async {
        final applied = await ref
            .read(audioPlayerServiceProvider)
            .applyStudioMasterMode(mode.name);
        if (applied) {
          ref.read(studioMasterModeProvider.notifier).state = mode;
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This audio effect is unavailable for the current output.'),
            duration: Duration(seconds: 2),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? tokens.accent : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? tokens.accent : tokens.subtleBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13, color: isSel ? tokens.canvas : tokens.secondaryText),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              color: isSel ? tokens.canvas : tokens.secondaryText,
            ),
          ),
        ]),
      ),
    );
  }
}
