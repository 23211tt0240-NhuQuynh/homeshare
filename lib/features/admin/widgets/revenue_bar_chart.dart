import '../theme/admin_colors.dart';
import 'package:flutter/material.dart';

/// Biểu đồ doanh thu theo năm.
/// [monthlyData]: 12 phần tử, đơn vị = triệu đồng. null = chưa có dữ liệu.
/// Đỉnh (cao nhất) và trung bình được TÍNH từ dữ liệu, không hardcode.
class RevenueBarChart extends StatelessWidget {
  final List<double?> monthlyData;

  const RevenueBarChart({
    super.key,
    this.monthlyData = const [
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
  });

  /// 1.234.567 (đ)
  static String _formatVnd(double vnd) {
    final s = vnd.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final int currentMonth = now.month; // 1..12

    // Chỉ tính các tháng đã qua/đang diễn ra
    double total = 0;
    double maxVal = 0;
    int peakIndex = -1;
    for (int i = 0; i < monthlyData.length && i < currentMonth; i++) {
      final v = monthlyData[i] ?? 0;
      total += v;
      if (v > maxVal) {
        maxVal = v;
        peakIndex = i;
      }
    }
    final double peakVnd = maxVal * 1000000;
    final bool hasData = maxVal > 0;
    final double avgVnd = (total / currentMonth) * 1000000;

    final String peakText = hasData
        ? '● T${peakIndex + 1}: ${_formatVnd(peakVnd)} đ (Cao nhất)'
        : '';
    final String avgText = '${_formatVnd(avgVnd)} đ';

    // Căn tooltip theo vị trí cột đỉnh
    final double tooltipAlignX = hasData
        ? (-1 + 2 * peakIndex / (monthlyData.length - 1))
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tooltip: chỉ hiện khi thực sự có doanh thu
        SizedBox(
          height: 30,
          child: hasData
              ? Align(
                  alignment: Alignment(tooltipAlignX.clamp(-0.7, 1.0), 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF398FC0,
                          ).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      peakText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        SizedBox(
          height: 155,
          child: CustomPaint(
            size: const Size(double.infinity, 155),
            painter: _BarChartPainter(
              data: monthlyData,
              peakIndex: peakIndex,
              currentMonth: currentMonth,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Nhãn T1 -> T12
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (index) {
              final isPeak = index == peakIndex;
              final isFuture = index >= currentMonth;
              return SizedBox(
                width: 22,
                child: Text(
                  'T${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                    color: isPeak
                        ? AdminColors.accent
                        : (isFuture
                              ? AdminColors.muted
                              : AdminColors.muted),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),

        // Trung bình mỗi tháng (tính từ dữ liệu thật)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminColors.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              RichText(
                text: TextSpan(
                  text: 'TB mỗi tháng: ',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.muted,
                  ),
                  children: [
                    TextSpan(
                      text: avgText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.ink,
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
  final int peakIndex; // -1 nếu chưa có dữ liệu
  final int currentMonth;

  _BarChartPainter({
    required this.data,
    required this.peakIndex,
    required this.currentMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    if (size.width <= 0 || size.height <= 0) return;

    const double barWidth = 14.0;
    const double radius = 5.0;
    const double paddingHorizontal = 10.0;
    final double availableWidth = size.width - (paddingHorizontal * 2);
    if (availableWidth <= 0) return;

    final double stepX = availableWidth / (data.length - 1);
    final double chartHeight = size.height - 10.0;
    if (chartHeight <= 0) return;

    double maxVal = 0;
    for (final val in data) {
      if (val != null && val > maxVal) maxVal = val;
    }
    if (maxVal <= 0) maxVal = 1;

    final solidBarColors = [
      const Color(0xFFD0E1FD),
      const Color(0xFFC2D9FC),
      const Color(0xFFB5D2FB),
      const Color(0xFFA5C9FB),
      const Color(0xFF90BCFA),
      const Color(0xFF75ABFA),
      const Color(0xFF5394F8),
      AdminColors.accent,
      AdminColors.accent,
      AdminColors.accent,
      AdminColors.accent,
      AdminColors.accent,
    ];

    for (int i = 0; i < data.length; i++) {
      final double xCenter = paddingHorizontal + (i * stepX);
      final double left = xCenter - (barWidth / 2);
      final double right = xCenter + (barWidth / 2);
      final double? value = data[i];

      if (value != null && value > 0) {
        final double barHeight = (value / maxVal) * chartHeight;
        final double top = size.height - barHeight;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, size.height),
          const Radius.circular(radius),
        );
        final color = i == peakIndex
            ? AdminColors.accent
            : solidBarColors[i.clamp(0, solidBarColors.length - 1)];
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      } else {
        // Placeholder viền cho tháng chưa có doanh thu / tháng tương lai
        final double placeholderHeight = chartHeight * 0.75;
        final double top = size.height - placeholderHeight;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, size.height),
          const Radius.circular(radius),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = AdminColors.border
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.peakIndex != peakIndex ||
        oldDelegate.currentMonth != currentMonth;
  }
}
