import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../services/p2p/p2p_sync_service.dart';
import '../../core/theme/noir_theme.dart';

class JamChatTab extends ConsumerStatefulWidget {
  final bool isDark;
  final P2PSyncService syncService;

  const JamChatTab({
    super.key,
    required this.isDark,
    required this.syncService,
  });

  @override
  ConsumerState<JamChatTab> createState() => _JamChatTabState();
}

class _JamChatTabState extends ConsumerState<JamChatTab> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    final messages = widget.syncService.chatMessages;

    return Column(
      children: [
        // Message Feed
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 36, color: t.tertiaryText),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(L10nKeys.noMessagesSession),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: t.tertiaryText),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isSelf = msg.senderName == widget.syncService.userName;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelf
                                  ? (t.primaryText)
                                  : (widget.isDark ? const Color(0xFF181818) : const Color(0xFFEBEBEB)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelf
                                        ? (t.secondaryText)
                                        : (t.secondaryText),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelf
                                        ? (t.primaryText)
                                        : (t.primaryText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Message Input
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF141414) : const Color(0xFFEBEBEB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr(L10nKeys.typeMessage),
                      hintStyle: TextStyle(fontSize: 12.5, color: t.tertiaryText),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    style: TextStyle(fontSize: 13, color: t.primaryText),
                    onSubmitted: (val) {
                      _sendMessage();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: t.primaryText,
                  foregroundColor: t.primaryText,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    final txt = _msgCtrl.text.trim();
    if (txt.isNotEmpty) {
      widget.syncService.sendChatMessage(txt);
      _msgCtrl.clear();
      setState(() {});
    }
  }
}
