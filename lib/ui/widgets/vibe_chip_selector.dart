import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';

class VibeChipSelector extends ConsumerWidget {
  const VibeChipSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.noctraTokens;
    final selectedVibe = ref.watch(selectedVibeKeyProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final repo = ref.watch(musicRepositoryProvider);

    final vibes = repo.getDynamicVibeChips();

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: vibes.map((vibe) {
            final isSelected = selectedVibe == vibe.keyName;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(
                  vibe.iconData,
                  size: 16,
                  color: isSelected
                      ? (t.primaryText)
                      : (t.secondaryText),
                ),
                label: Text(vibe.label),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  ref.read(selectedVibeKeyProvider.notifier).state = vibe.keyName;
                },
                backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFE5E5E5),
                selectedColor: t.primaryText,
                labelStyle: TextStyle(
                  color: isSelected
                      ? (t.primaryText)
                      : (isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isSelected
                        ? (t.primaryText)
                        : (t.tertiaryText),
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
