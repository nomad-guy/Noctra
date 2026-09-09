import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  bool _hasRenderEditable(RenderObject? ro) {
    if (ro == null) return false;
    if (ro is RenderEditable) return true;
    bool found = false;
    ro.visitChildren((child) {
      if (!found && _hasRenderEditable(child)) {
        found = true;
      }
    });
    return found;
  }

  bool _isNodeEditing(FocusNode node) {
    final context = node.context;
    if (context == null) return false;

    // Direct widget or ancestor widget check
    if (context.widget is EditableText ||
        context.widget is TextField ||
        context.widget is TextFormField ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<TextField>() != null ||
        context.findAncestorWidgetOfExactType<TextFormField>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null) {
      return true;
    }

    // RenderObject check: RenderEditable is always the underlying render object of text inputs
    final renderObject = context.findRenderObject();
    if (_hasRenderEditable(renderObject)) {
      return true;
    }

    // Walk up ancestor elements in the element tree
    bool isEditing = false;
    try {
      context.visitAncestorElements((element) {
        if (element.widget is EditableText ||
            element.widget is TextField ||
            element.widget is TextFormField ||
            element is StatefulElement && element.state is EditableTextState) {
          isEditing = true;
          return false;
        }
        return true;
      });
    } catch (_) {}
    return isEditing;
  }

  bool _isEditingText(FocusNode shortcutNode) {
    FocusNode? active = FocusManager.instance.primaryFocus;
    if (active == null || active == shortcutNode) return false;

    // If focused node is a FocusScopeNode, resolve to its leaf focused child
    while (active is FocusScopeNode && active.focusedChild != null) {
      active = active.focusedChild;
    }
    if (active == null || active == shortcutNode) return false;

    // Check debug label on focus node (works in debug/profile mode)
    final label = active.debugLabel?.toLowerCase() ?? '';
    if (label.contains('editabletext') ||
        label.contains('textfield') ||
        label.contains('textformfield')) {
      return true;
    }

    if (_isNodeEditing(active)) return true;

    // Check focus node descendants
    for (final desc in active.descendants) {
      if (_isNodeEditing(desc)) return true;
    }

    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, WidgetRef ref) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Strictly ignore if user is typing in any text field or input
    if (_isEditingText(node)) return KeyEventResult.ignored;

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
