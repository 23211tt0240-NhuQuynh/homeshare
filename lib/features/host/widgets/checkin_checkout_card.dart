import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/checkin_checkout_repository.dart';

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
      margin: const EdgeInsets.only(bottom: 14),
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
        padding: const EdgeInsets.all(16),
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
                              ? AppColors.textMuted
                              : AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.roomCode.replaceAll(RegExp(r'[^0-9A-Za-z]'), ''),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? AppColors.textMuted
                              : AppColors.primaryDark,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 3),
                      Text(
                        '${item.propertyName} • Tầng ${item.floor}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.surfaceVariant
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isDone) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD97706),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        isDone
                            ? (isCheckinTab ? 'HOÀN TẤT' : 'ĐÃ TRẢ PHÒNG')
                            : item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? AppColors.textMuted
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hộp chi tiết (Details Box)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.background
                    : const Color(0xFFFFFBEB),
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
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
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
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              ? AppColors.textDark
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Nút hành động
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isDone
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textMuted,
                        disabledBackgroundColor: AppColors.textMuted,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isCheckinTab ? 'Đã Check-in' : 'Đã Check-out',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : isCheckinTab
                      ? ElevatedButton.icon(
                          onPressed: onAction,
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text(
                            'Check-in & Bàn giao',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: onAction,
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text(
                            'Check-out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
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
