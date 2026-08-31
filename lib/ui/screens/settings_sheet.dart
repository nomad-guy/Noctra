import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../widgets/glass_card.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lyricsPref = ref.watch(lyricsPreferenceProvider);
    final autoplayDelay = ref.watch(autoplayDelayProvider);
    final audioFade = ref.watch(audioFadeTransitionProvider);
    final isDark = themeMode.isDark;
    final audioPlayer = ref.read(audioPlayerServiceProvider);
    final sleepRemaining = audioPlayer.sleepTimerRemainingMinutes;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? (themeMode == NoirThemeMode.noirAmoled ? Colors.black : const Color(0xFF0D0D0D)) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Preferences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                  IconButton(icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 18),

              // Theme Selector
              Text('INTERFACE THEME & APP ICON', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _themeChip(context, ref, 'Noir Black', NoirThemeMode.noirBlack, themeMode, isDark),
                    const SizedBox(width: 8),
                    _themeChip(context, ref, 'AMOLED', NoirThemeMode.noirAmoled, themeMode, isDark),
                    const SizedBox(width: 8),
                    _themeChip(context, ref, 'Noir White', NoirThemeMode.noirWhite, themeMode, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Sleep Timer
              Text('SLEEP TIMER & AUTO FADE-OUT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fade-Out Timer', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                        Text(sleepRemaining != null ? '$sleepRemaining min remaining' : 'Inactive', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: sleepRemaining != null ? Colors.cyanAccent : (isDark ? Colors.white54 : Colors.black54))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [0, 15, 30, 45, 60].map((m) {
                        final isSel = (m == 0 && sleepRemaining == null) || (m > 0 && sleepRemaining != null && sleepRemaining <= m && sleepRemaining > m - 15);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () { audioPlayer.setSleepTimer(m); (context as Element).markNeedsBuild(); },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white10 : Colors.black12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(m == 0 ? 'Off' : '${m}m', style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Playback Behaviors
              Text('PLAYBACK & TRANSITIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Autoplay Transition Delay', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 2),
                            Text('$autoplayDelay seconds between tracks', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                          ],
                        ),
                        DropdownButton<int>(
                          value: autoplayDelay,
                          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                          underline: const SizedBox.shrink(),
                          items: const [DropdownMenuItem(value: 0, child: Text('0s (Instant)')), DropdownMenuItem(value: 3, child: Text('3s (Default)')), DropdownMenuItem(value: 5, child: Text('5s (Relaxed)'))],
                          onChanged: (v) { if (v != null) { ref.read(autoplayDelayProvider.notifier).state = v; audioPlayer.setAutoplayDelay(v); } },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Studio Fade In / Out', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 2),
                            Text('Smooth volume transitions on play/pause', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                          ],
                        ),
                        Switch(
                          value: audioFade,
                          activeThumbColor: isDark ? Colors.white : Colors.black,
                          onChanged: (v) { ref.read(audioFadeTransitionProvider.notifier).state = v; audioPlayer.toggleFade(v); },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Lyrics Preference
              Text('LYRICS LANGUAGE & PROVIDER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    _lyricsRadio('English / Global (Standard)', lyricsPref, ref, isDark),
                    const Divider(height: 1),
                    _lyricsRadio('Original Master Track', lyricsPref, ref, isDark),
                    const Divider(height: 1),
                    _lyricsRadio('Romanized Phonetics', lyricsPref, ref, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Download Storage Location Tile
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder_special_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                            const SizedBox(width: 10),
                            Text('Download Storage Location', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(8)),
                          child: Text('320k FLAC/AAC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('/storage/emulated/0/Music/Noctra (Lossless)', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Developer Panel Link
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const DeveloperPanelSheet());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.terminal_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 10),
                          Text('Developer Console & Telemetry', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
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

  Widget _themeChip(BuildContext context, WidgetRef ref, String title, NoirThemeMode mode, NoirThemeMode current, bool isDark) {
    final isSelected = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(themeModeProvider.notifier).state = mode;
          NoctraLocalDatabase().saveThemeMode(mode == NoirThemeMode.noirWhite ? 'noirWhite' : (mode == NoirThemeMode.noirAmoled ? 'noirAmoled' : 'noirBlack'));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lyricsRadio(String value, String current, WidgetRef ref, bool isDark) {
    final isSelected = value == current;
    return InkWell(
      onTap: () => ref.read(lyricsPreferenceProvider.notifier).state = value,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isDark ? Colors.white : Colors.black)),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    );
  }
}
