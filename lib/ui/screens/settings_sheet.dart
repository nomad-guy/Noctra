import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../widgets/glass_card.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
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
                  Text(NoctraLocalization.tr('settings'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
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

              // Language Selector (i18n)
              Text('APPLICATION LANGUAGE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Language / भाषा', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                    DropdownButton<String>(
                      value: ref.watch(appLanguageProvider),
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      underline: const SizedBox.shrink(),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                        DropdownMenuItem(value: 'ur', child: Text('اردو (Urdu)')),
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          NoctraLocalization.currentLanguage = val;
                          ref.read(appLanguageProvider.notifier).state = val;
                        }
                      },
                    ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Playback Sleep Timer', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 2),
                        Text(sleepRemaining != null ? 'Active: $sleepRemaining min remaining' : 'Disabled (Continuous playback)', style: TextStyle(fontSize: 11.5, color: sleepRemaining != null ? Colors.amber : (isDark ? Colors.white54 : Colors.black54))),
                      ],
                    ),
                    DropdownButton<int>(
                      value: sleepRemaining ?? 0,
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      underline: const SizedBox.shrink(),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Off')),
                        DropdownMenuItem(value: 15, child: Text('15 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                        DropdownMenuItem(value: 45, child: Text('45 min')),
                        DropdownMenuItem(value: 60, child: Text('60 min')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          if (val == 0) {
                            audioPlayer.cancelSleepTimer();
                          } else {
                            audioPlayer.setSleepTimer(val);
                          }
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Playback Configuration
              Text('PLAYBACK & QUEUE BEHAVIOR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gapless Fade Transitions', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                        Switch(
                          value: audioFade,
                          activeThumbImage: null,
                          onChanged: (v) {
                            ref.read(audioFadeTransitionProvider.notifier).state = v;
                            audioPlayer.toggleFade(v);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Autoplay Delay (Radio)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                        Text('${autoplayDelay}s', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Synced Lyrics Configuration
              Text('SYNCHRONIZED LYRICS ENGINE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    _lyricsRadio('English / Global (Standard)', lyricsPref, ref, isDark),
                    const Divider(height: 4),
                    _lyricsRadio('Romanized Hindi/Punjabi (LRC)', lyricsPref, ref, isDark),
                    const Divider(height: 4),
                    _lyricsRadio('Devanagari Transliteration', lyricsPref, ref, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 18),

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
