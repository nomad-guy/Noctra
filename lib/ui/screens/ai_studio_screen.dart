import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../widgets/ai_archetype_card.dart';
import '../widgets/ai_prompt_curator_section.dart';
import '../widgets/glass_card.dart';

class AIStudioScreen extends ConsumerStatefulWidget {
  const AIStudioScreen({super.key});

  @override
  ConsumerState<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends ConsumerState<AIStudioScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _curatedResults = [];

  @override
  void initState() {
    super.initState();
    _loadInitialMix();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _loadInitialMix() {
    final repo = ref.read(musicRepositoryProvider);
    setState(() {
      _curatedResults = repo.curateByVibe(vibeKey: 'late_night');
    });
  }

  void _submitPrompt(String prompt) async {
    final clean = prompt.trim();
    if (clean.isEmpty) return;

    setState(() => _isLoading = true);
    final repo = ref.read(musicRepositoryProvider);
    final results = await repo.curateWithAIAgent(prompt: clean);

    if (mounted) {
      setState(() {
        _curatedResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == NoirThemeMode.noirBlack;
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
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : Colors.black, size: 26),
                          tooltip: 'Open Sidebar',
                          onPressed: () => ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Music Agent',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary),
                            ),
                            Text(
                              'On-Device RAG & Graph Ranking',
                              style: TextStyle(fontSize: 12, color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Developer Panel',
                      icon: Icon(Icons.terminal_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 22),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const DeveloperPanelSheet(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // AI Prompt Input & Quick Tuning Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AIPromptCuratorSection(
                  isDark: isDark,
                  controller: _promptController,
                  onSubmit: _submitPrompt,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Musical Archetype Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AIArchetypeCard(
                  isDark: isDark,
                  archetype: archetype,
                  dominantAxes: dominantAxes,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // Results Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI CURATED SOUNDTRACK',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    if (_isLoading)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Text('${_curatedResults.length} Tracks Ranked', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ),
              ),
            ),

            // Curated Song List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = _curatedResults[i];
                    final song = item['song'];
                    final match = item['matchPercentage'] ?? 90;
                    final explanation = item['explanation'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        radius: 16,
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          ref.read(audioPlayerServiceProvider).playSong(song);
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                song.artworkUrl ?? '',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, st) => Container(width: 48, height: 48, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    explanation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$match%',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _curatedResults.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
