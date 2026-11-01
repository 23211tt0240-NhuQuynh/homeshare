import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/checkin_checkout_repository.dart';
import '../../../core/constants/app_colors.dart';

class CheckinCheckoutCard extends StatelessWidget {
  final CheckinCheckoutItem item;
  final bool isCheckinTab;
  final VoidCallback onAction;

  const CheckinCheckoutCard({
    super.key,
    required this.item,
    required this.isCheckinTab,
    required this.onAction,
  });

  String _formatMoney(double amount) {
    return '${NumberFormat.decimalPattern('vi').format(amount)} đ';
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _formatDateTime(DateTime dt) {
    return '${DateFormat('HH:mm').format(dt)} • ${DateFormat('dd/MM/yyyy').format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = item.isCompleted;

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppColors.surfaceVariant : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Badge phòng + Tên người thuê + Status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge phòng
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.surfaceVariant
                        : AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'PHÒNG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? const Color(0xFF64748B)
                              : (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        item.roomCode.replaceAll(RegExp(r'[^0-9A-Za-z]'), ''),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? const Color(0xFF334155)
                              : (AppColors.isDark ? AppColors.textDark : const Color(0xFF1D4ED8)),
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                // Tên & Vị trí
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.renterName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3),
                      Text(
                        '${item.propertyName} • Tầng ${item.floor}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Badge trạng thái
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.surfaceVariant
                        : AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isDone) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 5),
                      ],
                      Text(
                        isDone
                            ? (isCheckinTab ? 'HOÀN TẤT' : 'ĐÃ TRẢ PHÒNG')
                            : item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? const Color(0xFF64748B)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Hộp chi tiết (Details Box)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.background
                    : AppColors.warningContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isDone
                              ? (isCheckinTab
                                  ? 'Hoàn tất check-in:'
                                  : 'Hoàn tất check-out:')
                              : (isCheckinTab
                                  ? 'Ngày vào dự kiến:'
                                  : 'Dự kiến trả phòng:'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        isDone && item.completedTime != null
                            ? _formatDateTime(item.completedTime!)
                            : _formatDate(item.expectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isDone
                              ? (isCheckinTab
                                  ? 'Tiền cọc nhận:'
                                  : 'Đã hoàn cọc:')
                              : 'Tiền cọc:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatMoney(
                          isDone && item.refundedDeposit != null
                              ? item.refundedDeposit!
                              : item.deposit,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            // Nút hành động
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isDone
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF94A3B8),
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isCheckinTab ? 'Đã Check-in' : 'Đã Check-out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : isCheckinTab
                      ? ElevatedButton.icon(
                          onPressed: onAction,
                          icon: Icon(Icons.login, size: 18),
                          label: Text(
                            'Check-in & Bàn giao',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: onAction,
                          icon: Icon(Icons.logout, size: 18),
                          label: Text(
                            'Check-out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
