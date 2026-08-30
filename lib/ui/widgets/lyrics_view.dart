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
  String _selectedLang = 'auto';

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  void _loadLyrics() {
    final pref = _selectedLang == 'hindi' ? 'Hindi / हिन्दी' : 'English / Global';
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
    if (_userIsScrolling || index == _lastActiveIndex) return;
    _lastActiveIndex = index;
    if (index < 0) {
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
      return;
    }
    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, alignment: 0.35, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
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
                      SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 10),
                      Text('Synchronizing lyrics...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                );
              }

              final data = snapshot.data;
              if (data == null || (!data.isSynced && data.plainText.isEmpty)) {
                return Center(child: Text('No lyrics found for this track', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)));
              }

              if (data.isSynced && data.lines.isNotEmpty) {
                final activeIndex = _findActiveIndex(data.lines, currentPos);
                if (activeIndex != _lastActiveIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(activeIndex));
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification && n.dragDetails != null) {
                      _userIsScrolling = true;
                      _resumeAutoScrollTimer?.cancel();
                    } else if (n is ScrollEndNotification) {
                      _resumeAutoScrollTimer?.cancel();
                      _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _userIsScrolling = false); });
                    }
                    return false;
                  },
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent], stops: [0.0, 0.12, 0.88, 1.0]).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 60),
                      itemCount: data.lines.length,
                      itemBuilder: (context, index) {
                        final line = data.lines[index];
                        final isActive = index == activeIndex;
                        final isPast = activeIndex >= 0 && index < activeIndex;
                        final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

                        return GestureDetector(
                          key: key,
                          behavior: HitTestBehavior.opaque,
                          onTap: () { ref.read(audioPlayerServiceProvider).seek(line.timestamp); setState(() => _userIsScrolling = false); },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                            child: Text(
                              line.text,
                              style: TextStyle(
                                fontSize: isActive ? 19 : (isPast ? 13.5 : 14.5),
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                color: isActive ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white.withValues(alpha: isPast ? 0.28 : 0.55) : Colors.black.withValues(alpha: isPast ? 0.22 : 0.45)),
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
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                child: Text(data.plainText, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.8, color: isDark ? Colors.white70 : Colors.black87)),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _langChip('Auto', 'auto', isDark),
              const SizedBox(width: 6),
              _langChip('हिन्दी', 'hindi', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _langChip(String label, String code, bool isDark) {
    final sel = _selectedLang == code;
    return GestureDetector(
      onTap: () {
        if (_selectedLang != code) {
          setState(() { _selectedLang = code; _loadLyrics(); });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
      ),
    );
  }
}
