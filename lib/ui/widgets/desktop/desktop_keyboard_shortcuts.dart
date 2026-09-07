import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/noctra_capabilities.dart';
import '../../../providers/app_providers.dart';

/// Wraps desktop UI with global keyboard shortcut controls.
///
/// Supports Space (Play/Pause), N (Next), P (Previous), Left/Right (Seek ±5s), and M (Mute).
/// Automatically and strictly ignores shortcuts when focus is inside any text input field
/// (TextField, TextFormField, EditableText) or when modifier keys (Ctrl/Alt/Meta) are held.
class DesktopKeyboardShortcuts extends ConsumerWidget {
  final Widget child;

  const DesktopKeyboardShortcuts({super.key, required this.child});

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;

    // Check debug label on focus node
    final label = focus.debugLabel?.toLowerCase() ?? '';
    if (label.contains('editabletext') ||
        label.contains('textfield') ||
        label.contains('textformfield')) {
      return true;
    }

    // Check focus node descendants
    for (final node in focus.descendants) {
      final nodeLabel = node.debugLabel?.toLowerCase() ?? '';
      if (nodeLabel.contains('editabletext') ||
          nodeLabel.contains('textfield') ||
          nodeLabel.contains('textformfield')) {
        return true;
      }
      final ctx = node.context;
      if (ctx != null && (ctx.widget is EditableText || ctx.widget is TextField)) {
        return true;
      }
    }

    final context = focus.context;
    if (context == null) return false;

    // Direct widget check
    if (context.widget is EditableText ||
        context.widget is TextField ||
        context.widget is TextFormField) {
      return true;
    }

    if (context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<TextField>() != null ||
        context.findAncestorWidgetOfExactType<TextFormField>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null) {
      return true;
    }

    // Walk up ancestor elements in the element tree
    bool isEditing = false;
    try {
      context.visitAncestorElements((element) {
        if (element.widget is EditableText ||
            element.widget is TextField ||
            element.widget is TextFormField) {
          isEditing = true;
          return false; // stop visiting
        }
        return true; // continue visiting
      });
    } catch (_) {}
    if (isEditing) return true;

    // Walk down descendant elements in the element tree
    void visitor(Element element) {
      if (isEditing) return;
      if (element.widget is EditableText ||
          element.widget is TextField ||
          element.widget is TextFormField) {
        isEditing = true;
        return;
      }
      element.visitChildren(visitor);
    }

    try {
      (context as Element).visitChildren(visitor);
    } catch (_) {}

    return isEditing;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, WidgetRef ref) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Strictly ignore if user is typing in any text field or input
    if (_isEditingText()) return KeyEventResult.ignored;

    // Ignore if modifier keys are pressed (Ctrl, Alt, Meta/Windows key)
    // to avoid interfering with shortcuts like Ctrl+C, Ctrl+V, Ctrl+A, Alt+Tab, etc.
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

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
