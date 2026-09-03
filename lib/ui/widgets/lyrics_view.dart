import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/lyrics/universal_lyrics_transliteration_engine.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Song song;
  const LyricsView({super.key, required this.song});

  /// Canonical single source of truth for active timed-lyric line resolution.
  /// Returns the greatest index `i` where `lines[i].timestamp <= pos`.
  /// Returns `-1` if [lines] is empty or [pos] is strictly before the first line.
  static int findActiveIndex(List<LyricLine> lines, Duration pos) {
    if (lines.isEmpty) return -1;
    if (pos < lines.first.timestamp) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].timestamp <= pos) {
        return i;
      }
    }
    return -1;
  }

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  late Future<LyricsData> _lyricsFuture;
  int _lastActiveIndex = -1;
  int _lastScrolledIndex = -1;
  int _lyricsGeneration = 0;
  int _scrollGeneration = 0;
  bool _userIsScrolling = false;
  Timer? _resumeAutoScrollTimer;
  StreamSubscription<Duration>? _positionSub;
  String _selectedScript = 'original';
  List<LyricLine> _cachedLines = [];
  bool _isSynced = false;
  String _plainText = '';

  @override
  void initState() {
    super.initState();
    _loadLyrics();

    // Position stream listener: single authoritative source of truth.
    // Throttled: only triggers setState and viewport auto-scroll when
    // the active line index ACTUALLY changes.
    _positionSub = ref
        .read(audioPlayerServiceProvider)
        .player
        .positionStream
        .listen((pos) {
      if (!mounted || !_isSynced || _cachedLines.isEmpty) return;
      final activeIndex = LyricsView.findActiveIndex(_cachedLines, pos);
      if (activeIndex == _lastActiveIndex) return;

      setState(() {
        _lastActiveIndex = activeIndex;
      });

      if (!_userIsScrolling && activeIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToIndex(activeIndex);
          }
        });
      }
    });
  }

  void _loadLyrics() {
    final pref = ref.read(lyricsPreferenceProvider);
    final preferenceKey = pref.toLowerCase();
    final preferredScript = preferenceKey.contains('romanized')
        ? 'roman'
        : (preferenceKey.contains('devanagari') ? 'devanagari' : 'original');
    final currentGen = ++_lyricsGeneration;
    final targetSongId = widget.song.id;
    _lyricsFuture = LyricsService.fetchLyrics(widget.song, preference: pref);
    _lyricsFuture.then((data) {
      if (mounted &&
          currentGen == _lyricsGeneration &&
          widget.song.id == targetSongId) {
        final lines = data.lines;
        final isSynced = data.isSynced;
        final pos = ref.read(audioPlayerServiceProvider).player.position;
        final activeIndex = isSynced && lines.isNotEmpty
            ? LyricsView.findActiveIndex(lines, pos)
            : -1;

        setState(() {
          _selectedScript = preferredScript;
          _cachedLines = lines;
          _isSynced = isSynced;
          _plainText = data.plainText;
          _lineKeys.clear();
          _lastActiveIndex = activeIndex;
        });

        // Immediately follow active line as soon as lyrics load (even if
        // playback was already underway before network response arrived).
        if (isSynced && activeIndex >= 0 && !_userIsScrolling) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && currentGen == _lyricsGeneration) {
              _scrollToIndex(activeIndex);
            }
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _lyricsGeneration++;
      _scrollGeneration++;
      _lastActiveIndex = -1;
      _lastScrolledIndex = -1;
      _userIsScrolling = false;
      _resumeAutoScrollTimer?.cancel();
      _selectedScript = 'original';
      _lineKeys.clear();
      _cachedLines = [];
      _isSynced = false;
      _plainText = '';
      _loadLyrics();
    }
  }

  void _scrollToIndex(int index, {bool isRetry = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    if (_userIsScrolling) return;
    if (index < 0 || index >= _cachedLines.length) return;
    if (index == _lastScrolledIndex && !isRetry) return;

    final targetGen = ++_scrollGeneration;
    _lastScrolledIndex = index;

    final lineContext = _lineKeys[index]?.currentContext;
    if (lineContext == null || !lineContext.mounted) {
      // If layout has not finished yet, retry once on next frame.
      if (!isRetry) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && targetGen == _scrollGeneration) {
            _scrollToIndex(index, isRetry: true);
          }
        });
      }
      return;
    }

    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.40, // Keeps current line comfortably near vertical center (40%)
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _resumeAutoScroll() {
    _resumeAutoScrollTimer?.cancel();
    if (!mounted) return;
    final pos = ref.read(audioPlayerServiceProvider).player.position;
    final activeIndex = LyricsView.findActiveIndex(_cachedLines, pos);
    setState(() {
      _userIsScrolling = false;
      if (activeIndex >= 0) {
        _lastActiveIndex = activeIndex;
      }
    });
    _lastScrolledIndex = -1; // Reset to ensure viewport moves back to active line
    final target = _lastActiveIndex >= 0 ? _lastActiveIndex : 0;
    _scrollToIndex(target);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(lyricsPreferenceProvider, (_, __) {
      if (mounted) _loadLyrics();
    });
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final activeIndex = _lastActiveIndex;

    return FutureBuilder<LyricsData>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedLines.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(height: 14),
                Text('Syncing Studio Lyrics...',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          );
        }

        final rawData = snapshot.data ?? LyricsData.empty();
        final options =
            UniversalLyricsTransliterationEngine.getAvailableScriptOptions(
                rawData);
        final data = UniversalLyricsTransliterationEngine.transliterateLyrics(
            rawData, _selectedScript);

        final displayLines = data.isSynced ? data.lines : _cachedLines;
        final isSynced = data.isSynced || _isSynced;

        return Stack(
          children: [
            Positioned.fill(
              child: isSynced && displayLines.isNotEmpty
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification &&
                            notification.dragDetails != null) {
                          if (!_userIsScrolling) {
                            setState(() => _userIsScrolling = true);
                          }
                          _resumeAutoScrollTimer?.cancel();
                        } else if (notification is UserScrollNotification &&
                            notification.direction != ScrollDirection.idle) {
                          if (!_userIsScrolling) {
                            setState(() => _userIsScrolling = true);
                          }
                          _resumeAutoScrollTimer?.cancel();
                        } else if (notification is ScrollEndNotification) {
                          _resumeAutoScrollTimer?.cancel();
                          _resumeAutoScrollTimer = Timer(
                              const Duration(milliseconds: 3500), () {
                            _resumeAutoScroll();
                          });
                        }
                        return false;
                      },
                      child: ShaderMask(
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
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 72, 20, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(displayLines.length, (index) {
                              final line = displayLines[index];
                              final isActive = index == activeIndex;
                              final isPast =
                                  activeIndex >= 0 && index < activeIndex;

                              return GestureDetector(
                                key: _lineKeys.putIfAbsent(
                                    index, () => GlobalKey()),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  ref
                                      .read(audioPlayerServiceProvider)
                                      .seek(line.timestamp);
                                  _resumeAutoScrollTimer?.cancel();
                                  setState(() => _userIsScrolling = false);
                                  _scrollToIndex(index);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOutCubic,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                      height: 1.4,
                                      color: isActive
                                          ? (isDark ? Colors.white : Colors.black)
                                          : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: isPast ? 0.32 : 0.60)
                                              : Colors.black.withValues(
                                                  alpha: isPast ? 0.26 : 0.50)),
                                    ),
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 160),
                                      opacity: isActive
                                          ? 1.0
                                          : (isPast ? 0.72 : 0.9),
                                      child: Text(line.text),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                      child: Text(
                        data.plainText.isNotEmpty ? data.plainText : _plainText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.8,
                            color: isDark ? Colors.white70 : Colors.black87),
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
            if (_userIsScrolling && isSynced && displayLines.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _resumeAutoScroll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.92)
                            : Colors.black.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.vertical_align_center_rounded,
                            size: 14,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sync with Song',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
          setState(() {
            _selectedScript = code;
            _lineKeys.clear();
          });
          if (_lastActiveIndex >= 0 && !_userIsScrolling) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToIndex(_lastActiveIndex);
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sel
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white70 : Colors.black87))),
      ),
    );
  }
}
