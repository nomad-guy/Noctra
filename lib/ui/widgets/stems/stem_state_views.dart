import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/noctra_localization.dart';
import '../../../services/audio/audio_stem_separation_service.dart';

class StemStartView extends StatelessWidget {
  final VoidCallback onStart;

  const StemStartView({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;

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
              NoctraLocalization.tr('separate_song_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              NoctraLocalization.tr('separate_description'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: tokens.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onStart,
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
                      NoctraLocalization.tr('start_separation'),
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
}

class StemProgressView extends StatelessWidget {
  final StemSeparationProgress? progress;

  const StemProgressView({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;

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
                '${(progress!.progress * 100).toStringAsFixed(0)}%',
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
}

class StemErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const StemErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;

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
              message ?? 'Separation failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  NoctraLocalization.tr('retry'),
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
