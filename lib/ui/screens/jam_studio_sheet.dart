import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/p2p/p2p_sync_service.dart';
import '../widgets/jam_chat_tab.dart';
import '../widgets/jam_host_controls_tab.dart';
import '../widgets/jam_queue_tab.dart';
import 'jam/jam_start_or_join_view.dart';

class JamStudioSheet extends ConsumerStatefulWidget {
  const JamStudioSheet({super.key});

  @override
  ConsumerState<JamStudioSheet> createState() => _JamStudioSheetState();
}

class _JamStudioSheetState extends ConsumerState<JamStudioSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _hostIpCtrl = TextEditingController();
  final TextEditingController _roomSecretCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(p2pSyncServiceProvider).startDiscovery();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostIpCtrl.dispose();
    _roomSecretCtrl.dispose();
    ref.read(p2pSyncServiceProvider).stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final syncService = ref.watch(p2pSyncServiceProvider);
    final isConnected = syncService.isHost || syncService.isClient;

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
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Noctra Jam Studio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? NoirColors.blackTextPrimary
                              : NoirColors.whiteTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Serverless P2P Synchronized Audio & Live Chat Mesh',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? NoirColors.blackTextSecondary
                              : NoirColors.whiteTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isConnected)
              Expanded(
                child: JamStartOrJoinView(
                  isDark: isDark,
                  syncService: syncService,
                  hostIpCtrl: _hostIpCtrl,
                  roomSecretCtrl: _roomSecretCtrl,
                  onHostIpSelected: () => setState(() {}),
                ),
              )
            else ...[
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
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
                  unselectedLabelColor:
                      isDark ? Colors.white60 : Colors.black54,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Shared Queue'),
                    Tab(text: 'Live P2P Chat'),
                    Tab(text: 'Room Controls'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    JamQueueTab(isDark: isDark, syncService: syncService),
                    JamChatTab(isDark: isDark, syncService: syncService),
                    JamHostControlsTab(
                        isDark: isDark, syncService: syncService),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
