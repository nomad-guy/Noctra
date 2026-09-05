import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/sources/noctra_local_database.dart';

final isOfflineModeProvider = StateProvider<bool>((ref) {
  return NoctraLocalDatabase().getCachedOfflineMode();
});

void toggleOfflineMode(WidgetRef ref) {
  HapticFeedback.mediumImpact();
  final current = ref.read(isOfflineModeProvider);
  final next = !current;
  ref.read(isOfflineModeProvider.notifier).state = next;
  NoctraLocalDatabase().saveOfflineMode(next);
}

void setOfflineMode(WidgetRef ref, bool enabled) {
  HapticFeedback.selectionClick();
  ref.read(isOfflineModeProvider.notifier).state = enabled;
  NoctraLocalDatabase().saveOfflineMode(enabled);
}
