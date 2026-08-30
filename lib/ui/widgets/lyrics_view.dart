import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/lyrics/lyrics_service.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Song song;

  const LyricsView({super.key, required this.song});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  late Future<LyricsData> _lyricsFuture;
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -2;
  bool _userIsScrolling = false;
  Timer? _resumeAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _lyricsFuture = LyricsService.fetchLyrics(widget.song);
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _lineKeys.clear();
      _lyricsFuture = LyricsService.fetchLyrics(widget.song);
      _lastActiveIndex = -2;
    }
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (_userIsScrolling || index == _lastActiveIndex) return;
    _lastActiveIndex = index;

    if (index < 0) {
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.35,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == NoirThemeMode.noirBlack;
    final currentPos = ref.watch(positionStreamProvider).value ?? Duration.zero;

    return FutureBuilder<LyricsData>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Synchronizing time-coded master lyrics...',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data;
        if (data == null || (!data.isSynced && data.plainText.isEmpty)) {
          return Center(
            child: Text(
              'No lyrics found for this track',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          );
        }

        // Synced Lyrics Mode
        if (data.isSynced && data.lines.isNotEmpty) {
          int activeIndex = -1;
          for (int i = 0; i < data.lines.length; i++) {
            if (currentPos >= data.lines[i].timestamp) {
              activeIndex = i;
            } else {
              break;
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToIndex(activeIndex);
          });

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification && notification.dragDetails != null) {
                _userIsScrolling = true;
                _resumeAutoScrollTimer?.cancel();
              } else if (notification is ScrollEndNotification) {
                _resumeAutoScrollTimer?.cancel();
                _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _userIsScrolling = false);
                });
              }
              return false;
            },
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.08, 0.90, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                itemCount: data.lines.length,
                itemBuilder: (context, index) {
                  final line = data.lines[index];
                  final isActive = index == activeIndex;
                  final isPast = activeIndex >= 0 && index < activeIndex;
                  final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

                  return GestureDetector(
                    key: key,
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ref.read(audioPlayerServiceProvider).seek(line.timestamp);
                      setState(() => _userIsScrolling = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                      alignment: Alignment.centerLeft,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          fontSize: isActive ? 21 : (isPast ? 14.5 : 15.5),
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          letterSpacing: isActive ? -0.2 : 0.0,
                          height: 1.35,
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black)
                              : (isPast
                                  ? (isDark ? Colors.white.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.22))
                                  : (isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45))),
                          shadows: isActive
                              ? [
                                  Shadow(
                                    color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 14,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(line.text),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

        // Plain Lyrics Fallback Mode
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.06, 0.92, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 50),
            child: Text(
              data.plainText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                height: 1.85,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }
}
