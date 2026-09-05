import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../services/p2p/p2p_sync_service.dart';
import '../../shared/widgets/glass_card.dart';


class JamHostControlsTab extends ConsumerWidget {
  final bool isDark;
  final P2PSyncService syncService;

  const JamHostControlsTab({
    super.key,
    required this.isDark,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHost = syncService.isHost;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Code Card
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROOM CODE',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      syncService.roomCode,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: isDark ? Colors.white : Colors.black),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy_rounded,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: syncService.roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  context.tr(L10nKeys.roomCodeCopied, {'code': syncService.roomCode}))),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  isHost
                      ? 'Host IP: ${syncService.localIp ?? "127.0.0.1"}:${syncService.port}'
                      : 'Host IP: ${syncService.connectedHostIp ?? "127.0.0.1"}:${syncService.port}',
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),

          // Room Secret Card (host only) — this is the real credential
          // listeners must enter when joining.
          if (isHost) ...[
            const SizedBox(height: 14),
            GlassCard(
              radius: 16,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROOM SECRET (REQUIRED TO JOIN)',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          syncService.roomSecret,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              height: 1.5,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy_rounded,
                            color: isDark ? Colors.white : Colors.black),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: syncService.roomSecret));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    context.tr(L10nKeys.roomSecretCopied))),
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    'Keep this secret private. Anyone who has it can join your room.',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white38 : Colors.black45),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Host Permission Switch
          if (isHost)
            GlassCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr(L10nKeys.hostControlsOnly),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black),
                ),
                subtitle: Text(
                  context.tr(L10nKeys.hostControlsDesc),
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54),
                ),
                value: syncService.hostControlsOnly,
                activeThumbColor: isDark ? Colors.white : Colors.black,
                onChanged: (_) {
                  syncService.toggleHostControlsOnly();
                },
              ),
            ),

          const SizedBox(height: 14),

          // End / Leave Session
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side:
                    BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                await syncService.stopParty();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                isHost ? context.tr(L10nKeys.endJamSession) : context.tr(L10nKeys.leaveJamRoom),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
