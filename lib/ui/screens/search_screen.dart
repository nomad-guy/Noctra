import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/developer_panel_sheet.dart';
import '../widgets/synccast_sheet.dart';
import '../widgets/search_results_list.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _selectedSource = 'all';

  int _searchSequence = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchSequence++;
      ref.read(searchResultsProvider.notifier).state = [];
      ref.read(isSearchingProvider.notifier).state = false;
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(clean);
    });
  }

  Future<void> _performSearch(String query) async {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) return;
    final seq = ++_searchSequence;
    ref.read(isSearchingProvider.notifier).state = true;
    ref.read(searchQueryProvider.notifier).state = clean;

    try {
      final coordinator = ref.read(searchCoordinatorProvider);
      final results = await coordinator.executeSearch(
        clean,
        source: _selectedSource,
        executionId: seq,
      );
      if (_searchSequence == seq && mounted) {
        ref.read(searchResultsProvider.notifier).state = results;
      }
    } finally {
      if (_searchSequence == seq && mounted) {
        ref.read(isSearchingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final isSearching = ref.watch(isSearchingProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final catalogTopics = ref.watch(dynamicCatalogTopicsProvider);
    final syncService = ref.watch(p2pSyncServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu_rounded,
                        color: isDark ? Colors.white : Colors.black, size: 24),
                    tooltip: 'Open Sidebar',
                    onPressed: () => ref
                        .read(rootScaffoldKeyProvider)
                        .currentState
                        ?.openDrawer(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Search & Explore',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? NoirColors.blackTextPrimary
                            : NoirColors.whiteTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'SyncCast Party Mode',
                    icon: Icon(
                      Icons.podcasts_rounded,
                      color: syncService.isHost || syncService.isClient
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white60 : Colors.black54),
                      size: 22,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const SyncCastSheet(),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Developer Suite',
                    icon: Icon(Icons.terminal_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22),
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

            // Live As-You-Type Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141414)
                      : const Color(0xFFEBEBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _performSearch,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, or paste URL...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: isDark ? Colors.white60 : Colors.black54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                size: 18,
                                color:
                                    isDark ? Colors.white60 : Colors.black54),
                            onPressed: () {
                              _searchSequence++;
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              ref.read(searchResultsProvider.notifier).state =
                                  [];
                              ref.read(isSearchingProvider.notifier).state =
                                  false;
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Catalog quality filters. Provider identifiers stay internal.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _sourceChip('All Catalog', 'all', isDark),
                    const SizedBox(width: 8),
                    _sourceChip('High Fidelity', 'saavn', isDark),
                    const SizedBox(width: 8),
                    _sourceChip('Extended Catalog', 'ytmusic', isDark),
                  ],
                ),
              ),
            ),

            // Results List
            Expanded(
              child: SearchResultsList(
                isDark: isDark,
                searchResults: searchResults,
                isSearching: isSearching,
                catalogTopics: catalogTopics.asData?.value,
                isLoadingCatalogTopics: catalogTopics.isLoading,
                onGenreTap: (query) {
                  _searchController.text = query;
                  _performSearch(query);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceChip(String label, String sourceKey, bool isDark) {
    final isSelected = _selectedSource == sourceKey;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSource = sourceKey);
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
