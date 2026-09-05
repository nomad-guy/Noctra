import 'package:flutter/material.dart';
import '../../../services/lyrics/lyrics_service.dart';
import 'lyrics_line_tile.dart';

class LyricsSyncedList extends StatelessWidget {
  final ScrollController scrollController;
  final List<LyricLine> displayLines;
  final int activeIndex;
  final bool isDark;
  final Map<int, GlobalKey> lineKeys;
  final void Function(LyricLine line, int index) onLineTap;

  const LyricsSyncedList({
    super.key,
    required this.scrollController,
    required this.displayLines,
    required this.activeIndex,
    required this.isDark,
    required this.lineKeys,
    required this.onLineTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, 0.06, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(displayLines.length, (index) {
            final line = displayLines[index];
            return LyricsLineTile(
              line: line,
              index: index,
              isActive: index == activeIndex,
              isPast: activeIndex >= 0 && index < activeIndex,
              isDark: isDark,
              lineKey: lineKeys.putIfAbsent(index, () => GlobalKey()),
              onTap: () => onLineTap(line, index),
            );
          }),
        ),
      ),
    );
  }
}
