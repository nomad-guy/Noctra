import 'dart:math';
import 'package:flutter/material.dart';

/// A minimal sparkline chart for visualizing neural network training loss.
class NeuralMiniChart extends StatelessWidget {
  final List<double> lossHistory;
  final bool isDark;

  const NeuralMiniChart({super.key, required this.lossHistory, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    if (lossHistory.isEmpty) {
      return Center(
        child: Text(
          'Collecting training data...',
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
        ),
      );
    }

    return CustomPaint(
      painter: _SparklinePainter(data: lossHistory, isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final bool isDark;

  _SparklinePainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final minVal = data.reduce(min);
    final maxVal = data.reduce(max);
    final range = (maxVal - minVal).clamp(0.001, double.infinity);

    final path = Path();
    final gradientPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * (size.height - 4) - 2;

      if (i == 0) {
        path.moveTo(x, y);
        gradientPath.moveTo(x, size.height);
        gradientPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        gradientPath.lineTo(x, y);
      }
    }

    // Gradient fill under the line
    gradientPath.lineTo(size.width, size.height);
    gradientPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        (isDark ? Colors.cyanAccent : Colors.blue).withValues(alpha: 0.15),
        (isDark ? Colors.cyanAccent : Colors.blue).withValues(alpha: 0.0),
      ],
    );

    canvas.drawPath(
      gradientPath,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    paint.color = isDark ? Colors.cyanAccent : Colors.blue;
    canvas.drawPath(path, paint);

    // Current value dot
    final lastX = size.width;
    final lastY = size.height - ((data.last - minVal) / range) * (size.height - 4) - 2;
    canvas.drawCircle(
      Offset(lastX, lastY),
      2.5,
      Paint()..color = isDark ? Colors.cyanAccent : Colors.blue,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.data != data;
}
