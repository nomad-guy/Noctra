import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../services/audio/stream_quality_service.dart';
import 'glass_card.dart';

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
                    // Stream Quality
                    _buildSectionHeader('STREAM QUALITY', tokens),
                    const SizedBox(height: 8),
                    GlassCard(
                      radius: 14,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: StreamQuality.values.map((q) {
                          final isSelected = _selectedQuality == q;
                          return _buildQualityOption(q, isSelected, tokens);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preferred Codec
                    _buildSectionHeader('PREFERRED CODEC', tokens),
                    const SizedBox(height: 8),
                    GlassCard(
                      radius: 14,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: AudioCodec.values.map((c) {
                          final isSelected = _selectedCodec == c;
                          return _buildCodecOption(c, isSelected, tokens);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Audio Processing
                    _buildSectionHeader('AUDIO PROCESSING', tokens),
                    const SizedBox(height: 8),
                    GlassCard(
                      radius: 14,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          _buildToggleOption(
                            'Volume Normalization',
                            'Balance volume levels across tracks',
                            _normalizeVolume,
                            tokens,
                            (v) => setState(() {
                              _normalizeVolume = v;
                              _service.setNormalizeVolume(v);
                            }),
                          ),
                          const Divider(height: 8),
                          _buildToggleOption(
                            'Gapless Playback',
                            'Seamless transitions between tracks',
                            _gaplessPlayback,
                            tokens,
                            (v) => setState(() {
                              _gaplessPlayback = v;
                              _service.setGaplessPlayback(v);
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // File Size Estimates
                    _buildSectionHeader('ESTIMATED FILE SIZES (4 min song)', tokens),
                    const SizedBox(height: 8),
                    GlassCard(
                      radius: 14,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: StreamQuality.values.map((q) {
                          final sizeMB =
                              StreamQualityService.estimateFileSizeMB(240, q);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  q.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.primaryText,
                                  ),
                                ),
                                Text(
                                  q == StreamQuality.hiRes
                                      ? '~${sizeMB.toStringAsFixed(0)} MB'
                                      : '~${sizeMB.toStringAsFixed(1)} MB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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

  Widget _buildQualityOption(
      StreamQuality quality, bool isSelected, NoctraThemeTokens tokens) {
    return InkWell(
      onTap: () {
        setState(() => _selectedQuality = quality);
        _service.setStreamQuality(quality);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: isSelected ? tokens.accent : tokens.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quality.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: tokens.primaryText,
                    ),
                  ),
                  if (quality != StreamQuality.hiRes)
                    Text(
                      '${quality.bitrate} kbps • ${quality.codec.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.secondaryText,
                      ),
                    )
                  else
                    Text(
                      'Lossless • ${quality.codec.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodecOption(
      AudioCodec codec, bool isSelected, NoctraThemeTokens tokens) {
    return InkWell(
      onTap: () {
        setState(() => _selectedCodec = codec);
        _service.setPreferredCodec(codec);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: isSelected ? tokens.accent : tokens.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    codec.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: tokens.primaryText,
                    ),
                  ),
                  Text(
                    codec.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String title,
    String subtitle,
    bool value,
    NoctraThemeTokens tokens,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.primaryText,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: tokens.accent,
          ),
        ],
      ),
    );
  }
}
