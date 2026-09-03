import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/p2p/p2p_sync_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/jam_queue_tab.dart';
import '../widgets/jam_chat_tab.dart';
import '../widgets/jam_host_controls_tab.dart';

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
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white : Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!isConnected)
              Expanded(child: _buildStartOrJoinView(isDark, syncService))
            else ...[
              // Connected Tabs
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

  Widget _buildStartOrJoinView(bool isDark, P2PSyncService syncService) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Host a Jam Session',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start a room over your local Wi-Fi / Hotspot. Other devices can join without any cloud server.',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final started = await syncService.startHost();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(started
                              ? 'Jam room started. Share the room secret with your listeners.'
                              : 'Could not start Jam room. Check your network and try again.'),
                        ),
                      );
                    },
                    child: const Text('Start Hosting Jam Session',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          if (syncService.discoveredRooms.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_tethering_rounded,
                          size: 16,
                          color: isDark ? Colors.white : Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        'Nearby Rooms Found (${syncService.discoveredRooms.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...syncService.discoveredRooms.map((room) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${room.hostName} (${room.roomCode})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  '${room.hostIp}:${room.port}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _hostIpCtrl.text = room.hostIp;
                              });
                            },
                            child: const Text('Select',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join an Existing Jam Room',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the host device IP and the room secret shown on their screen.',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hostIpCtrl,
                  decoration: const InputDecoration(
                      hintText: '192.168.43.1 or 127.0.0.1'),
                  style: TextStyle(
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _roomSecretCtrl,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Room secret',
                    helperText: 'Required — authenticates you to the host.',
                  ),
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final ip = _hostIpCtrl.text.trim();
                      final secret = _roomSecretCtrl.text.trim();
                      if (ip.isEmpty || secret.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Enter both the host IP and the room secret.')),
                          );
                        }
                        return;
                      }
                      final joined =
                          await syncService.joinParty(ip, roomSecret: secret);
                      if (!mounted) return;
                      if (!joined) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Could not join. Check the IP and room secret, and confirm the host is online.'),
                          ),
                        );
                      }
                    },
                    child: Text('Connect & Sync Audio',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
