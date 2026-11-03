import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';

BookingRequestModel _createBooking({
  required String id,
  required String status,
  required DateTime moveInDate,
}) {
  return BookingRequestModel(
    id: id,
    renterId: 'renter_123',
    renterName: 'Nguyễn Văn An',
    renterPhone: '0901234567',
    roomId: 'room_456',
    roomTitle: 'Phòng trọ cao cấp Quận 7',
    roomAddress: '123 Nguyễn Thị Thập, Q7, TP.HCM',
    roomPrice: 3500000,
    deposit: 1500000,
    hostId: 'host_789',
    hostName: 'Chủ trọ Trần Văn Bình',
    status: status,
    moveInDate: moveInDate,
    createdAt: DateTime.now(),
  );
}

bool canChangeMoveInDate(BookingRequestModel b) {
  return (b.isPending || b.isApproved) &&
      !b.isActive &&
      !b.isCancelled &&
      !b.isEnded;
}

void main() {
  group('ChangeMoveInDate Policy & Model Tests', () {
    test('Đơn đang chờ xử lý (pending / choDuyet) ĐƯỢC PHÉP đổi ngày dọn vào', () {
      final b1 = _createBooking(
        id: 'DP_01',
        status: 'pending',
        moveInDate: DateTime.now().add(const Duration(days: 3)),
      );
      final b2 = _createBooking(
        id: 'DP_02',
        status: 'choDuyet',
        moveInDate: DateTime.now().add(const Duration(days: 5)),
      );
      final b3 = _createBooking(
        id: 'DP_03',
        status: 'pending_payment',
        moveInDate: DateTime.now().add(const Duration(days: 2)),
      );

      expect(canChangeMoveInDate(b1), isTrue);
      expect(canChangeMoveInDate(b2), isTrue);
      expect(canChangeMoveInDate(b3), isTrue);
    });

    test('Đơn đã duyệt (approved / daDuyet) ĐƯỢC PHÉP đổi ngày dọn vào', () {
      final b1 = _createBooking(
        id: 'DP_04',
        status: 'approved',
        moveInDate: DateTime.now().add(const Duration(days: 7)),
      );
      final b2 = _createBooking(
        id: 'DP_05',
        status: 'daDuyet',
        moveInDate: DateTime.now().add(const Duration(days: 10)),
      );
      final b3 = _createBooking(
        id: 'DP_06',
        status: 'deposit_paid',
        moveInDate: DateTime.now().add(const Duration(days: 4)),
      );

      expect(canChangeMoveInDate(b1), isTrue);
      expect(canChangeMoveInDate(b2), isTrue);
      expect(canChangeMoveInDate(b3), isTrue);
    });

    test('Đơn đang ở (active / dangO) KHÔNG ĐƯỢC đổi ngày dọn vào', () {
      final b = _createBooking(
        id: 'DP_07',
        status: 'active',
        moveInDate: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(canChangeMoveInDate(b), isFalse);
    });

    test('Đơn đã trả phòng / kết thúc (checked_out / completed) KHÔNG ĐƯỢC đổi ngày dọn vào', () {
      final b = _createBooking(
        id: 'DP_08',
        status: 'checked_out',
        moveInDate: DateTime.now().subtract(const Duration(days: 60)),
      );

      expect(canChangeMoveInDate(b), isFalse);
    });

    test('Đơn đã hủy (cancelled / daHuy / rejected) KHÔNG ĐƯỢC đổi ngày dọn vào', () {
      final b1 = _createBooking(
        id: 'DP_09',
        status: 'cancelled',
        moveInDate: DateTime.now().add(const Duration(days: 5)),
      );
      final b2 = _createBooking(
        id: 'DP_10',
        status: 'rejected',
        moveInDate: DateTime.now().add(const Duration(days: 5)),
      );

      expect(canChangeMoveInDate(b1), isFalse);
      expect(canChangeMoveInDate(b2), isFalse);
    });

    test('BookingRequestModel.copyWith cập nhật moveInDate chính xác', () {
      final originalDate = DateTime(2026, 11, 10);
      final newDate = DateTime(2026, 11, 20);

      final booking = _createBooking(
        id: 'DP_11',
        status: 'pending',
        moveInDate: originalDate,
      );

      expect(booking.moveInDate, equals(originalDate));

      final updatedBooking = booking.copyWith(moveInDate: newDate);
      expect(updatedBooking.moveInDate, equals(newDate));
      expect(updatedBooking.id, equals(booking.id));
      expect(updatedBooking.renterName, equals(booking.renterName));
      expect(updatedBooking.roomTitle, equals(booking.roomTitle));

      // QR Data phản ánh ngày dọn vào mới
      final qrData = updatedBooking.toQrData();
      expect(qrData['moveInDate'], equals(newDate.toIso8601String()));
    });
  });
}

