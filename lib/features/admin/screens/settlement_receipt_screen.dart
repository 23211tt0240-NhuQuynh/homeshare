import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SettlementReceiptScreen extends StatelessWidget {
  final double amount;
  final String hostName;
  final String hostAccountNumber;
  final String hostBankName;
  final List<Map<String, dynamic>> settlementItems;

  const SettlementReceiptScreen({
    super.key,
    required this.amount,
    required this.hostName,
    required this.hostAccountNumber,
    required this.hostBankName,
    this.settlementItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF101828)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Biên Lai Giao Dịch',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF101828)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEAECF0)),
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
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CHUYỂN KHOẢN THÀNH CÔNG',
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
                    'Số tiền thực thanh toán cho chủ trọ',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Đã quyết toán ${settlementItems.length} đơn', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF344054))),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  _buildReceiptRow('Mã biên lai', '#REC-${DateFormat('yyyyMMdd').format(DateTime.now())}-SUM'),
                  _buildReceiptRow('Thời gian thực hiện', DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now())),
                  _buildReceiptRow('Phương thức', 'VietQR (Auto $hostBankName)', valueColor: const Color(0xFF155EEF)),
                  _buildReceiptRow('Người thụ hưởng', hostName),
                  _buildReceiptRow('Tài khoản nhận', '$hostBankName: $hostAccountNumber'),
                  _buildReceiptRow('Trạng thái Firestore', 'Đã ghi sổ thành công', valueColor: const Color(0xFF027A48)),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'BẢNG KÊ ĐỐI SOÁT CHI TIẾT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
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
                      const TableRow(
                        children: [
                          Text('Khách & HĐ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF667085))),
                          Text('Tiền cọc', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF667085))),
                          Text('Hoa hồng', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF667085))),
                          Text('Thực chuyển', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF667085))),
                        ],
                      ),
                      ...settlementItems.map((item) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['orderCode']} • ${item['renterName']}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  Text(item['roomCode'], style: const TextStyle(fontSize: 9.5, color: Color(0xFF667085))),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(currencyFormatter.format(item['amount']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('-${currencyFormatter.format(item['fee'])}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: Color(0xFFD92D20))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(currencyFormatter.format(item['net']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF027A48))),
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
                        const Text('TỔNG CỘNG THỰC CHUYỂN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF027A48))),
                        Text('${currencyFormatter.format(amount)} đ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF027A48))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Biên lai điện tử hợp lệ được xuất từ hệ thống quản lý phòng trọ\nMã tra cứu: NT-REC-99824 • Ký số tự động bởi VietQR',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF155EEF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('HOÀN TẤT & QUAY VỀ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color valueColor = const Color(0xFF101828)}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085))),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}