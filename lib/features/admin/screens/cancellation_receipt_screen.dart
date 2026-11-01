import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../core/utils/admin_receipt_pdf.dart';
import '../widgets/admin_page_backdrop.dart';
import '../widgets/admin_branded_title.dart';
import '../theme/admin_colors.dart';

class CancellationReceiptScreen extends StatelessWidget {
  final String receiptCode;
  final String orderCodes;
  final String recipientName;
  final String recipientRole;
  final String bankDetails;
  final int amount,
      totalDeposit,
      renterRefund,
      hostCompensation,
      platformFee,
      bookingCount;
  final DateTime executedAt;

  const CancellationReceiptScreen({
    super.key,
    required this.receiptCode,
    required this.orderCodes,
    required this.recipientName,
    required this.recipientRole,
    required this.bankDetails,
    required this.amount,
    required this.totalDeposit,
    required this.renterRefund,
    required this.hostCompensation,
    required this.platformFee,
    required this.bookingCount,
    required this.executedAt,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    final isHost = recipientRole == 'host';
    final color = isHost ? AdminColors.successInk : AdminColors.accent;
    final pale = isHost ? AdminColors.successContainer : AdminColors.accentSoft;
    return Scaffold(
      backgroundColor: AdminColors.paper,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        elevation: 0,
        centerTitle: false,
        title: const AdminBrandedTitle(title: 'Biên lai đơn hủy'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AdminColors.ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AdminPageBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .035),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: AdminColors.card,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isHost
                          ? 'ĐÃ GHI NHẬN BỒI THƯỜNG'
                          : 'ĐÃ GHI NHẬN HOÀN TIỀN',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fmt.format(amount)} đ',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.ink,
                      ),
                    ),
                    Text(
                      isHost
                          ? 'Tiền bồi thường chuyển cho chủ trọ'
                          : 'Tiền hoàn lại cho người thuê',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.muted,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pale,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Đối soát $bookingCount đơn hủy',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _row('Mã biên lai', receiptCode),
                    _row(
                      'Thời gian ghi nhận',
                      DateFormat('HH:mm - dd/MM/yyyy').format(executedAt),
                    ),
                    _row('Mã đơn', orderCodes),
                    _row('Người nhận', recipientName),
                    _row(
                      'Tài khoản',
                      bankDetails.isEmpty ? 'Chưa cập nhật' : bankDetails,
                    ),
                    _row('Trạng thái', 'Admin đã ghi nhận', valueColor: color),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'BẢNG KÊ PHÂN BỔ TIỀN CỌC',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _amountRow(
                      'Tổng tiền cọc',
                      totalDeposit,
                      AdminColors.mutedStrong,
                    ),
                    _amountRow(
                      'Hoàn người thuê (85%)',
                      renterRefund,
                      AdminColors.accent,
                    ),
                    _amountRow(
                      'Phí sàn (5%)',
                      platformFee,
                      AdminColors.danger,
                    ),
                    _amountRow(
                      'Bồi thường chủ trọ (10%)',
                      hostCompensation,
                      AdminColors.successInk,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: pale,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isHost
                                  ? 'THỰC CHUYỂN CHO CHỦ TRỌ'
                                  : 'THỰC HOÀN CHO NGƯỜI THUÊ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                          Text(
                            '${fmt.format(amount)} đ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Biên lai nội bộ ghi nhận theo xác nhận của Admin.\nMã tra cứu: $receiptCode',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final bytes = await AdminReceiptPdf.build(
                            title: isHost
                                ? 'Biên lai bồi thường đơn hủy'
                                : 'Biên lai hoàn tiền đơn hủy',
                            amount: '${fmt.format(amount)} đ',
                            subtitle: isHost
                                ? 'Tiền bồi thường chuyển cho chủ trọ'
                                : 'Tiền hoàn lại cho người thuê',
                            receiptCode: receiptCode,
                            sectionTitle: 'BẢNG KÊ PHÂN BỔ TIỀN CỌC',
                            details: [
                              MapEntry('Mã biên lai', receiptCode),
                              MapEntry(
                                'Thời gian ghi nhận',
                                DateFormat(
                                  'HH:mm - dd/MM/yyyy',
                                ).format(executedAt),
                              ),
                              MapEntry('Mã đơn', orderCodes),
                              MapEntry('Người nhận', recipientName),
                              MapEntry(
                                'Tài khoản',
                                bankDetails.isEmpty
                                    ? 'Chưa cập nhật'
                                    : bankDetails,
                              ),
                              MapEntry('Trạng thái', 'Admin đã ghi nhận'),
                            ],
                            tableHeaders: const ['Khoản phân bổ', 'Số tiền'],
                            tableRows: [
                              [
                                'Tổng tiền cọc',
                                '${fmt.format(totalDeposit)} đ',
                              ],
                              [
                                'Hoàn người thuê (85%)',
                                '${fmt.format(renterRefund)} đ',
                              ],
                              ['Phí sàn (5%)', '${fmt.format(platformFee)} đ'],
                              [
                                'Bồi thường chủ trọ (10%)',
                                '${fmt.format(hostCompensation)} đ',
                              ],
                            ],
                            totalLabel: isHost
                                ? 'THỰC CHUYỂN CHO CHỦ TRỌ'
                                : 'THỰC HOÀN CHO NGƯỜI THUÊ',
                            totalAmount: '${fmt.format(amount)} đ',
                            executedAt: executedAt,
                          );
                          await Printing.layoutPdf(
                            name:
                                '${receiptCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}.pdf',
                            onLayout: (_) async => bytes,
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Không thể xuất PDF. Vui lòng thử lại.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(
                        'IN PHIẾU PDF',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.mutedStrong,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'HOÀN TẤT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _row(
    String label,
    String value, {
    Color? valueColor,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AdminColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AdminColors.ink,
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _amountRow(String label, int value, Color color) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: AdminColors.muted),
            ),
          ),
          Text(
            '${fmt.format(value)} đ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
