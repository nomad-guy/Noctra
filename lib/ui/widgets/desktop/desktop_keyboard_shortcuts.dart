import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/noctra_capabilities.dart';
import '../../../providers/app_providers.dart';

/// Wraps desktop UI with global keyboard shortcut controls.
///
/// Supports Space (Play/Pause), N (Next), P (Previous), Left/Right (Seek ±5s), and M (Mute).
/// Automatically ignores shortcuts when focus is inside a text input field.
class DesktopKeyboardShortcuts extends ConsumerWidget {
  final Widget child;

  const DesktopKeyboardShortcuts({super.key, required this.child});

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final widget = focus.context?.widget;
    return widget is EditableText;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, WidgetRef ref) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditingText()) return KeyEventResult.ignored;

    final player = ref.read(audioPlayerServiceProvider);

    if (event.logicalKey == LogicalKeyboardKey.space) {
      player.togglePlayPause();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyN) {
      player.skipNext();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
      player.skipPrevious();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final pos = player.player.position;
      final dur = player.player.duration ?? Duration.zero;
      final target = pos + const Duration(seconds: 5);
      player.seek(target < dur ? target : dur);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final pos = player.player.position;
      final target = pos - const Duration(seconds: 5);
      player.seek(target > Duration.zero ? target : Duration.zero);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      final currentVol = player.player.volume;
      player.setVolume(currentVol > 0 ? 0.0 : 1.0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!NoctraCapabilities.isDesktop) return child;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, ref),
      child: child,
    );
  }
}
