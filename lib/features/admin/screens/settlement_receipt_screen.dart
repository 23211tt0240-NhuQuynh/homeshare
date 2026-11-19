import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../core/utils/admin_receipt_pdf.dart';
import '../widgets/admin_page_backdrop.dart';
import '../widgets/admin_branded_title.dart';

class SettlementReceiptScreen extends StatelessWidget {
  final double amount;
  final String hostName;
  final String hostAccountNumber;
  final String hostBankName;
  final List<Map<String, dynamic>> settlementItems;
  final String receiptCode; // mã biên lai đã lưu trong Firestore (collection disbursements)
  final DateTime? executedAt; // thời điểm admin xác nhận
  final String? reconciliationNotice;

  const SettlementReceiptScreen({
    super.key,
    required this.amount,
    required this.hostName,
    required this.hostAccountNumber,
    required this.hostBankName,
    this.settlementItems = const [],
    this.receiptCode = '',
    this.executedAt,
    this.reconciliationNotice,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');
    final time = executedAt ?? DateTime.now();
    final code = receiptCode.isNotEmpty
        ? receiptCode
        : '#REC-${DateFormat('yyyyMMdd-HHmmss').format(time)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF101828),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDCEAF5)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF12B76A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ĐÃ GHI NHẬN CHUYỂN KHOẢN',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF027A48),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFormatter.format(amount)} đ',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Số tiền chuyển cho chủ trọ (theo xác nhận của Admin)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Đã quyết toán ${settlementItems.length} đơn',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF344054),
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
                      valueColor: const Color(0xFF398FC0),
                    ),
                    _buildReceiptRow('Người thụ hưởng', hostName),
                    _buildReceiptRow(
                      'Tài khoản nhận',
                      '$hostBankName: $hostAccountNumber',
                    ),
                    _buildReceiptRow(
                      'Trạng thái',
                      'Admin đã xác nhận & ghi sổ',
                      valueColor: const Color(0xFF027A48),
                    ),

                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'BẢNG KÊ ĐỐI SOÁT CHI TIẾT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (reconciliationNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          reconciliationNotice!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A6700),
                          ),
                        ),
                      ),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.2),
                        1: FlexColumnWidth(1.4),
                        2: FlexColumnWidth(1.4),
                        3: FlexColumnWidth(1.5),
                      },
                      children: [
                        const TableRow(
                          children: [
                            Text(
                              'Khách & HĐ',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              'Tiền cọc',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              'Hoa hồng',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              'Thực chuyển',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667085),
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
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      (item['roomCode'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF667085),
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
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  '-${currencyFormatter.format(item['fee'])}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFFD92D20),
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
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF027A48),
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
                        color: const Color(0xFFECFDF3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TỔNG CỘNG THỰC CHUYỂN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF027A48),
                            ),
                          ),
                          Text(
                            '${currencyFormatter.format(amount)} đ',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF027A48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Biên lai nội bộ, ghi nhận theo xác nhận chuyển khoản của Admin.\nMã tra cứu: $code',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF98A2B3),
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

  Widget _buildReceiptRow(
    String label,
    String value, {
    Color valueColor = const Color(0xFF101828),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
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
  }
}
