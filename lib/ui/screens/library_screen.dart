import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../providers/app_providers.dart';
import '../widgets/synccast_sheet.dart';
import '../widgets/library_folders_tab.dart';
import '../widgets/library_all_songs_tab.dart';
import '../widgets/library_ai_mixes_tab.dart';
import 'migration_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);
    final downloads = repo.downloads;
    final allSongs = repo.localLibrary;
    final customFolders = repo.customFolders;
    final syncService = ref.watch(p2pSyncServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : Colors.black, size: 24),
                    tooltip: context.tr(L10nKeys.openSidebar),
                    onPressed: () => ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.tr(L10nKeys.libraryTitle),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr(L10nKeys.importMigrateLibrary),
                    icon: Icon(Icons.file_download_outlined, color: isDark ? Colors.white60 : Colors.black54, size: 22),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const MigrationScreen(),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: context.tr(L10nKeys.partyMode),
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
                        useRootNavigator: true,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const SyncCastSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Top Section 3 Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: isDark ? Colors.black : Colors.white,
                  unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                  labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: context.tr(L10nKeys.aiMixes)),
                    Tab(text: context.tr(L10nKeys.folders)),
                    Tab(text: context.tr(L10nKeys.downloads)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  LibraryAIMixesTab(
                    isDark: isDark,
                    repo: repo,
                  ),
                  LibraryFoldersTab(
                    isDark: isDark,
                    repo: repo,
                    customFolders: customFolders,
                    allSongs: allSongs,
                  ),
                  LibraryAllSongsTab(
                    isDark: isDark,
                    repo: repo,
                    allSongs: allSongs,
                    downloads: downloads,
                    customFolders: customFolders,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
