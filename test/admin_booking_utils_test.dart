import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/admin/utils/booking_utils.dart';

void main() {
  group('BookingUtils Admin', () {
    test('chuẩn hóa đơn cũ và ưu tiên trạng thái tiến xa hơn', () {
      final booking = BookingUtils.canonical({
        'trangThai': 'daDuyet',
        'status': 'pending',
        'tienCoc': 1500000,
        'tenNguoiO': 'Nguyễn Văn A',
      });

      expect(booking['status'], 'approved');
      expect(booking['depositAmount'], 1500000);
      expect(booking['renterName'], 'Nguyễn Văn A');
      expect(BookingUtils.uiStatus(booking), BookingUtils.statusDepositPaid);
    });

    test('không coi completed là đã giải ngân nếu chưa có bằng chứng', () {
      final booking = BookingUtils.canonical({
        'status': 'completed',
        'paymentOption': 'deposit',
        'depositAmount': 2000000,
      });

      expect(booking['status'], 'approved');
      expect(booking['isDisbursed'], isFalse);
      expect(BookingUtils.uiStatus(booking), BookingUtils.statusDepositPaid);
    });

    test('chia tiền hủy đơn luôn khớp tổng tiền cọc', () {
      final split = BookingUtils.cancellationSplit(1500000);

      expect(split['platformFee'], 75000);
      expect(split['hostAmount'], 150000);
      expect(split['refundAmount'], 1275000);
      expect(
        split['platformFee']! + split['hostAmount']! + split['refundAmount']!,
        split['deposit'],
      );
    });
  });
}
