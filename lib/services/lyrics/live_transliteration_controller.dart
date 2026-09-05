import 'dart:async';
import 'package:flutter/foundation.dart';
import 'devanagari_transliteration_service.dart';

/// Drives live, as-you-type Roman -> Devanagari conversion for a text field.
///
/// Usage:
/// ```dart
/// final controller = LiveTransliterationController();
///
/// TextField(
///   onChanged: controller.onTextChanged,
/// );
///
/// ValueListenableBuilder<String>(
///   valueListenable: controller.output,
///   builder: (_, devanagariText, __) => Text(devanagariText),
/// );
/// ```
///
/// Design notes:
///   - Debounced: conversion runs [debounce] after the last keystroke, not
///     on every keystroke, so fast typing doesn't cause visible jank or
///     wasted work re-converting a word that's still being typed.
///   - Incremental: only the *last, still-being-typed word* is re-converted
///     each pass; completed earlier words are converted once and cached by
///     the engine, so a long lyric line stays cheap to update as the user
///     keeps typing at the end of it.
class LiveTransliterationController {
  LiveTransliterationController({
    DevanagariTransliterationEngine? engine,
    this.debounce = const Duration(milliseconds: 150),
  }) : engine = engine ?? DevanagariTransliterationEngine();

  final DevanagariTransliterationEngine engine;
  final Duration debounce;

  final ValueNotifier<String> output = ValueNotifier<String>('');

  Timer? _debounceTimer;
  String _lastRawInput = '';
  bool _isDisposed = false;

  void onTextChanged(String rawInput) {
    if (_isDisposed) return;
    _lastRawInput = rawInput;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _convertNow(rawInput));
  }

  /// Force an immediate conversion, bypassing the debounce — call this on
  /// submit/blur so the field is never left showing a stale conversion.
  void flush() {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _convertNow(_lastRawInput);
  }

  void _convertNow(String rawInput) {
    // Guard against a stale timer firing after newer input arrived or after disposal.
    if (_isDisposed || rawInput != _lastRawInput) return;
    output.value = engine.toDevanagari(rawInput);
  }

  /// Call when the user manually corrects a word in the Devanagari output —
  /// wires straight into the engine's learning so it's right from then on.
  void learnCorrection(String romanWord, String correctedDevanagari) {
    if (_isDisposed) return;
    engine.learnWord(romanWord, correctedDevanagari);
    flush();
  }

  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    output.dispose();
  }
}
