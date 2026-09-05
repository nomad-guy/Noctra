import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/latest_request_gate.dart';
import '../../providers/app_providers.dart';
import '../../services/ai/candidate_retrieval_service.dart';
import '../widgets/developer_panel_sheet.dart';
import 'ai_studio_sections.dart';

class AIStudioScreen extends ConsumerStatefulWidget {
  const AIStudioScreen({super.key});
  @override
  ConsumerState<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends ConsumerState<AIStudioScreen> {
  final _promptController = TextEditingController();
  final _requestGate = LatestRequestGate();
  var _isLoading = false;
  var _activeChip = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _requestGate.invalidate();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _load({String? prompt, String? vibeKey}) async {
    final generation = _requestGate.begin();
    setState(() {
      _isLoading = true;
      _activeChip = vibeKey ?? '';
    });
    try {
      final current = ref.read(currentSongStreamProvider).value;
      final results = await CandidateRetrievalService.curatePersonalizedFeed(
        naturalPrompt: prompt,
        vibeKey: vibeKey,
        seedSong: prompt?.toLowerCase().contains('like this') == true
            ? current
            : null,
        targetCount: 15,
      ).timeout(const Duration(seconds: 10));
      if (mounted && _requestGate.isCurrent(generation)) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _requestGate.isCurrent(generation)) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _submitPrompt(String raw) {
    final prompt = raw.trim();
    if (prompt.isNotEmpty) _load(prompt: prompt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider).isDark;
    final repo = ref.watch(musicRepositoryProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(isDark)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _promptField(isDark)),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: AiStudioSections(
                isDark: isDark,
                activeChip: _activeChip,
                results: _results,
                archetype: repo.getUserMusicalArchetype(),
                dominantAxes: repo.getDominantAxes(),
                onChip: (vibe) {
                  _promptController.clear();
                  _load(vibeKey: vibe);
                },
                onPlay: (song, queue) => ref
                    .read(audioPlayerServiceProvider)
                    .playSong(song, newQueue: queue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.menu_rounded,
                color: isDark ? Colors.white : Colors.black),
            onPressed: () =>
                ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
          ),
          Expanded(
              child: Text('AI Studio',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? NoirColors.blackTextPrimary
                          : NoirColors.whiteTextPrimary))),
          IconButton(
            icon: Icon(Icons.terminal_rounded,
                color: isDark ? Colors.white54 : Colors.black54),
            onPressed: _openDeveloperPanel,
          ),
        ]),
      );

  Widget _promptField(bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _promptController,
          onSubmitted: _submitPrompt,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'What are you in the mood for?',
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => _submitPrompt(_promptController.text)),
          ),
        ),
      );

  void _openDeveloperPanel() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const DeveloperPanelSheet(),
      );
}
