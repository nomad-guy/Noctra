import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/lyrics/universal_lyrics_transliteration_engine.dart';
import 'lyrics/lyrics_plain_text_body.dart';
import 'lyrics/lyrics_script_selector.dart';
import 'lyrics/lyrics_synced_list.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Song song;
  const LyricsView({super.key, required this.song});

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
      alignment: 0.40,
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
    _lastScrolledIndex = -1;
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

    return FutureBuilder<LyricsData>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedLines.isEmpty) {
          return LyricsLoadingState(isDark: isDark);
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
                      onNotification: _handleScrollNotification,
                      child: LyricsSyncedList(
                        scrollController: _scrollController,
                        displayLines: displayLines,
                        activeIndex: _lastActiveIndex,
                        isDark: isDark,
                        lineKeys: _lineKeys,
                        onLineTap: (line, index) {
                          ref
                              .read(audioPlayerServiceProvider)
                              .seek(line.timestamp);
                          _resumeAutoScrollTimer?.cancel();
                          setState(() => _userIsScrolling = false);
                          _scrollToIndex(index);
                        },
                      ),
                    )
                  : LyricsPlainTextBody(
                      text: data.plainText.isNotEmpty
                          ? data.plainText
                          : _plainText,
                      isDark: isDark,
                    ),
            ),
            LyricsScriptSelector(
              options: options,
              selectedScript: _selectedScript,
              isDark: isDark,
              onSelectScript: (code) {
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
            ),
            if (_userIsScrolling && isSynced && displayLines.isNotEmpty)
              LyricsSyncFloatingButton(
                isDark: isDark,
                onTap: _resumeAutoScroll,
              ),
          ],
        );
      },
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
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
      _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 3500), () {
        _resumeAutoScroll();
      });
    }
    return false;
  }
}
