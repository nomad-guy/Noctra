import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/lyrics/universal_lyrics_transliteration_engine.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Song song;
  const LyricsView({super.key, required this.song});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  late Future<LyricsData> _lyricsFuture;
  int _lastActiveIndex = -2;
  bool _userIsScrolling = false;
  Timer? _resumeAutoScrollTimer;
  Timer? _scrollDebounce;
  String _selectedScript = 'original';
  List<LyricLine> _cachedLines = [];
  bool _isSynced = false;
  String _plainText = '';

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  void _loadLyrics() {
    final pref = ref.read(lyricsPreferenceProvider);
    _lyricsFuture = LyricsService.fetchLyrics(widget.song, preference: pref);
    _lyricsFuture.then((data) {
      if (mounted) {
        setState(() {
          _cachedLines = data.lines;
          _isSynced = data.isSynced;
          _plainText = data.plainText;
          _lastActiveIndex = -2;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _lastActiveIndex = -2;
      _selectedScript = 'original';
      _loadLyrics();
    }
  }

  int _findActiveIndex(List<LyricLine> lines, Duration pos) {
    if (lines.isEmpty) return -1;
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

  void _scrollToIndex(int index) {
    if (_userIsScrolling) return;
    if (index == _lastActiveIndex) return;
    if (index < 0) return;
    _lastActiveIndex = index;
    // Debounce: cancel previous scroll animation
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_scrollController.hasClients) return;
      final targetOffset = (index * 48.0) - (_scrollController.position.viewportDimension / 2) + 64;
      final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollDebounce?.cancel();
    if (_scrollController.hasClients) _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final currentPos = ref.watch(positionStreamProvider).value ?? Duration.zero;

    // Compute active index — only triggers rebuild when line changes
    final activeIndex = _findActiveIndex(_cachedLines, currentPos);

    // Scroll to active line (debounced, no post-frame callback needed)
    if (_isSynced && _cachedLines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(activeIndex);
      });
    }

    return FutureBuilder<LyricsData>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedLines.isEmpty) {
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
        final options = UniversalLyricsTransliterationEngine.getAvailableScriptOptions(rawData);
        final data = UniversalLyricsTransliterationEngine.transliterateLyrics(rawData, _selectedScript);

        // Use cached data for sync, or freshly transliterated data
        final displayLines = data.isSynced ? data.lines : _cachedLines;
        final isSynced = data.isSynced || _isSynced;

        return Stack(
          children: [
            Positioned.fill(
              child: isSynced && displayLines.isNotEmpty
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification && notification.dragDetails != null) {
                          _userIsScrolling = true;
                          _resumeAutoScrollTimer?.cancel();
                        } else if (notification is ScrollEndNotification) {
                          _resumeAutoScrollTimer?.cancel();
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
                          itemCount: displayLines.length,
                          // Stable key per index to prevent rebuild churn
                          itemBuilder: (context, index) {
                            final line = displayLines[index];
                            final isActive = index == activeIndex;
                            final isPast = activeIndex >= 0 && index < activeIndex;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                ref.read(audioPlayerServiceProvider).seek(line.timestamp);
                                setState(() => _userIsScrolling = false);
                                _scrollToIndex(index);
                              },
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
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
                                  child: Text(line.text),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                      child: Text(
                        data.plainText.isNotEmpty ? data.plainText : _plainText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.8, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
            ),
            if (options.length > 1)
              Positioned(
                top: 10,
                right: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((opt) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _scriptChip(opt.label, opt.code, isDark),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
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
