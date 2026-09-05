import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import 'noctra_app_logo.dart';
import 'dev_credits_tab.dart';
import 'dev_diagnostics_tab.dart';

class DeveloperPanelSheet extends ConsumerStatefulWidget {
  const DeveloperPanelSheet({super.key});

  @override
  ConsumerState<DeveloperPanelSheet> createState() => _DeveloperPanelSheetState();
}

class _DeveloperPanelSheetState extends ConsumerState<DeveloperPanelSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tasteVector = ref.watch(tasteVectorStateProvider);
    final currentSong = ref.watch(currentSongStreamProvider).value;
    final telemetry = ref.watch(streamResolutionStreamProvider).value;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF4080808) : const Color(0xF4FFFFFF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    NoctraAppLogo(size: 36, radius: 9, isDark: isDark),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Noctra Developer Suite',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Engineering Credits & System Diagnostics',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tabs
            Container(
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
                tabs: const [
                  Tab(text: 'Developer & Architecture'),
                  Tab(text: 'Diagnostics & ML Vector'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  DevCreditsTab(isDark: isDark),
                  DevDiagnosticsTab(
                    isDark: isDark,
                    tasteVector: tasteVector,
                    currentSong: currentSong,
                    telemetry: telemetry,
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
