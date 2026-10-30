import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/admin_receipt_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AdminReceiptPdf tạo được biên nhận PDF với font tiếng Việt', () async {
    final bytes = await AdminReceiptPdf.build(
      title: 'Biên nhận quyết toán',
      amount: '1.350.000 đ',
      subtitle: 'Đã chuyển cho chủ trọ',
      receiptCode: '#REC-TEST',
      sectionTitle: 'Chi tiết giao dịch',
      details: const [
        MapEntry('Chủ trọ', 'Nguyễn Văn A'),
        MapEntry('Ngân hàng', 'MBBank'),
      ],
      tableHeaders: const ['Mã đơn', 'Tiền cọc'],
      tableRows: const [
        ['DH001', '1.500.000 đ'],
      ],
      totalLabel: 'Thực nhận',
      totalAmount: '1.350.000 đ',
      executedAt: DateTime(2026, 10, 21, 9, 30),
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);
  });
}
