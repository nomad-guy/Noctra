import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_localization.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../../shared/widgets/glass_card.dart';
import 'settings/app_language_section.dart';
import 'settings/music_preferences_section.dart';
import 'settings/download_storage_section.dart';
import 'settings/lyrics_and_neural_section.dart';
import 'settings/playback_and_audio_section.dart';
import 'settings/theme_and_icon_section.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;
    final q = _query.toLowerCase().trim();

    final showTheme = q.isEmpty || 'theme dark white liquid glass noir icon style'.contains(q) || q.contains('theme');
    final showLang = q.isEmpty || 'language translation english hindi app'.contains(q) || q.contains('lang');
    final showMusicPref = q.isEmpty || 'music preferences history clear genre recommendations'.contains(q) || q.contains('pref');
    final showStorage = q.isEmpty || 'download storage folder sd card location path offline'.contains(q) || q.contains('download') || q.contains('storage');
    final showPlayback = q.isEmpty || 'playback audio sleep timer fade crossfade quality codec data saver flac stream equalizer dsp harman iem buffer'.contains(q) || q.contains('audio') || q.contains('quality') || q.contains('data saver');
    final showLyrics = q.isEmpty || 'lyrics akshara neural profile taste ai recommendation archetype transliteration karaoke'.contains(q) || q.contains('lyric') || q.contains('neural');
    final showDev = q.isEmpty || 'developer debug logs panel developer console'.contains(q) || q.contains('dev');

    final hasAnyMatch = showTheme || showLang || showMusicPref || showStorage || showPlayback || showLyrics || showDev;

    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 680 : double.infinity,
        ),
        child: Container(
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
              const SizedBox(height: 12),
              // Settings Instant Search Bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _query = val),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search settings (e.g. Data Saver, FLAC, Audio)...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (showTheme) ...[
                ThemeAndIconSection(isDark: isDark),
                const SizedBox(height: 18),
              ],
              if (showLang) ...[
                AppLanguageSection(isDark: isDark),
                const SizedBox(height: 18),
              ],
              if (showMusicPref) ...[
                MusicPreferencesSection(isDark: isDark),
                const SizedBox(height: 18),
              ],
              if (showStorage) ...[
                DownloadStorageSection(isDark: isDark),
                const SizedBox(height: 18),
              ],
              if (showPlayback) ...[
                PlaybackAndAudioSection(isDark: isDark),
                const SizedBox(height: 18),
              ],
              if (showLyrics) ...[
                LyricsAndNeuralSection(isDark: isDark),
                const SizedBox(height: 18),
              ],
              if (!hasAnyMatch) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No settings matching "$_query"',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
              if (showDev) ...[
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
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}
