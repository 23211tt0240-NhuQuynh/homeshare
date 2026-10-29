import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../models/violation_record_model.dart';

class PaymentActionSheet {
  static String _formatCurrency(double amount) {
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

  /// Xác nhận thu tiền mặt
  static Future<bool?> showCashConfirmation({
    required BuildContext context,
    required ViolationRecordModel record,
    required String collectorName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Text('💵', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Xác nhận thu tiền mặt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Ghi nhận đã thu trực tiếp từ khách thuê',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildRow('Phòng / Cơ sở:',
                          '${record.roomCode} • ${record.propertyName}'),
                      Divider(height: 16, color: AppColors.border),
                      _buildRow('Người nộp:', record.tenantName),
                      Divider(height: 16, color: AppColors.border),
                      _buildRow('Người thu (Chủ trọ):',
                          collectorName.isNotEmpty ? collectorName : 'Chủ trọ'),
                      Divider(height: 16, color: AppColors.border),
                      _buildRow(
                        'Số tiền thực thu:',
                        _formatCurrency(record.totalFine),
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Xác nhận đã thu đủ tiền',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Hủy bỏ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Xác nhận trừ vào hóa đơn
  static Future<bool?> showDeductConfirmation({
    required BuildContext context,
    required ViolationRecordModel record,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Cộng vào hóa đơn tháng sau',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Khoản phạt sẽ được thêm vào hóa đơn tiền phòng kỳ tới',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildRow('Phòng:', record.roomCode),
                      Divider(height: 16, color: AppColors.border),
                      _buildRow('Khách thuê:', record.tenantName),
                      Divider(height: 16, color: AppColors.border),
                      _buildRow(
                        'Số tiền cộng:',
                        _formatCurrency(record.totalFine),
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Xác nhận cộng vào hóa đơn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Hủy bỏ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight
                ? AppColors.danger
                : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
