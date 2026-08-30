import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../screens/jam_studio_sheet.dart';
import 'live_audio_wave.dart';

class JamFloatingPill extends ConsumerWidget {
  const JamFloatingPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(p2pSyncServiceProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;

    if (!syncService.isJamActive) return const SizedBox.shrink();

    return Center(
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const JamStudioSheet(),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE6181818) : const Color(0xE6E8E8E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black26,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'JAM: ${syncService.roomCode} • ${syncService.connectedPeersCount} Listening',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              LiveAudioWave(
                isPlaying: true,
                color: isDark ? Colors.white : Colors.black,
                height: 10,
                barCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
