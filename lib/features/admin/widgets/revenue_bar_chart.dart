import 'package:flutter/material.dart';

class RevenueBarChart extends StatelessWidget {
  final List<double?> monthlyData; // null for future months
  final int peakIndex;
  final String peakTooltipText;
  final String averageMonthlyText;

  const RevenueBarChart({
    super.key,
    this.monthlyData = const [
      6.2, 4.0, 7.5, 9.8, 11.2, 13.5, 15.0, 16.2, 18.5, null, null, null
    ],
    this.peakIndex = 8, // T9 (0-indexed 8)
    this.peakTooltipText = '● T9: 18.5M đ (Cao nhất)',
    this.averageMonthlyText = 'TB mỗi tháng: 14.020.000 đ',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tooltip container above the peak bar
        Padding(
          padding: const EdgeInsets.only(right: 16.0, bottom: 6.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E60FF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E60FF).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                peakTooltipText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),

        // Custom Bar Chart canvas
        SizedBox(
          height: 155,
          child: CustomPaint(
            size: const Size(double.infinity, 155),
            painter: _BarChartPainter(
              data: monthlyData,
              peakIndex: peakIndex,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Month Labels T1 -> T12
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (index) {
              final isPeak = index == peakIndex;
              final isFuture = index >= 9;
              return SizedBox(
                width: 22,
                child: Text(
                  'T${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                    color: isPeak
                        ? const Color(0xFF1E60FF)
                        : (isFuture ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),

        // Average summary note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚡',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              RichText(
                text: TextSpan(
                  text: 'TB mỗi tháng: ',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475467),
                  ),
                  children: [
                    TextSpan(
                      text: averageMonthlyText.replaceFirst('TB mỗi tháng: ', ''),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double?> data;
  final int peakIndex;

  _BarChartPainter({required this.data, required this.peakIndex});

  @override
  void paint(Canvas canvas, Size size) {
    const double barWidth = 14.0;
    const double radius = 5.0;
    const double paddingHorizontal = 10.0;
    final double availableWidth = size.width - (paddingHorizontal * 2);
    final double stepX = availableWidth / (data.length - 1);
    final double chartHeight = size.height - 10.0;

    // Find max value
    double maxVal = 20.0;
    for (var val in data) {
      if (val != null && val > maxVal) maxVal = val;
    }

    final solidBarColors = [
      const Color(0xFFD0E1FD), // T1
      const Color(0xFFC2D9FC), // T2
      const Color(0xFFB5D2FB), // T3
      const Color(0xFFA5C9FB), // T4
      const Color(0xFF90BCFA), // T5
      const Color(0xFF75ABFA), // T6
      const Color(0xFF5394F8), // T7
      const Color(0xFF387EF5), // T8
      const Color(0xFF1E60FF), // T9 (Peak)
    ];

    for (int i = 0; i < data.length; i++) {
      final double xCenter = paddingHorizontal + (i * stepX);
      final double left = xCenter - (barWidth / 2);
      final double right = xCenter + (barWidth / 2);
      final double? value = data[i];

      if (value != null) {
        // Render solid rounded bar
        final double barHeight = (value / maxVal) * chartHeight;
        final double top = size.height - barHeight;
        final rect = Rect.fromLTRB(left, top, right, size.height);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

        final color = i == peakIndex
            ? const Color(0xFF1E60FF)
            : (i < solidBarColors.length ? solidBarColors[i] : const Color(0xFF75ABFA));

        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rrect, paint);
      } else {
        // Render dashed/dotted placeholder outline for upcoming future months
        final double placeholderHeight = chartHeight * 0.75;
        final double top = size.height - placeholderHeight;
        final rect = Rect.fromLTRB(left, top, right, size.height);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

        final dashedPaint = Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        _drawDashedRRect(canvas, rrect, dashedPaint);
      }
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    final dashPath = _dashPath(path, dashArray: [3.5, 3.5]);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, {required List<double> dashArray}) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      int index = 0;
      while (distance < metric.length) {
        final double len = dashArray[index % dashArray.length];
        if (index % 2 == 0) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        index++;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.peakIndex != peakIndex;
  }
}
