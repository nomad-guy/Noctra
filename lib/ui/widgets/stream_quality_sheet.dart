import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../services/audio/stream_quality_service.dart';
import 'quality/audio_processing_options.dart';
import 'quality/stream_quality_options.dart';

/// Bottom sheet for stream quality and codec resolution settings.
class StreamQualitySheet extends ConsumerStatefulWidget {
  const StreamQualitySheet({super.key});

  @override
  ConsumerState<StreamQualitySheet> createState() => _StreamQualitySheetState();
}

class _StreamQualitySheetState extends ConsumerState<StreamQualitySheet> {
  final _service = StreamQualityService();
  late StreamQuality _selectedQuality;
  late AudioCodec _selectedCodec;
  late bool _normalizeVolume;
  late bool _gaplessPlayback;

  @override
  void initState() {
    super.initState();
    _selectedQuality = _service.streamQuality;
    _selectedCodec = _service.preferredCodec;
    _normalizeVolume = _service.normalizeVolume;
    _gaplessPlayback = _service.gaplessPlayback;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                  Icon(Icons.equalizer_rounded,
                      size: 22, color: tokens.accent),
                  const SizedBox(width: 10),
                  Text(
                    'CODEC & Resolution',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tokens.primaryText,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: tokens.secondaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('STREAM QUALITY', tokens),
                    const SizedBox(height: 8),
                    StreamQualityOptionsCard(
                      selectedQuality: _selectedQuality,
                      tokens: tokens,
                      onSelect: (q) {
                        setState(() => _selectedQuality = q);
                        _service.setStreamQuality(q);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('PREFERRED CODEC', tokens),
                    const SizedBox(height: 8),
                    AudioCodecOptionsCard(
                      selectedCodec: _selectedCodec,
                      tokens: tokens,
                      onSelect: (c) {
                        setState(() => _selectedCodec = c);
                        _service.setPreferredCodec(c);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('AUDIO PROCESSING', tokens),
                    const SizedBox(height: 8),
                    AudioProcessingTogglesCard(
                      normalizeVolume: _normalizeVolume,
                      gaplessPlayback: _gaplessPlayback,
                      tokens: tokens,
                      onNormalizeVolumeChanged: (v) => setState(() {
                        _normalizeVolume = v;
                        _service.setNormalizeVolume(v);
                      }),
                      onGaplessPlaybackChanged: (v) => setState(() {
                        _gaplessPlayback = v;
                        _service.setGaplessPlayback(v);
                      }),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                        'ESTIMATED FILE SIZES (4 min song)', tokens),
                    const SizedBox(height: 8),
                    EstimatedFileSizeCard(tokens: tokens),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text, NoctraThemeTokens tokens) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: tokens.secondaryText,
      ),
    );
  }
}
