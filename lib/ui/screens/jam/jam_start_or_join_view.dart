import 'package:flutter/material.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../services/p2p/p2p_sync_service.dart';
import '../../../shared/widgets/glass_card.dart';

class JamStartOrJoinView extends StatelessWidget {
  final bool isDark;
  final P2PSyncService syncService;
  final TextEditingController hostIpCtrl;
  final TextEditingController roomSecretCtrl;
  final VoidCallback onHostIpSelected;

  const JamStartOrJoinView({
    super.key,
    required this.isDark,
    required this.syncService,
    required this.hostIpCtrl,
    required this.roomSecretCtrl,
    required this.onHostIpSelected,
  });

  @override
  Widget build(BuildContext context) {
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
                  context.tr(L10nKeys.hostJam),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(L10nKeys.hostJamDesc),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final started = await syncService.startHost();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            started
                                ? 'Jam room started. Share the room secret with your listeners.'
                                : 'Could not start Jam room. Check your network and try again.',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      context.tr(L10nKeys.startHosting),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                      Icon(
                        Icons.wifi_tethering_rounded,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${context.tr(L10nKeys.nearbyRoomsFound)} (${syncService.discoveredRooms.length})',
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
                              hostIpCtrl.text = room.hostIp;
                              onHostIpSelected();
                            },
                            child: Text(context.tr(L10nKeys.select),
                                style: const TextStyle(fontSize: 12)),
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
                  context.tr(L10nKeys.joinJam),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(L10nKeys.joinJamDesc),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hostIpCtrl,
                  decoration: const InputDecoration(
                      hintText: '192.168.43.1 or 127.0.0.1'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roomSecretCtrl,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: context.tr(L10nKeys.roomSecret),
                    helperText: context.tr(L10nKeys.roomSecretHint),
                  ),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final ip = hostIpCtrl.text.trim();
                      final secret = roomSecretCtrl.text.trim();
                      if (ip.isEmpty || secret.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(L10nKeys.enterIpSecretErr),
                            ),
                          ),
                        );
                        return;
                      }
                      final joined =
                          await syncService.joinParty(ip, roomSecret: secret);
                      if (!context.mounted) return;
                      if (!joined) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(L10nKeys.couldNotJoinErr),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      context.tr(L10nKeys.connectSync),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
