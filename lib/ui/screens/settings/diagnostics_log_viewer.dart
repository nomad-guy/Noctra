import 'package:flutter/material.dart';

import '../../../core/utils/noctra_logger.dart';
import '../../../services/platform/diagnostic_log_export_service.dart';

/// Full-screen-ish bottom sheet listing every captured log entry, newest
/// first, with clear + export actions. Shown from Settings > Diagnostics.
class DiagnosticsLogViewer extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCleared;

  const DiagnosticsLogViewer({
    super.key,
    required this.isDark,
    required this.onCleared,
  });

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return const Color(0xFFFF5252);
      case 'WARN':
        return const Color(0xFFFFB74D);
      case 'INFO':
        return const Color(0xFF4FC3F7);
      default:
        return isDark ? Colors.white38 : Colors.black38;
    }
  }

  Color get _fg => isDark ? Colors.white : Colors.black;
  Color get _fg3 => isDark ? Colors.white38 : Colors.black38;

  @override
  Widget build(BuildContext context) {
    final logs = NoctraLogger.recentLogs.reversed.toList(); // newest first
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101010) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Diagnostic Log (${logs.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _fg,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Clear log',
                  icon: Icon(Icons.delete_sweep_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: () {
                    NoctraLogger.clear();
                    onCleared();
                    Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  tooltip: 'Export .txt',
                  icon: Icon(Icons.ios_share_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: () async {
                    final path =
                        await DiagnosticLogExportService.exportLogs();
                    if (context.mounted && path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Log exported: $path')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No log entries',
                      style: TextStyle(fontSize: 12.5, color: _fg3),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      final e = logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: .04)
                                : Colors.black.withValues(alpha: .03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _levelColor(e.level)
                                          .withValues(alpha: .15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      e.level,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .8,
                                        color: _levelColor(e.level),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    e.timestamp.toIso8601String().substring(11, 19),
                                    style: TextStyle(
                                        fontSize: 10, color: _fg3),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              SelectableText(
                                e.error == null
                                    ? e.message
                                    : '${e.message}  =>  ${e.error}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    color: _fg.withValues(alpha: .85)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
