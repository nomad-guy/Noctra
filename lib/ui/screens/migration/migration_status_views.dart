import 'package:flutter/material.dart';

class MigrationLoadingView extends StatelessWidget {
  final bool isDark;
  final String status;

  const MigrationLoadingView({
    super.key,
    required this.isDark,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? Colors.white : Colors.black,
          ),
          const SizedBox(height: 16),
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class MigrationCompleteView extends StatelessWidget {
  final bool isDark;
  final int matchedCount;
  final VoidCallback onDone;

  const MigrationCompleteView({
    super.key,
    required this.isDark,
    required this.matchedCount,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Library Imported',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$matchedCount tracks added to your library',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
