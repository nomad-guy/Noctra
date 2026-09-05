import 'package:flutter/material.dart';

/// Static, non-synced lyrics rendered as centered plain text.
/// Extracted from LyricsView so the view file stays under 300 LOC.
class LyricsPlainTextBody extends StatelessWidget {
  final String text;
  final bool isDark;

  const LyricsPlainTextBody({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.8,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}

/// Centered loading indicator shown while lyrics are being fetched.
class LyricsLoadingState extends StatelessWidget {
  final bool isDark;

  const LyricsLoadingState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              strokeWidth: 2, color: isDark ? Colors.white70 : Colors.black87),
          const SizedBox(height: 14),
          Text('Syncing Studio Lyrics...',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }
}
