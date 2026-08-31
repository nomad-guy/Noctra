import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../widgets/glass_card.dart';
import '../../services/ai/candidate_retrieval_service.dart';

class AIStudioScreen extends ConsumerStatefulWidget {
  const AIStudioScreen({super.key});
  @override
  ConsumerState<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends ConsumerState<AIStudioScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  bool _archetypeExpanded = false;
  List<Map<String, dynamic>> _results = [];
  String _activeChip = '';

  static const _moodChips = [
    ('Late Night', 'noir_night', Icons.nightlight_round),
    ('High Energy', 'high_energy', Icons.bolt_rounded),
    ('Chill', 'ambient_chill', Icons.spa_rounded),
    ('Bollywood', 'bollywood', Icons.music_note_rounded),
    ('Deep Focus', 'deep_focus', Icons.psychology_rounded),
    ('Synthwave', 'retro_synth', Icons.graphic_eq_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadDefault();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _loadDefault() async {
    setState(() => _isLoading = true);
    try {
      final results = await CandidateRetrievalService.curatePersonalizedFeed(targetCount: 15)
          .timeout(const Duration(seconds: 8));
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submitPrompt(String rawPrompt) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty) return;
    setState(() { _isLoading = true; _activeChip = ''; });
    try {
      final song = ref.read(currentSongStreamProvider).value;
      final results = await CandidateRetrievalService.curatePersonalizedFeed(
        naturalPrompt: prompt,
        seedSong: prompt.toLowerCase().contains('like this') ? song : null,
        targetCount: 15,
      ).timeout(const Duration(seconds: 10));
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectChip(String vibeKey, String label) async {
    setState(() { _isLoading = true; _activeChip = vibeKey; _promptController.clear(); });
    try {
      final results = await CandidateRetrievalService.curatePersonalizedFeed(
        vibeKey: vibeKey, targetCount: 15,
      ).timeout(const Duration(seconds: 8));
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);
    final archetype = repo.getUserMusicalArchetype();
    final dominantAxes = repo.getDominantAxes();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : Colors.black, size: 24),
                    onPressed: () => ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text('AI Studio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary))),
                  IconButton(
                    tooltip: 'Developer Panel',
                    icon: Icon(Icons.terminal_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                    onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const DeveloperPanelSheet()),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'What are you in the mood for?',
                          hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                        onSubmitted: _submitPrompt,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    if (_isLoading)
                      Padding(padding: const EdgeInsets.only(right: 14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white54 : Colors.black54)))
                    else
                      IconButton(icon: Icon(Icons.arrow_forward_rounded, size: 18, color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.60)), onPressed: () => _submitPrompt(_promptController.text)),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Mood chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _moodChips.map((chip) {
                    final isActive = _activeChip == chip.$2;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _selectChip(chip.$2, chip.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(chip.$3, size: 13, color: isActive ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70))),
                            const SizedBox(width: 5),
                            Text(chip.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70)))),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Results
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = _results[i];
                    final song = item['song'] as Song;
                    final explanation = item['explanation'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        onTap: () {
                          final queue = _results.map((m) => m['song'] as Song).toList();
                          ref.read(audioPlayerServiceProvider).playSong(song, newQueue: queue);
                        },
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(song.artworkUrl ?? '', width: 44, height: 44, cacheWidth: 132, cacheHeight: 132, fit: BoxFit.cover,
                              errorBuilder: (c, e, st) => Container(width: 44, height: 44, color: isDark ? const Color(0xFF222222) : const Color(0xFFDDDDDD),
                                child: Icon(Icons.music_note_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 2),
                            Text(explanation.isNotEmpty ? explanation : song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                          ])),
                          Icon(Icons.play_arrow_rounded, size: 22, color: isDark ? Colors.white38 : Colors.black38),
                        ]),
                      ),
                    );
                  },
                  childCount: _results.length,
                ),
              ),
            ),

            // Archetype collapsible footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GestureDetector(
                  onTap: () => setState(() => _archetypeExpanded = !_archetypeExpanded),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.person_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Your sound: $archetype', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70)))),
                        Icon(_archetypeExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                      ]),
                      if (_archetypeExpanded) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: dominantAxes.map((d) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${d['name']}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70))),
                        )).toList()),
                      ],
                    ]),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }
}
