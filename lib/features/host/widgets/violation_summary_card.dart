import 'package:flutter/material.dart';
import '../repositories/violation_repository.dart';
import '../../../core/constants/app_colors.dart';

class ViolationSummaryCard extends StatelessWidget {
  final ViolationMonthlyStats stats;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<String> onFilterTap;

  const ViolationSummaryCard({
    super.key,
    required this.stats,
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.onFilterTap,
  });

  String _formatCurrency(double amount) {
    final s = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join()} đ';
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentYear = selectedMonth.year;
        final months = List.generate(12, (index) => index + 1);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Chọn tháng đối soát năm $currentYear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: months.map((m) {
                    final isSelected = selectedMonth.month == m;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onMonthChanged(DateTime(currentYear, m));
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 72,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB))
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Th $m',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Header: Chọn tháng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TỔNG QUAN THÁNG',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              InkWell(
                onTap: () => _showMonthPicker(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Tháng ${selectedMonth.month}/${selectedMonth.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Khung lớn Gradient: Tổng tiền phạt ghi nhận
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng tiền phạt ghi nhận',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stats.totalCount} vi phạm',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _formatCurrency(stats.totalFineRecorded),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // 2 Ô Thống kê: Đã nộp & Chờ nộp (Tap to filter)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onFilterTap('PAID'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tổng đã nộp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          _formatCurrency(stats.totalPaid),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
                          ),
                        ),
                        Text(
                          '${stats.paidCount} biên bản',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onFilterTap('PENDING'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tổng chờ nộp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          _formatCurrency(stats.totalPending),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                          ),
                        ),
                        Text(
                          '${stats.pendingCount} biên bản',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
