import 'package:flutter/material.dart';

/// Small line-chart card showing the driver's last 7 days of earnings.
class EarningsTrendChart extends StatelessWidget {
  final List<double> dailyTotals;

  const EarningsTrendChart({super.key, required this.dailyTotals});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: dailyTotals.every((v) => v == 0)
          ? const Center(
              child: Text(
                "Complete trips to see your trend here.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          : CustomPaint(
              size: Size.infinite,
              painter: _TrendLinePainter(dailyTotals),
            ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> dailyTotals;

  _TrendLinePainter(this.dailyTotals);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2F5BD3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final maxValue = dailyTotals.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final n = dailyTotals.length;

    final points = List<Offset>.generate(n, (i) {
      final x = size.width * (i / (n - 1));
      final ratio = dailyTotals[i] / safeMax;
      final y =
          size.height - (ratio * size.height * 0.85) - (size.height * 0.1);
      return Offset(x, y);
    });

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);

    for (final p in points) {
      canvas.drawCircle(p, 3, Paint()..color = const Color(0xFF2F5BD3));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.dailyTotals != dailyTotals;
}
