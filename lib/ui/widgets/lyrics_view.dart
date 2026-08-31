import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/lyrics/devanagari_transliteration_service.dart';

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
  String _selectedScript = 'english';

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  void _loadLyrics() {
    final pref = ref.read(lyricsPreferenceProvider);
    _lyricsFuture = LyricsService.fetchLyrics(widget.song, preference: pref);
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _lineKeys.clear();
      _lastActiveIndex = -2;
      setState(_loadLyrics);
    }
  }

  int _findActiveIndex(List<LyricLine> lines, Duration pos) {
    int low = 0, high = lines.length - 1, result = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp <= pos) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _lineKeys.clear();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (_userIsScrolling) return;
    // Only scroll when the active line actually changes — prevents
    // firing every frame which caused early scroll-away from the current line.
    if (index == _lastActiveIndex) return;
    _lastActiveIndex = index;
    if (index < 0) {
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
      return;
    }
    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      // alignment: 0.5 centers the active line in the viewport so it dwells
      // visibly for the full duration before the next line triggers a scroll.
      Scrollable.ensureVisible(key!.currentContext!, alignment: 0.5, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final currentPos = ref.watch(positionStreamProvider).value ?? Duration.zero;

    return Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<LyricsData>(
            future: _lyricsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white70 : Colors.black87),
                      const SizedBox(height: 14),
                      Text('Syncing Studio Lyrics...', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                );
              }

              final rawData = snapshot.data ?? LyricsData.empty();
              final data = _selectedScript == 'devanagari'
                  ? DevanagariTransliterationService.transliterateLyrics(rawData, 'devanagari')
                  : rawData;

              if (data.isSynced && data.lines.isNotEmpty) {
                final activeIndex = _findActiveIndex(data.lines, currentPos);
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(activeIndex));

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification && notification.dragDetails != null) {
                      _userIsScrolling = true;
                      _resumeAutoScrollTimer?.cancel();
                    } else if (notification is ScrollEndNotification) {
                      _resumeAutoScrollTimer?.cancel();
                      // 5s gives the user time to read before auto-scroll resumes.
                      _resumeAutoScrollTimer = Timer(const Duration(seconds: 5), () {
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
                        stops: [0.0, 0.06, 0.92, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 64, 20, 80),
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
                            _scrollToIndex(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isActive
                                  ? (isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000))
                                  : Colors.transparent,
                              border: isActive
                                  ? Border.all(
                                      color: isDark ? const Color(0x33E0E0E0) : const Color(0x22000000),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Text(
                              line.text,
                              style: TextStyle(
                                fontSize: isActive ? 19.5 : (isPast ? 14.0 : 15.0),
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                letterSpacing: isActive ? 0.2 : 0.0,
                                height: 1.4,
                                color: isActive
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: isPast ? 0.32 : 0.60)
                                        : Colors.black.withValues(alpha: isPast ? 0.26 : 0.50)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                child: Text(data.plainText, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.8, color: isDark ? Colors.white70 : Colors.black87)),
              );
            },
          ),
        ),
        Positioned(
          top: 10,
          right: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _scriptChip('English', 'english', isDark),
              const SizedBox(width: 6),
              _scriptChip('देवनागरी', 'devanagari', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scriptChip(String label, String code, bool isDark) {
    final sel = _selectedScript == code;
    return GestureDetector(
      onTap: () {
        if (_selectedScript != code) {
          setState(() => _selectedScript = code);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
      ),
    );
  }
}
