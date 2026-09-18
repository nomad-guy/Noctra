import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../services/audio/audio_upscale_service.dart';
import '../../services/audio/local_audio_resolver.dart';

/// Bottom sheet for on-device audio upscaling: DSP enhancement
/// (harmonic reconstruction + band extension + soft limiting) in a
/// background isolate, exported as a true lossless 24-bit WAV.
/// Streamed tracks are downloaded first; this is stated in the UI.
class AudioUpscaleSheet extends StatefulWidget {
  final Song song;

  const AudioUpscaleSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioUpscaleSheet(song: song),
    );
  }

  @override
  State<AudioUpscaleSheet> createState() => _AudioUpscaleSheetState();
}

class _AudioUpscaleSheetState extends State<AudioUpscaleSheet> {
  final _service = AudioUpscaleService();
  double _strength = 0.6;
  bool _running = false;
  String _stage = '';
  double _progress = 0;
  String? _resultPath;
  StreamSubscription? _sub;
  bool _isLocal = false;
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _sub = _service.progressStream.listen((p) {
      if (!mounted) return;
      setState(() {
        _stage = p.message;
        _progress = p.progress;
      });
    });
    _isLocal = LocalAudioResolver.isLocal(widget.song);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _downloadThenUpscale() async {
    setState(() {
      _running = true;
      _stage = 'Preparing track...';
      _progress = 0.02;
    });
    final path = await LocalAudioResolver.ensureLocalFile(
      widget.song,
      onStatus: (m) => mounted ? setState(() => _stage = m) : null,
    );
    if (!mounted) return;
    if (path == null) {
      setState(() => _running = false);
      _snack('Download failed — cannot upscale a streaming track.');
      return;
    }
    setState(() => _isLocal = true);
    _lastPath = path;
    await _run(path);
  }

  Future<void> _run(String localPath) async {
    HapticFeedback.mediumImpact();
    setState(() => _running = true);

    final result = await _service.upscale(
      inputPath: localPath,
      songId: widget.song.id,
      strength: _strength,
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _resultPath = result?.path;
    });
    if (result == null) {
      _snack('Upscale failed — check the log export in Settings.');
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    final hasResult = _resultPath != null;
    final canStart = _isLocal && !_running;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: t.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: t.tertiaryText,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.equalizer_rounded,
                        size: 22, color: t.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Upscaler',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: t.primaryText),
                        ),
                        Text(
                          'Reconstruct harmonics lost to lossy compression → lossless 24-bit WAV',
                          style: TextStyle(
                              fontSize: 11, color: t.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Strength slider
              Text(
                'Enhancement strength',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.primaryText),
              ),
              Slider(
                value: _strength,
                min: 0.2,
                max: 1.0,
                divisions: 4,
                label: _strength == 0.2
                    ? 'Subtle'
                    : _strength == 0.4
                        ? 'Light'
                        : _strength == 0.6
                            ? 'Balanced'
                            : _strength == 0.8
                                ? 'Warm'
                                : 'Maximum',
                onChanged: _running
                    ? null
                    : (v) => setState(() => _strength = v),
              ),

              // Progress / result / status
              if (_running) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  _stage,
                  style:
                      TextStyle(fontSize: 12, color: t.secondaryText),
                ),
              ] else if (hasResult) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved: ${_resultPath!.split('/').last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: t.primaryText),
                      ),
                    ),
                  ],
                ),
              ] else if (!_isLocal) ...[
                const SizedBox(height: 8),
                Text(
                  'This track is not on this device yet. '
                  'Noctra will download it first, then upscale locally.',
                  style: TextStyle(fontSize: 12, color: t.secondaryText),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  '• Runs fully on-device, in a background isolate\n'
                  '• Restores perceived brightness and air from lossy sources\n'
                  '• Output: standard 24-bit WAV, playable anywhere',
                  style: TextStyle(fontSize: 12, color: t.secondaryText),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.canvas,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _running
                      ? null
                      : (hasResult
                          ? () => _snack(
                              'Saved in your music folder — open it with any player.')
                          : (canStart
                              ? () => _run(_lastPath!)
                              : _downloadThenUpscale)),
                  child: Text(
                    _running
                        ? 'Upscaling…'
                        : hasResult
                            ? 'Done'
                            : canStart
                                ? 'Start upscaling'
                                : 'Download & upscale',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
