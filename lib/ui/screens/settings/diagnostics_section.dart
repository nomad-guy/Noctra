import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/noctra_logger.dart';
import '../../../services/platform/diagnostic_log_export_service.dart';
import '../../../shared/widgets/glass_card.dart';
import 'diagnostics_log_viewer.dart';

/// Settings > Diagnostics: runtime log capture with .txt export.
///
/// Every uncaught runtime error is captured automatically (see
/// [NoctraLogger.install]); this surface lets users inspect and export the
/// captured log for bug reports.
class DiagnosticsSection extends ConsumerStatefulWidget {
  final bool isDark;

  const DiagnosticsSection({super.key, required this.isDark});

  @override
  ConsumerState<DiagnosticsSection> createState() =>
      _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends ConsumerState<DiagnosticsSection> {
  int _refreshTick = 0;

  bool get _isDark => widget.isDark;

  Color get _fg => _isDark ? Colors.white : Colors.black;
  Color get _fg2 => _isDark ? Colors.white60 : Colors.black54;

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return const Color(0xFFFF5252);
      case 'WARN':
        return const Color(0xFFFFB74D);
      case 'INFO':
        return const Color(0xFF4FC3F7);
      default:
        return _isDark ? Colors.white38 : Colors.black38;
    }
  }

  Future<void> _export() async {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    final path = await DiagnosticLogExportService.exportLogs();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
          content: Text(path != null
              ? 'Log exported: $path'
              : 'Export cancelled')),
    );
  }

  void _clear() {
    HapticFeedback.lightImpact();
    NoctraLogger.clear();
    setState(() => _refreshTick++);
  }

  void _openViewer() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiagnosticsLogViewer(
        isDark: _isDark,
        onCleared: () => setState(() => _refreshTick++),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = NoctraLogger.recentLogs; // newest last; stats don't care
    return Column(
      key: ValueKey(_refreshTick),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIAGNOSTICS & LOGS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _fg2,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report_rounded,
                      size: 18, color: _levelColor('WARN')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Runtime Diagnostics',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Captures runtime errors, playback issues and '
                          'resolver failures automatically',
                          style: TextStyle(fontSize: 11.5, color: _fg2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _LogStat('${logs.length}', 'entries', _fg),
                  const SizedBox(width: 8),
                  _LogStat(
                    '${logs.where((l) => l.level == 'ERROR').length}',
                    'errors',
                    _levelColor('ERROR'),
                  ),
                  const SizedBox(width: 8),
                  _LogStat(
                    '${logs.where((l) => l.level == 'WARN').length}',
                    'warnings',
                    _levelColor('WARN'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: BorderSide(color: _fg.withValues(alpha: .25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.ios_share_rounded,
                          size: 16, color: _fg),
                      label: Text(
                        'Export .txt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _fg,
                        ),
                      ),
                      onPressed: logs.isEmpty ? null : _export,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: BorderSide(color: _fg.withValues(alpha: .25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.visibility_rounded,
                          size: 16, color: _fg),
                      label: Text(
                        'View',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _fg,
                        ),
                      ),
                      onPressed: logs.isEmpty ? null : _openViewer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: BorderSide(color: _fg.withValues(alpha: .25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.delete_sweep_rounded,
                          size: 16, color: _fg),
                      label: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _fg,
                        ),
                      ),
                      onPressed: logs.isEmpty ? null : _clear,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _LogStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: .8),
            ),
          ),
        ],
      ),
    );
  }
}
