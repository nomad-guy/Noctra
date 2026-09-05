import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import '../../services/audio/audio_stem_separation_service.dart';
import '../../services/resolvers/native_resolver_client.dart';
import 'stems/stem_model_selector.dart';
import 'stems/stem_results_view.dart';
import 'stems/stem_state_views.dart';

class StemSeparationSheet extends ConsumerStatefulWidget {
  final Song song;

  const StemSeparationSheet({super.key, required this.song});

  @override
  ConsumerState<StemSeparationSheet> createState() =>
      _StemSeparationSheetState();
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

    final sub = _service.progressStream.listen((p) {
      if (mounted) setState(() => _progress = p);
    });

    String audioSource = widget.song.localFilePath ?? '';
    if (audioSource.isEmpty && widget.song.streamUrl != null) {
      audioSource = widget.song.streamUrl!;
    }
    if (audioSource.isEmpty) {
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
    // Platform boundary: never construct MethodChannel in UI code. The native
    // InnerTube fast path lives behind NativeResolverClient, which returns
    // null on unsupported platforms/failures so Dart-side fallback applies.
    return NativeResolverClient.extractInnerTube(song.id);
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
            StemModelSelector(
              selectedModel: _selectedModel,
              onModelSelected: (model) =>
                  setState(() => _selectedModel = model),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isProcessing) {
      return StemProgressView(progress: _progress);
    }
    if (_result != null) {
      return StemResultsView(
        result: _result!,
        playingStem: _playingStem,
        onPlayStem: _playStem,
        onReseparate: () {
          setState(() => _result = null);
          _startSeparation();
        },
      );
    }
    if (_progress?.stage == 'error') {
      return StemErrorView(
        message: _progress?.message,
        onRetry: _startSeparation,
      );
    }
    return StemStartView(onStart: _startSeparation);
  }
}
