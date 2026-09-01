import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/dynamic_icon_service.dart';
import '../../core/utils/noctra_localization.dart';
import '../../data/models/download_location.dart';
import '../../data/repositories/neural_recommender_engine.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/taste_vector_engine.dart';
import '../../data/sources/noctra_local_database.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/neural_mini_chart.dart';
import '../widgets/stream_quality_sheet.dart';

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
    final tokens = context.noctraTokens;
    final audioPlayer = ref.watch(audioPlayerServiceProvider);
    final sleepTimerAsync = ref.watch(sleepTimerStreamProvider);
    final sleepRemaining =
        sleepTimerAsync.asData?.value ?? audioPlayer.sleepTimerRemainingMinutes;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: themeMode.isLiquidGlass
            ? tokens.surface.withValues(alpha: .90)
            : (isDark
                ? (themeMode == NoirThemeMode.noirAmoled
                    ? Colors.black
                    : const Color(0xFF0D0D0D))
                : const Color(0xFFFAFAFA)),
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
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(NoctraLocalization.tr('settings'),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black)),
                  IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 18),

              // Theme Selector — ONLY changes Flutter UI colors
              Text('INTERFACE THEME',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _themeChip(context, ref, 'Noir Black',
                          NoirThemeMode.noirBlack, themeMode, isDark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _themeChip(context, ref, 'AMOLED',
                          NoirThemeMode.noirAmoled, themeMode, isDark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _themeChip(context, ref, 'White',
                          NoirThemeMode.noirWhite, themeMode, isDark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _themeChip(context, ref, 'Liquid Glass',
                          NoirThemeMode.liquidGlass, themeMode, isDark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // App Icon Selector — ONLY changes Android launcher icon
              Text('APP ICON',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _iconChip(context, 'Default',
                          NoctraAppIcon.defaultIcon, isDark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _iconChip(context, 'Noir Black',
                          NoctraAppIcon.noirBlack, isDark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _iconChip(context, 'Noir White',
                          NoctraAppIcon.noirWhite, isDark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _iconChip(context, 'Liquid Glass',
                          NoctraAppIcon.liquidGlass, isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Theme and icon are independent. You can mix any theme with any icon.',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      height: 1.4),
                ),
              ),

              const SizedBox(height: 18),

              // Language Selector (i18n)
              Text('APPLICATION LANGUAGE',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Language / भाषा',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black)),
                    DropdownButton<String>(
                      value: ref.watch(appLanguageProvider),
                      dropdownColor:
                          isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      underline: const SizedBox.shrink(),
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(
                            value: 'hi', child: Text('हिंदी (Hindi)')),
                        DropdownMenuItem(
                            value: 'pa', child: Text('ਪੰਜਾਬੀ (Punjabi)')),
                        DropdownMenuItem(
                            value: 'ur', child: Text('اردو (Urdu)')),
                        DropdownMenuItem(
                            value: 'kn', child: Text('ಕನ್ನಡ (Kannada)')),
                        DropdownMenuItem(
                            value: 'ta', child: Text('தமிழ் (Tamil)')),
                        DropdownMenuItem(
                            value: 'mr', child: Text('मराठी (Marathi)')),
                        DropdownMenuItem(
                            value: 'or', child: Text('ଓଡ଼ିଆ (Odia)')),
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

              // Local Storage Picker
              Text('LOCAL STORAGE FOR DOWNLOADS',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose where downloaded songs are stored.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(height: 8),
                    // Show current custom path if set
                    if (ref
                        .watch(downloadLocationProvider)
                        .startsWith('custom:'))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_open_rounded,
                                size: 16, color: tokens.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ref
                                    .watch(downloadLocationProvider)
                                    .substring(7),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.primaryText,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: ref
                              .watch(downloadLocationProvider)
                              .startsWith('custom:')
                          ? DownloadLocation.custom
                          : ref.watch(downloadLocationProvider),
                      dropdownColor:
                          isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      underline: const SizedBox.shrink(),
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black),
                      items: DownloadLocation.all
                          .map((loc) => DropdownMenuItem<String>(
                                value: loc.key,
                                child: Text(loc.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        if (val == DownloadLocation.custom) {
                          _pickCustomFolder(context, ref, isDark);
                        } else {
                          NoctraLocalDatabase().saveDownloadLocation(val);
                          ref.read(downloadLocationProvider.notifier).state =
                              val;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ref.watch(downloadLocationProvider).startsWith('custom:')
                          ? 'Custom folder selected. Songs will be saved here.'
                          : DownloadLocation.byKey(
                                  ref.watch(downloadLocationProvider))
                              .description,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                          height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Sleep Timer
              Text('SLEEP TIMER & AUTO FADE-OUT',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Playback Sleep Timer',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 2),
                        Text(
                            sleepRemaining != null
                                ? 'Active: $sleepRemaining min remaining'
                                : 'Disabled (Continuous playback)',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: sleepRemaining != null
                                    ? Colors.amber
                                    : (isDark
                                        ? Colors.white54
                                        : Colors.black54))),
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
                      dropdownColor:
                          isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      underline: const SizedBox.shrink(),
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black),
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
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Playback Configuration
              Text('PLAYBACK & QUEUE BEHAVIOR',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gapless Fade Transitions',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black)),
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
                        Text('Autoplay Delay (Radio)',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black)),
                        Text('${autoplayDelay}s',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // CODEC & Stream Quality
              Text('CODEC & STREAM QUALITY',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
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
                        builder: (c) => const StreamQualitySheet());
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.equalizer_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 10),
                          Text('Audio Quality & Codec Settings',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black)),
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Synced Lyrics Configuration
              Text('SYNCHRONIZED LYRICS ENGINE',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    _lyricsRadio(
                        'English / Global (Standard)', lyricsPref, ref, isDark),
                    const Divider(height: 4),
                    _lyricsRadio('Romanized Hindi/Punjabi (LRC)', lyricsPref,
                        ref, isDark),
                    const Divider(height: 4),
                    _lyricsRadio(
                        'Devanagari Transliteration', lyricsPref, ref, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Neural Network Settings
              Text('NEURAL RECOMMENDATION ENGINE',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 8),
              GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _nnStat('Training Steps',
                        '${NeuralRecommenderEngine.totalTrainSteps}', isDark),
                    const SizedBox(height: 6),
                    _nnStat(
                        'Running Accuracy',
                        '${(NeuralRecommenderEngine.accuracy * 100).toStringAsFixed(1)}%',
                        isDark),
                    const SizedBox(height: 6),
                    _nnStat(
                        'Average Loss',
                        NeuralRecommenderEngine.averageLoss.toStringAsFixed(4),
                        isDark),
                    const SizedBox(height: 10),
                    // Mini loss chart
                    SizedBox(
                      height: 40,
                      child: NeuralMiniChart(
                          lossHistory: NeuralRecommenderEngine.lossHistory,
                          isDark: isDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The neural network learns from your listening patterns in real-time. '
                      'More training steps = better recommendations.',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                          height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    // Taste archetype
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x0D000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.psychology_rounded,
                              size: 14,
                              color: isDark ? Colors.white60 : Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            'Your Profile: ${TasteVectorEngine.calculateArchetype(MusicRepository().userTasteVector)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Developer Panel Link
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
                        builder: (c) => const DeveloperPanelSheet());
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
                          Text('Developer Console & Telemetry',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black)),
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

  Widget _themeChip(BuildContext context, WidgetRef ref, String title,
      NoirThemeMode mode, NoirThemeMode current, bool isDark) {
    final isSelected = current == mode;

    final tokens = context.noctraTokens;
    return GestureDetector(
      onTap: () {
        ref.read(themeModeProvider.notifier).state = mode;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? tokens.canvas : tokens.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _iconChip(BuildContext context, String title,
      NoctraAppIcon icon, bool isDark) {
    final currentIcon = ref.watch(appIconProvider);
    final isSelected = currentIcon == icon;
    final tokens = context.noctraTokens;
    return GestureDetector(
      onTap: () async {
        // Optimistic: update state immediately
        ref.read(appIconProvider.notifier).state = icon;
        // Then call native
        final success = await DynamicIconService.setIcon(icon);
        if (!success) {
          // Rollback if native failed
          ref.read(appIconProvider.notifier).state = currentIcon;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? tokens.canvas : tokens.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _lyricsRadio(
      String value, String current, WidgetRef ref, bool isDark) {
    final isSelected = value == current;
    return InkWell(
      onTap: () => ref.read(lyricsPreferenceProvider.notifier).state = value,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black)),
            Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    );
  }

  Widget _nnStat(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54)),
        Text(value,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Future<void> _pickCustomFolder(
      BuildContext context, WidgetRef ref, bool isDark) async {
    final sm = ScaffoldMessenger.of(context);

    // Request storage permission first
    if (Platform.isAndroid) {
      // Android 11+ needs MANAGE_EXTERNAL_STORAGE for custom folders
      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        if (context.mounted) {
          sm.showSnackBar(SnackBar(
            content: const Text(
                'Storage permission required. Please enable it in Settings.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ));
        }
        return;
      }

      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Fallback: try regular storage permission
        final fallback = await Permission.storage.request();
        if (!fallback.isGranted) {
          if (context.mounted) {
            sm.showSnackBar(SnackBar(
              content: const Text(
                  'Storage permission is needed to save songs to a custom folder.'),
              action: SnackBarAction(
                label: 'Grant Access',
                onPressed: () => openAppSettings(),
              ),
            ));
          }
          return;
        }
      }
    }

    // Open folder picker
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select download folder for Noctra',
      );

      if (result != null && result.isNotEmpty) {
        // Verify the directory is writable
        final dir = Directory(result);
        if (!dir.existsSync()) {
          try {
            dir.createSync(recursive: true);
          } catch (e) {
            if (context.mounted) {
              sm.showSnackBar(SnackBar(
                content: Text('Cannot create folder: $e'),
              ));
            }
            return;
          }
        }

        // Test write access
        final testFile = File('$result/.noctra_write_test');
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (e) {
          if (context.mounted) {
            sm.showSnackBar(SnackBar(
              content: Text(
                  'Cannot write to this folder. Choose a different location.'),
            ));
          }
          return;
        }

        // Save custom path with prefix
        final customKey = 'custom:$result';
        NoctraLocalDatabase().saveDownloadLocation(customKey);
        ref.read(downloadLocationProvider.notifier).state = customKey;

        if (context.mounted) {
          sm.showSnackBar(SnackBar(
            content: Text('Download folder set to: $result'),
            duration: const Duration(seconds: 3),
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        sm.showSnackBar(SnackBar(
          content: Text('Folder picker error: $e'),
        ));
      }
    }
  }
}
