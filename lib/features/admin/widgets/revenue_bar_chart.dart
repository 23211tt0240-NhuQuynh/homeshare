import 'package:flutter/material.dart';

<<<<<<< HEAD
/// Biểu đồ doanh thu theo năm.
/// [monthlyData]: 12 phần tử, đơn vị = triệu đồng. null = chưa có dữ liệu.
/// Đỉnh (cao nhất) và trung bình được TÍNH từ dữ liệu, không hardcode.
class RevenueBarChart extends StatelessWidget {
  final List<double?> monthlyData;
=======
class RevenueBarChart extends StatelessWidget {
  final List<double?> monthlyData; // null for future months
  final int peakIndex;
  final String peakTooltipText;
  final String averageMonthlyText;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

  const RevenueBarChart({
    super.key,
    this.monthlyData = const [
<<<<<<< HEAD
      null, null, null, null, null, null, null, null, null, null, null, null
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
    final double tooltipAlignX =
        hasData ? (-1 + 2 * peakIndex / (monthlyData.length - 1)) : 1;

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF398FC0),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF398FC0).withValues(alpha: 0.25),
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

=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        SizedBox(
          height: 155,
          child: CustomPaint(
            size: const Size(double.infinity, 155),
            painter: _BarChartPainter(
              data: monthlyData,
              peakIndex: peakIndex,
<<<<<<< HEAD
              currentMonth: currentMonth,
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
            ),
          ),
        ),
        const SizedBox(height: 6),

<<<<<<< HEAD
        // Nhãn T1 -> T12
=======
        // Month Labels T1 -> T12
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (index) {
              final isPeak = index == peakIndex;
<<<<<<< HEAD
              final isFuture = index >= currentMonth;
=======
              final isFuture = index >= 9;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              return SizedBox(
                width: 22,
                child: Text(
                  'T${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                    color: isPeak
<<<<<<< HEAD
                        ? const Color(0xFF398FC0)
                        : (isFuture
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
=======
                        ? const Color(0xFF1E60FF)
                        : (isFuture ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),

<<<<<<< HEAD
        // Trung bình mỗi tháng (tính từ dữ liệu thật)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F9FF),
=======
        // Average summary note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
<<<<<<< HEAD
              const Text('⚡', style: TextStyle(fontSize: 14)),
=======
              const Text(
                '⚡',
                style: TextStyle(fontSize: 14),
              ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                      text: avgText,
=======
                      text: averageMonthlyText.replaceFirst('TB mỗi tháng: ', ''),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
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
=======
  final int peakIndex;

  _BarChartPainter({required this.data, required this.peakIndex});

  @override
  void paint(Canvas canvas, Size size) {
    // Guard: need at least 2 data points to calculate stepX safely
    if (data.length < 2) return;
    // Guard: canvas must have positive dimensions
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    if (size.width <= 0 || size.height <= 0) return;

    const double barWidth = 14.0;
    const double radius = 5.0;
    const double paddingHorizontal = 10.0;
    final double availableWidth = size.width - (paddingHorizontal * 2);
    if (availableWidth <= 0) return;

    final double stepX = availableWidth / (data.length - 1);
    final double chartHeight = size.height - 10.0;
    if (chartHeight <= 0) return;

<<<<<<< HEAD
    double maxVal = 0;
    for (final val in data) {
      if (val != null && val > maxVal) maxVal = val;
    }
    if (maxVal <= 0) maxVal = 1;

    const solidBarColors = [
      Color(0xFFD0E1FD),
      Color(0xFFC2D9FC),
      Color(0xFFB5D2FB),
      Color(0xFFA5C9FB),
      Color(0xFF90BCFA),
      Color(0xFF75ABFA),
      Color(0xFF5394F8),
      Color(0xFF398FC0),
      Color(0xFF398FC0),
      Color(0xFF398FC0),
      Color(0xFF398FC0),
      Color(0xFF398FC0),
=======
    // Find max value
    double maxVal = 20.0;
    for (final val in data) {
      if (val != null && val > maxVal) maxVal = val;
    }

    const solidBarColors = [
      Color(0xFFD0E1FD), // T1
      Color(0xFFC2D9FC), // T2
      Color(0xFFB5D2FB), // T3
      Color(0xFFA5C9FB), // T4
      Color(0xFF90BCFA), // T5
      Color(0xFF75ABFA), // T6
      Color(0xFF5394F8), // T7
      Color(0xFF387EF5), // T8
      Color(0xFF1E60FF), // T9 (Peak)
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    ];

    for (int i = 0; i < data.length; i++) {
      final double xCenter = paddingHorizontal + (i * stepX);
      final double left = xCenter - (barWidth / 2);
      final double right = xCenter + (barWidth / 2);
      final double? value = data[i];

      if (value != null && value > 0) {
<<<<<<< HEAD
        final double barHeight = (value / maxVal) * chartHeight;
        final double top = size.height - barHeight;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, size.height),
          const Radius.circular(radius),
        );
        final color = i == peakIndex
            ? const Color(0xFF398FC0)
            : solidBarColors[i.clamp(0, solidBarColors.length - 1)];
=======
        // Render solid rounded bar
        final double barHeight = (value / maxVal) * chartHeight;
        final double top = size.height - barHeight;
        final rect = Rect.fromLTRB(left, top, right, size.height);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

        final color = i == peakIndex
            ? const Color(0xFF1E60FF)
            : (i < solidBarColors.length
                ? solidBarColors[i]
                : const Color(0xFF75ABFA));

>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      } else {
<<<<<<< HEAD
        // Placeholder viền cho tháng chưa có doanh thu / tháng tương lai
        final double placeholderHeight = chartHeight * 0.75;
        final double top = size.height - placeholderHeight;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, size.height),
          const Radius.circular(radius),
        );
=======
        // Render simple stroked placeholder for null / zero-value months.
        // Deliberately NOT using computeMetrics() (causes assertion flood on
        // Flutter Web). A plain stroke rectangle looks identical at this scale.
        final double placeholderHeight = chartHeight * 0.75;
        final double top = size.height - placeholderHeight;
        final rect = Rect.fromLTRB(left, top, right, size.height);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = const Color(0xFFCBD5E1)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
<<<<<<< HEAD
    return oldDelegate.data != data ||
        oldDelegate.peakIndex != peakIndex ||
        oldDelegate.currentMonth != currentMonth;
=======
    return oldDelegate.data != data || oldDelegate.peakIndex != peakIndex;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }
}
