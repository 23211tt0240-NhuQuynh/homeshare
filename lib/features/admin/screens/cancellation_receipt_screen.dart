import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../core/utils/admin_receipt_pdf.dart';
import '../widgets/admin_page_backdrop.dart';
import '../widgets/admin_branded_title.dart';

class CancellationReceiptScreen extends StatelessWidget {
  final String receiptCode;
  final String orderCodes;
  final String recipientName;
  final String recipientRole;
  final String bankDetails;
  final bool isFullPayment;
  final double commissionRate;
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
    required this.isFullPayment,
    required this.commissionRate,
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
    final color = isHost ? const Color(0xFF027A48) : const Color(0xFF398FC0);
    final pale = isHost ? const Color(0xFFECFDF3) : const Color(0xFFE9F5FC);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const AdminBrandedTitle(title: 'Biên lai đơn hủy'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF101828),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDCEAF5)),
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
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                    Text(
                      isHost
                          ? 'Tiền bồi thường chuyển cho chủ trọ'
                          : 'Tiền hoàn lại cho người thuê',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF667085),
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
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'BẢNG KÊ PHÂN BỔ TIỀN CỌC',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _amountRow(
                      'Tổng tiền cọc',
                      totalDeposit,
                      const Color(0xFF344054),
                    ),
                    _amountRow(
                      isFullPayment
                          ? 'Hoàn người thuê (50% cọc)'
                          : 'Tiền cọc chuyển cho chủ trọ',
                      isFullPayment ? renterRefund : totalDeposit,
                      isHost
                          ? const Color(0xFF344054)
                          : const Color(0xFF398FC0),
                    ),
                    if (isFullPayment && isHost)
                      _amountRow(
                        'Phần chủ trọ trước hoa hồng (50%)',
                        totalDeposit ~/ 2,
                        const Color(0xFF344054),
                      ),
                    _amountRow(
                      'Hoa hồng sàn (${commissionRate.toStringAsFixed(commissionRate % 1 == 0 ? 0 : 1)}%)',
                      platformFee,
                      const Color(0xFFD92D20),
                    ),
                    if (isHost)
                      _amountRow(
                        'Thực chuyển cho chủ trọ',
                        hostCompensation,
                        const Color(0xFF027A48),
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
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF98A2B3),
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
                                ? 'Biên lai quyết toán đơn hủy'
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
                                isFullPayment
                                    ? 'Hoàn người thuê (50% cọc)'
                                    : 'Tiền cọc chuyển cho chủ trọ',
                                '${fmt.format(isFullPayment ? renterRefund : totalDeposit)} đ',
                              ],
                              if (isFullPayment && isHost)
                                [
                                  'Phần chủ trọ trước hoa hồng (50%)',
                                  '${fmt.format(totalDeposit ~/ 2)} đ',
                                ],
                              [
                                'Hoa hồng sàn (${commissionRate.toStringAsFixed(commissionRate % 1 == 0 ? 0 : 1)}%)',
                                '${fmt.format(platformFee)} đ',
                              ],
                              if (isHost)
                                [
                                  'Thực chuyển cho chủ trọ',
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
                                content: Text('Không thể xuất PDF: $error'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text(
                        'IN PHIẾU PDF',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF344054),
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
                        backgroundColor: const Color(0xFF398FC0),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
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
    Color valueColor = const Color(0xFF101828),
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: valueColor,
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
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
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
