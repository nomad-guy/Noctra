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
  final Map<int, GlobalKey> _lineKeys = {};
  late Future<LyricsData> _lyricsFuture;
  int _lastActiveIndex = -2;
  int _lyricsGeneration = 0;
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
    // Subscribing to the position stream here (instead of watching it in
    // build) means the lyrics list — transliteration output, ShaderMask,
    // per-line text styles — only rebuilds when the ACTIVE line index
    // actually changes, not on every ~200ms position tick.
    _positionSub = ref
        .read(audioPlayerServiceProvider)
        .player
        .positionStream
        .listen((pos) {
      if (!mounted || !_isSynced || _cachedLines.isEmpty) return;
      final activeIndex = _findActiveIndex(_cachedLines, pos);
      if (activeIndex == _lastActiveIndex) return;
      setState(() {
        _lastActiveIndex = activeIndex;
        if (_userIsScrolling) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToIndex(activeIndex);
        });
      });
    });
  }

  void _loadLyrics() {
    final pref = ref.read(lyricsPreferenceProvider);
    // Settings describe the desired presentation, not just the fetch source.
    // Select it as soon as the payload arrives so the user does not have to
    // manually press a second script button.
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
        setState(() {
          _selectedScript = preferredScript;
          _cachedLines = data.lines;
          _isSynced = data.isSynced;
          _plainText = data.plainText;
          _lineKeys.clear();
          // Establish the active line immediately (instead of waiting for
          // the next position tick) so paused songs still highlight the
          // current line as soon as lyrics arrive.
          if (data.isSynced && data.lines.isNotEmpty) {
            final pos = ref.read(audioPlayerServiceProvider).player.position;
            _lastActiveIndex = _findActiveIndex(data.lines, pos);
          } else {
            _lastActiveIndex = -2;
          }
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
      _lineKeys.clear();
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
    final lineContext = _lineKeys[index]?.currentContext;
    if (lineContext == null) return;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.45,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
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
    // The active line index is tracked by the position subscription in
    // initState — reading it here means this build no longer re-runs on
    // every position tick.
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

        // Use cached data for sync, or freshly transliterated data
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
                          _userIsScrolling = true;
                          _resumeAutoScrollTimer?.cancel();
                        } else if (notification is ScrollEndNotification) {
                          _resumeAutoScrollTimer?.cancel();
                          _resumeAutoScrollTimer =
                              Timer(const Duration(seconds: 5), () {
                            if (mounted) {
                              setState(() => _userIsScrolling = false);
                            }
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
                        child: ListView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 64, 20, 80),
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
                                    opacity:
                                        isActive ? 1.0 : (isPast ? 0.72 : 0.9),
                                    child: Text(line.text),
                                  ),
                                ),
                              ),
                            );
                          }),
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
