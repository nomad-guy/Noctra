import 'package:flutter/material.dart';

/// Action row shown above an open AI folder/mix: Play All and, for generated
/// vibes, Remix. Owned by [AiCollectionDetailView]; kept in its own file so
/// the detail view stays within the project's LOC budget.
class AiCollectionActionBar extends StatelessWidget {
  final bool isDark;
  final bool canRemix;
  final bool busy;
  final bool hasTracks;
  final VoidCallback onPlayAll;
  final VoidCallback onRemix;

  const AiCollectionActionBar({
    super.key,
    required this.isDark,
    required this.canRemix,
    required this.busy,
    required this.hasTracks,
    required this.onPlayAll,
    required this.onRemix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ActionButton(
            isDark: isDark,
            icon: Icons.play_arrow_rounded,
            label: 'Play All',
            enabled: hasTracks && !busy,
            onTap: onPlayAll,
          ),
          const SizedBox(width: 10),
          if (canRemix)
            _ActionButton(
              isDark: isDark,
              icon: Icons.auto_awesome_rounded,
              label: 'Remix',
              enabled: !busy && hasTracks,
              onTap: onRemix,
            ),
          if (busy) ...[
            const SizedBox(width: 12),
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = isDark ? Colors.white : Colors.black;
    final inactive = isDark ? Colors.white30 : Colors.black26;
    return Material(
      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: enabled ? active : inactive),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: enabled ? active : inactive)),
            ],
          ),
        ),
      ),
    );
  }
}