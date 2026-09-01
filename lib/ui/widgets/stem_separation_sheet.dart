import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/audio/audio_stem_separation_service.dart';
import 'glass_card.dart';

/// Bottom sheet for on-device audio stem separation.
/// Allows users to separate a song into vocals, drums, bass, and other.
class StemSeparationSheet extends ConsumerStatefulWidget {
  final Song song;

  const StemSeparationSheet({super.key, required this.song});

  @override
  ConsumerState<StemSeparationSheet> createState() => _StemSeparationSheetState();
}

class _StemSeparationSheetState extends ConsumerState<StemSeparationSheet> {
  final _service = AudioStemSeparationService();
  StemSeparationResult? _result;
  StemSeparationProgress? _progress;
  StemSeparationModel _selectedModel = StemSeparationModel.light;
  bool _isProcessing = false;
  String? _playingStem;
  AudioPlayer? _stemPlayer;

  @override
  void dispose() {
    _stemPlayer?.dispose();
    super.dispose();
  }

  Future<void> _startSeparation() async {
    setState(() {
      _isProcessing = true;
      _result = null;
    });

    // Subscribe to progress
    final sub = _service.progressStream.listen((p) {
      if (mounted) setState(() => _progress = p);
    });

    // Get audio source for the song
    String audioSource = widget.song.localFilePath ?? '';
    if (audioSource.isEmpty && widget.song.streamUrl != null) {
      audioSource = widget.song.streamUrl!;
    }
    if (audioSource.isEmpty) {
      // Try resolving the stream
      try {
        final resolved = await _resolveStreamUrl(widget.song);
        if (resolved != null) audioSource = resolved;
      } catch (_) {}
    }

    if (audioSource.isEmpty) {
      setState(() {
        _isProcessing = false;
        _progress = StemSeparationProgress(
          stage: 'error',
          progress: 0,
          message: 'Could not resolve audio source for this song.',
        );
      });
      sub.cancel();
      return;
    }

    final result = await _service.separate(
      audioSource: audioSource,
      songId: widget.song.id,
      model: _selectedModel,
    );

    sub.cancel();
    if (mounted) {
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    }
  }

  Future<String?> _resolveStreamUrl(Song song) async {
    try {
      const channel = MethodChannel('com.noctra.app/native_resolver');
      return await channel.invokeMethod<String>('extractInnerTube', {
        'videoId': song.id,
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _playStem(AudioStem stem) async {
    if (_playingStem == stem.name) {
      await _stemPlayer?.stop();
      setState(() => _playingStem = null);
      return;
    }

    try {
      await _stemPlayer?.stop();
      _stemPlayer?.dispose();
      _stemPlayer = AudioPlayer();
      await _stemPlayer!.setFilePath(stem.audioFile!.path);
      await _stemPlayer!.play();
      setState(() => _playingStem = stem.name);

      _stemPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingStem = null);
        }
      });
    } catch (e) {
      NoctraLogger.e('Failed to play stem', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play ${stem.displayName}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tokens.subtleBorder),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: tokens.secondaryText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded,
                      size: 22, color: tokens.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Stems',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: tokens.primaryText,
                          ),
                        ),
                        Text(
                          'Separate "${widget.song.title}" into components',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: tokens.secondaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Model Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEPARATION MODEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: tokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: StemSeparationModel.values.map((model) {
                        final isSelected = _selectedModel == model;
                        final labels = {
                          StemSeparationModel.light: ('Light', '~30s'),
                          StemSeparationModel.hq: ('HQ', '~2min'),
                          StemSeparationModel.karaoke: ('Karaoke', '~30s'),
                        };
                        final (label, time) = labels[model]!;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedModel = model),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? tokens.accent
                                    : tokens.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? tokens.accent
                                      : tokens.subtleBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? tokens.canvas
                                          : tokens.primaryText,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected
                                          ? tokens.canvas
                                              .withValues(alpha: 0.7)
                                          : tokens.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress or Results
            Expanded(
              child: _buildContent(tokens, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(NoctraThemeTokens tokens, bool isDark) {
    if (_isProcessing) {
      return _buildProgress(tokens, isDark);
    }

    if (_result != null) {
      return _buildResults(tokens, isDark);
    }

    if (_progress?.stage == 'error') {
      return _buildError(tokens, isDark);
    }

    return _buildStartView(tokens, isDark);
  }

  Widget _buildStartView(NoctraThemeTokens tokens, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.multitrack_audio_rounded,
                size: 48, color: tokens.accent.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'Separate this song into individual stems',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Split into Vocals, Drums, Bass & Other using on-device ML.\nNo internet required after initial processing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: tokens.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _startSeparation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        size: 20, color: tokens.canvas),
                    const SizedBox(width: 8),
                    Text(
                      'Start Separation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.canvas,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(NoctraThemeTokens tokens, bool isDark) {
    final progress = _progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress?.progress,
                strokeWidth: 3,
                color: tokens.accent,
                backgroundColor: tokens.surfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              progress?.message ?? 'Processing...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.primaryText,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(NoctraThemeTokens tokens, bool isDark) {
    final stems = _result!.stems;
    return Column(
      children: [
        // Processing info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: Colors.greenAccent.shade400),
              const SizedBox(width: 8),
              Text(
                'Separated in ${(_result!.processingTimeMs / 1000).toStringAsFixed(1)}s '
                'using ${_result!.modelUsed} model',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stems list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stems.length,
            itemBuilder: (context, index) {
              final stem = stems[index];
              final isPlaying = _playingStem == stem.name;

              final stemIcons = {
                'vocals': Icons.record_voice_over_rounded,
                'drums': Icons.album_rounded,
                'bass': Icons.surround_sound_rounded,
                'other': Icons.music_note_rounded,
              };

              final stemColors = {
                'vocals': Colors.cyanAccent,
                'drums': Colors.orangeAccent,
                'bass': Colors.purpleAccent,
                'other': Colors.greenAccent,
              };

              return GlassCard(
                radius: 14,

                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: stemColors[stem.name]
                            ?.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        stemIcons[stem.name],
                        size: 20,
                        color: stemColors[stem.name],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stem.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tokens.primaryText,
                            ),
                          ),
                          Text(
                            '${(stem.audioFile?.lengthSync() ?? 0) ~/ 1024} KB • ${stem.name}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Play/Pause button
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill_rounded,
                        size: 32,
                        color: isPlaying
                            ? stemColors[stem.name]
                            : tokens.primaryText,
                      ),
                      onPressed: () => _playStem(stem),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Re-separate button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                setState(() => _result = null);
                _startSeparation();
              },
              child: Text(
                'Re-separate with different model',
                style: TextStyle(
                  color: tokens.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(NoctraThemeTokens tokens, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              _progress?.message ?? 'Separation failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _startSeparation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.canvas,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
