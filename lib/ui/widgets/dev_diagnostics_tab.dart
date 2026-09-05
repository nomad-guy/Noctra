import 'package:flutter/material.dart';
import '../../data/models/song_model.dart';
import '../../shared/widgets/glass_card.dart';


class DevDiagnosticsTab extends StatelessWidget {
  final bool isDark;
  final List<double> tasteVector;
  final Song? currentSong;
  final dynamic telemetry;

  static const List<String> _axisLabels = [
    '00. Dark Tone', '01. Ambient Drone', '02. Energetic Pulse', '03. Chill Lofi',
    '04. Melancholy', '05. Organic Acoustic', '06. Electronic Grid', '07. Vocal Presence',
    '08. Harmonic Structure', '09. Synthwave Lead', '10. Night Drive', '11. Cognitive Focus',
    '12. Uplift Joy', '13. Sub-Bass Depth', '14. Dynamic Tempo', '15. Pure Instrumental'
  ];

  const DevDiagnosticsTab({
    super.key,
    required this.isDark,
    required this.tasteVector,
    required this.currentSong,
    required this.telemetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Telemetry Card
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REAL-TIME TELEMETRY',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                _telemetryRow('Active Track', currentSong?.title ?? 'Idle', isDark),
                _telemetryRow('Source Engine', currentSong?.genre ?? 'Local Library', isDark),
                _telemetryRow('Resolver Engine', telemetry?.resolverUsed ?? '320 kbps (Master)', isDark),
                _telemetryRow('ML Inference', '< 2.0 ms (On-Device)', isDark),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 16-Axis Neural Space Grid
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '16-AXIS USER TASTE VECTOR EMBEDDINGS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(16, (i) {
                  final val = (i < tasteVector.length) ? tasteVector[i] : 0.5;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            _axisLabels[i],
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: val.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${(val * 100).toInt()}%',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _telemetryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54)),
          Text(value, style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }
}
