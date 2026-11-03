import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../core/utils/admin_receipt_pdf.dart';
import '../widgets/admin_page_backdrop.dart';
import '../widgets/admin_branded_title.dart';
import '../theme/admin_colors.dart';

class SettlementReceiptScreen extends StatelessWidget {
  final double amount;
  final String hostName;
  final String hostAccountNumber;
  final String hostBankName;
  final List<Map<String, dynamic>> settlementItems;
  final String
  receiptCode; // mã biên lai đã lưu trong Firestore (collection disbursements)
  final DateTime? executedAt; // thời điểm admin xác nhận

  const SettlementReceiptScreen({
    super.key,
    required this.amount,
    required this.hostName,
    required this.hostAccountNumber,
    required this.hostBankName,
    this.settlementItems = const [],
    this.receiptCode = '',
    this.executedAt,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');
    final time = executedAt ?? DateTime.now();
    final code = receiptCode.isNotEmpty
        ? receiptCode
        : '#REC-${DateFormat('yyyyMMdd-HHmmss').format(time)}';

    return Scaffold(
      backgroundColor: AdminColors.paper,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AdminColors.ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: const AdminBrandedTitle(title: 'Biên lai giao dịch'),
      ),
      body: AdminPageBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AdminColors.success,
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
                      'ĐÃ GHI NHẬN CHUYỂN KHOẢN',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.successInk,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFormatter.format(amount)} đ',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Số tiền chuyển cho chủ trọ (theo xác nhận của Admin)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Đã quyết toán ${settlementItems.length} đơn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.mutedStrong,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    _buildReceiptRow('Mã biên lai', code),
                    _buildReceiptRow(
                      'Thời gian xác nhận',
                      DateFormat('HH:mm - dd/MM/yyyy').format(time),
                    ),
                    _buildReceiptRow(
                      'Phương thức',
                      'Chuyển khoản ngân hàng (ngoài ứng dụng)',
                      valueColor: AdminColors.accent,
                    ),
                    _buildReceiptRow('Người thụ hưởng', hostName),
                    _buildReceiptRow(
                      'Tài khoản nhận',
                      '$hostBankName: $hostAccountNumber',
                    ),
                    _buildReceiptRow(
                      'Trạng thái',
                      'Admin đã xác nhận & ghi sổ',
                      valueColor: AdminColors.successInk,
                    ),

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'BẢNG KÊ ĐỐI SOÁT CHI TIẾT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.2),
                        1: FlexColumnWidth(1.4),
                        2: FlexColumnWidth(1.4),
                        3: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          children: [
                            Text(
                              'Khách & HĐ',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.muted,
                              ),
                            ),
                            Text(
                              'Tiền cọc',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.muted,
                              ),
                            ),
                            Text(
                              'Hoa hồng',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.muted,
                              ),
                            ),
                            Text(
                              'Thực chuyển',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.muted,
                              ),
                            ),
                          ],
                        ),
                        ...settlementItems.map((item) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['orderCode']} • ${item['renterName']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      (item['roomCode'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: AdminColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  currencyFormatter.format(item['amount']),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 10.5),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  '-${currencyFormatter.format(item['fee'])}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AdminColors.danger,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  currencyFormatter.format(item['net']),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AdminColors.successInk,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminColors.successContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TỔNG CỘNG THỰC CHUYỂN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.successInk,
                            ),
                          ),
                          Text(
                            '${currencyFormatter.format(amount)} đ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.successInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Biên lai nội bộ, ghi nhận theo xác nhận chuyển khoản của Admin.\nMã tra cứu: $code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final bytes = await AdminReceiptPdf.build(
                            title: 'Biên lai giao dịch',
                            amount: '${currencyFormatter.format(amount)} đ',
                            subtitle:
                                'Số tiền chuyển cho chủ trọ theo xác nhận của Admin',
                            receiptCode: code,
                            sectionTitle: 'BẢNG KÊ ĐỐI SOÁT CHI TIẾT',
                            details: [
                              MapEntry('Mã biên lai', code),
                              MapEntry(
                                'Thời gian xác nhận',
                                DateFormat('HH:mm - dd/MM/yyyy').format(time),
                              ),
                              MapEntry(
                                'Phương thức',
                                'Chuyển khoản ngân hàng (ngoài ứng dụng)',
                              ),
                              MapEntry('Người thụ hưởng', hostName),
                              MapEntry(
                                'Tài khoản nhận',
                                '$hostBankName: $hostAccountNumber',
                              ),
                              MapEntry(
                                'Trạng thái',
                                'Admin đã xác nhận & ghi sổ',
                              ),
                            ],
                            tableHeaders: const [
                              'Khách & HĐ',
                              'Tiền cọc',
                              'Hoa hồng',
                              'Thực chuyển',
                            ],
                            tableRows: settlementItems
                                .map(
                                  (item) => [
                                    '${item['orderCode']} • ${item['renterName']}',
                                    currencyFormatter.format(item['amount']),
                                    '-${currencyFormatter.format(item['fee'])}',
                                    currencyFormatter.format(item['net']),
                                  ],
                                )
                                .toList(),
                            totalLabel: 'TỔNG CỘNG THỰC CHUYỂN',
                            totalAmount:
                                '${currencyFormatter.format(amount)} đ',
                            executedAt: time,
                          );
                          await Printing.layoutPdf(
                            name:
                                '${code.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}.pdf',
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

  Widget _buildReceiptRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AdminColors.muted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AdminColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
