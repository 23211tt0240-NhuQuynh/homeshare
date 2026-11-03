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

    test(
      'loại đơn đã có mã hoặc thời điểm giải ngân khỏi nhóm tạo hóa đơn',
      () {
        expect(
          BookingUtils.isDisbursed({
            'isDisbursed': false,
            'disbursementId': 'disbursement-1',
          }),
          isTrue,
        );
        expect(
          BookingUtils.canonical({
            'status': 'approved',
            'isDisbursed': false,
            'disbursedAt': DateTime(2026, 11, 1),
          })['isDisbursed'],
          isTrue,
        );
        expect(BookingUtils.isDisbursed({'status': 'approved'}), isFalse);
      },
    );

    test('không gom đơn hủy đã quyết toán nhưng giữ đơn trả hết còn một phía', () {
      expect(
        BookingUtils.isCancellationSettled({
          'paymentOption': 'deposit',
          'cancellationHostPaid': true,
        }),
        isTrue,
      );
      expect(
        BookingUtils.isCancellationSettled({
          'paymentOption': 'full',
          'cancellationHostPaid': true,
          'cancellationRenterRefunded': false,
        }),
        isFalse,
      );
      expect(
        BookingUtils.isCancellationSettled({
          'paymentOption': 'full',
          'cancellationHostPaid': true,
          'cancellationRenterRefunded': true,
        }),
        isTrue,
      );
      expect(BookingUtils.isCancellationSettled({'isRefunded': true}), isTrue);
    });

    test('đơn trả hết lấy số tiền thanh toán thay vì chỉ lấy tiền cọc', () {
      final amount = BookingUtils.amount({
        'paymentOption': 'full',
        'depositAmount': 100000000,
        'paymentAmount': 500000000,
        'rentPrice': 500000000,
      });

      expect(amount, 500000000);
    });

    test('đơn cọc vẫn lấy depositAmount dù có tổng thanh toán khác', () {
      final amount = BookingUtils.amount({
        'paymentOption': 'deposit',
        'depositAmount': 100000000,
        'paymentAmount': 500000000,
        'rentPrice': 500000000,
      });

      expect(amount, 100000000);
    });

    test('đơn trả hết cũ đọc paymentType và totalAmount', () {
      final amount = BookingUtils.amount({
        'paymentType': 'full',
        'depositAmount': 100000000,
        'totalAmount': 500000000,
      });

      expect(amount, 500000000);
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
