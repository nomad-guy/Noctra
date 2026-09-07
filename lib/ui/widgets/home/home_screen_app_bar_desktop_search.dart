import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/noir_theme.dart';
import '../../../providers/app_providers.dart';

class HomeScreenAppBarDesktopSearch extends ConsumerWidget {
  final bool isDark;

  const HomeScreenAppBarDesktopSearch({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.noctraTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: tokens.surfaceVariant.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.subtleBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_rounded, size: 16, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                'Discover Feed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: isDark
                      ? NoirColors.blackTextPrimary
                      : NoirColors.whiteTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(currentNavigationIndexProvider.notifier).state = 1;
          },
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.subtleBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    size: 16, color: isDark ? Colors.white54 : Colors.black45),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search songs, artists, albums...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x22FFFFFF)
                        : const Color(0x14000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ctrl+K',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
