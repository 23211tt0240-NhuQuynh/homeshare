import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/vietqr_helper.dart';

class SettlementInvoiceScreen extends StatelessWidget {
  final String hostName;
  final String hostPhone;
  final String hostBankName;
  final String hostAccountNumber;
  final String hostCode;
  final double totalDeposit;
  final double platformFee;
  final double netSettlement;
  final List<Map<String, dynamic>> settlementItems;
  final VoidCallback? onConfirmDisbursement;

  const SettlementInvoiceScreen({
    super.key,
    this.hostName = 'Chủ trọ A (Khu Bình Thạnh)',
    this.hostPhone = '0388529900',
    this.hostBankName = 'MB Bank',
    this.hostAccountNumber = '0388529900',
    this.hostCode = 'CT0089',
    this.totalDeposit = 4100000.0,
    this.platformFee = 350000.0,
    this.netSettlement = 3750000.0,
    this.settlementItems = const [
      {
        'orderCode': '1-0482',
        'renterName': 'Nguyễn Văn Nam',
        'roomCode': 'Phòng 201 - Bình Thạnh',
        'itemType': 'Tiền cọc • Đặt cọc giữ phòng',
        'amount': 1000000.0,
        'fee': 100000.0,
        'net': 900000.0,
      },
      {
        'orderCode': '1-5821',
        'renterName': 'Trần Thị Mai',
        'roomCode': 'Phòng 104 - Bình Thạnh',
        'itemType': 'Tiền cọc • Đặt cọc đảm bảo nhận phòng',
        'amount': 500000.0,
        'fee': 50000.0,
        'net': 450000.0,
      },
      {
        'orderCode': '1-6012',
        'renterName': 'Hoàng Minh Tuấn',
        'roomCode': 'Phòng 302 - Bình Thạnh',
        'itemType': 'Tiền cọc • Cọc hẹn dọn vào',
        'amount': 1500000.0,
        'fee': 120000.0,
        'net': 1380000.0,
      },
      {
        'orderCode': '1-7145',
        'renterName': 'Lê Thu Thảo',
        'roomCode': 'Phòng 102 - Bình Thạnh',
        'itemType': 'Tiền cọc • Cọc đơn hạn 1 tháng',
        'amount': 1100000.0,
        'fee': 80000.0,
        'net': 1020000.0,
      },
    ],
    this.onConfirmDisbursement,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    // Build VietQR image URL
    final qrImageUrl = VietQRHelper.buildVietQrImageUrl(
      amount: netSettlement,
      addInfo: 'NT0009 CHU TRO A',
      accountNo: hostAccountNumber.isNotEmpty ? hostAccountNumber : '0382542737',
      bankCode: 'MB',
      accountName: hostName.toUpperCase(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF101828)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Hóa Đơn & Quyết Toán',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF101828),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF155EEF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettlementReceiptScreen(
                    amount: netSettlement,
                    hostName: hostName,
                    hostAccountNumber: hostAccountNumber,
                    hostBankName: hostBankName,
                    settlementItems: settlementItems,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Host Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: Color(0xFF155EEF), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            hostName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF0C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Chờ thanh toán',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB54708),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MB Bank: $hostAccountNumber • Chủ tài khoản: $hostName',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kỳ đối soát: 16/09/2026',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                      ),
                      Text(
                        'Chi 02 phòng ▼',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Settlement Total Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1E0FF), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF155EEF).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'HÓA ĐƠN QUYẾT TOÁN TIỀN CHỦ TRỌ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currencyFormatter.format(netSettlement)} đ',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF027A48),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '(Số tiền thực chuyển EX tự động khấu trừ hoa hồng dịch vụ)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Tổng tiền cọc: ${currencyFormatter.format(totalDeposit)} đ',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Hoa hồng sàn: -${currencyFormatter.format(platformFee)} đ',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD92D20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Settlement Breakdown Items
            const Text(
              'DANH SÁCH GIAO DỊCH QUYẾT TOÁN (4 đơn)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF344054),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            ...settlementItems.map((item) {
              final amt = (item['amount'] as num).toDouble();
              final fee = (item['fee'] as num).toDouble();
              final net = (item['net'] as num).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEAECF0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item['orderCode'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF155EEF),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['renterName'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['roomCode'],
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['itemType'],
                            style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currencyFormatter.format(amt)} đ',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nhận: ${currencyFormatter.format(net)} đ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF027A48),
                          ),
                        ),
                        Text(
                          'Phí: -${currencyFormatter.format(fee)} đ',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD92D20)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),

            // 4. Accounting Summary Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHI TIẾT KHOẢN THU / CHI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1. Tổng tiền cọc giữ chỗ (4 đơn):', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                      Text('${currencyFormatter.format(totalDeposit)} đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('2. Hoa hồng môi giới dịch vụ (sàn):', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                      Text('-${currencyFormatter.format(platformFee)} đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD92D20))),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TỔNG CỘNG THỰC CHUYỂN:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF101828)),
                      ),
                      Text(
                        '${currencyFormatter.format(netSettlement)} đ',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF027A48)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. QR Code Section for Host
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Column(
                children: [
                  const Text(
                    'MÃ QR CHUYỂN KHOẢN CHO CHỦ TRỌ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF155EEF),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 190,
                    height: 190,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: Image.network(
                      qrImageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 70, color: Color(0xFF155EEF)),
                            const SizedBox(height: 4),
                            Text(
                              'MB Bank • $hostAccountNumber',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Quét mã để chuyển nhanh ${currencyFormatter.format(netSettlement)} đ qua Napas 24/7',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF155EEF)),
                      const SizedBox(width: 4),
                      Text(
                        'Sao chép STK: $hostAccountNumber',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF155EEF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Action Buttons
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang xuất phiếu quyết toán định dạng PDF...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('In Phiếu', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF344054))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (onConfirmDisbursement != null) {
                        onConfirmDisbursement!();
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettlementReceiptScreen(
                            amount: netSettlement,
                            hostName: hostName,
                            hostAccountNumber: hostAccountNumber,
                            hostBankName: hostBankName,
                            settlementItems: settlementItems,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'XÁC NHẬN CHUYỂN KHOẢN',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF12B76A), size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CHUYỂN KHOẢN THÀNH CÔNG',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF027A48),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${currencyFormatter.format(amount)} đ',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Số tiền thực thanh toán cho chủ trọ',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  _buildReceiptRow('Mã biên lai:', '#REC-20260916-SUM'),
                  _buildReceiptRow('Thời gian thực hiện:', '14:32 - 16/09/2026'),
                  _buildReceiptRow('Phương thức:', 'VietQR (Auto MB Bank)'),
                  _buildReceiptRow('Người thụ hưởng:', hostName),
                  _buildReceiptRow('Tài khoản nhận:', '$hostBankName: $hostAccountNumber'),
                  _buildReceiptRow('Khu trọ áp dụng:', 'Khu Bình Thạnh'),
                  _buildReceiptRow('Nội dung chuyển:', 'NT0009 CHU TRO A'),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'BẢNG KÊ ĐỐI SOÁT CHI TIẾT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF344054)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(
                        children: [
                          Text('Khách & HĐ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                          Text('Tiền cọc', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                          Text('Hoa hồng', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                          Text('Thực chuyển', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                        ],
                      ),
                      ...settlementItems.map((item) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('${item['orderCode']} - ${item['renterName']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(currencyFormatter.format(item['amount']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('-${currencyFormatter.format(item['fee'])}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFFD92D20))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(currencyFormatter.format(item['net']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF027A48))),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TỔNG CỘNG THỰC CHUYỂN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF101828))),
                      Text('${currencyFormatter.format(amount)} đ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF027A48))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang tải phiếu PDF biên lai...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('In phiếu'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('XÁC NHẬN NHẬN TIỀN', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
        ],
      ),
    );
  }
}
