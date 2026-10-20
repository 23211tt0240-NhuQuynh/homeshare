import 'package:flutter/material.dart';

class RevenueLineChart extends StatelessWidget {
  final List<double> weeklyData;
  final List<String> labels;
  final int activeIndex;

  const RevenueLineChart({
    super.key,
    this.weeklyData = const [0, 0, 0, 0, 0, 0, 0],
    this.labels = const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
    this.activeIndex = 0, // điểm được nhấn mạnh (vd: hôm nay)
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(double.infinity, 170),
                painter: _SplineLineChartPainter(
                  data: weeklyData,
                  activeIndex: activeIndex,
                ),
              ),
              if (weeklyData.every((v) => v <= 0))
                const Text(
                  'Chưa có doanh thu',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(labels.length, (index) {
              final isSelected = index == activeIndex;
              return Text(
                labels[index],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF398FC0) : const Color(0xFF64748B),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SplineLineChartPainter extends CustomPainter {
  final List<double> data;
  final int activeIndex;

  _SplineLineChartPainter({required this.data, required this.activeIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final double paddingBottom = 16.0;
    final double paddingTop = 16.0;
    final double paddingHorizontal = 16.0;

    final double chartWidth = size.width - (paddingHorizontal * 2);
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Draw background horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 3; i++) {
      final y = paddingTop + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(paddingHorizontal, y),
        Offset(size.width - paddingHorizontal, y),
        gridPaint,
      );
    }

    // Luôn lấy mốc 0 làm đáy để không phóng đại chênh lệch nhỏ
    const double minVal = 0;
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double range = maxVal <= 0 ? 1 : maxVal;

    // Compute coordinate points
    final List<Offset> points = [];
    final double stepX = chartWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final double normalized = (data[i] - minVal) / range;
      // Invert Y for canvas coordinate system (0 is top)
      final double x = paddingHorizontal + (i * stepX);
      final double y = paddingTop + (chartHeight * (1.0 - (normalized * 0.85 + 0.1)));
      points.add(Offset(x, y));
    }

    // Build smooth cubic bezier curve
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Gradient fill under the curve
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height - paddingBottom);
    fillPath.lineTo(points.first.dx, size.height - paddingBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF398FC0).withValues(alpha: 0.28),
          const Color(0xFF89CFF0).withValues(alpha: 0.12),
          const Color(0xFF89CFF0).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, paddingTop, size.width, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    // Draw main line stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF398FC0)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Draw data circles
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isPeak = i == activeIndex;

      if (isPeak) {
        // Outer halo / glow for active point
        final haloPaint = Paint()
          ..color = const Color(0xFF398FC0).withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 10.0, haloPaint);

        // Active outer ring
        final activeRingPaint = Paint()
          ..color = const Color(0xFF398FC0)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(p, 6.5, activeRingPaint);

        // Active inner center
        final centerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 4.5, centerPaint);

        final dotCenter = Paint()
          ..color = const Color(0xFF398FC0)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 2.5, dotCenter);
      } else {
        // Regular point: white circle with blue stroke
        final dotBg = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 4.5, dotBg);

        final dotStroke = Paint()
          ..color = const Color(0xFF398FC0)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(p, 4.5, dotStroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplineLineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.activeIndex != activeIndex;
  }
}
