import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../../shared/widgets/glass_card.dart';
import 'settings/app_language_section.dart';
import 'settings/download_storage_section.dart';
import 'settings/lyrics_and_neural_section.dart';
import 'settings/playback_and_audio_section.dart';
import 'settings/theme_and_icon_section.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: themeMode.isLiquidGlass
            ? tokens.surface.withValues(alpha: .90)
            : (isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA)),
        gradient: themeMode.isLiquidGlass
            ? LinearGradient(colors: [
                tokens.surfaceVariant.withValues(alpha: .94),
                tokens.canvas.withValues(alpha: .88)
              ])
            : null,
        border: Border.all(color: tokens.subtleBorder),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    NoctraLocalization.tr('settings'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ThemeAndIconSection(isDark: isDark),
              const SizedBox(height: 18),
              AppLanguageSection(isDark: isDark),
              const SizedBox(height: 18),
              DownloadStorageSection(isDark: isDark),
              const SizedBox(height: 18),
              PlaybackAndAudioSection(isDark: isDark),
              const SizedBox(height: 18),
              LyricsAndNeuralSection(isDark: isDark),
              const SizedBox(height: 18),
              GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (c) => const DeveloperPanelSheet(),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.terminal_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 10),
                          Text(
                            'Developer Console & Telemetry',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
