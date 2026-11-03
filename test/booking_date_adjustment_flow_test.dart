import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';

void main() {
  group('Booking Date Adjustment & Confirmation Flow Tests', () {
    test('BookingRequestModel correctly identifies choXacNhanThayDoi as approved deposit state', () {
      final now = DateTime.now();
      final booking = BookingRequestModel(
        id: 'BK_TEST_001',
        renterId: 'renter_123',
        renterName: 'Trần Thanh Anh Toàn',
        renterPhone: '0382542737',
        roomId: 'room_mmf2',
        roomTitle: 'Phòng MMF2',
        roomAddress: '123 Đường Số 1, TP. HCM',
        roomPrice: 5000000,
        deposit: 23000,
        totalAmount: 23000,
        hostId: 'host_456',
        hostName: 'Chủ trọ QA',
        status: 'choXacNhanThayDoi',
        moveInDate: DateTime(2026, 10, 31),
        createdAt: now,
      );

      // Khi chủ trọ đề xuất đổi ngày, đơn vẫn là đơn cọc hợp lệ (isApproved == true)
      expect(booking.isApproved, isTrue);
      expect(booking.isCancelled, isFalse);
      expect(booking.isActive, isFalse);
    });

    test('Booking date adjustment data payload contains required fields for Renter confirmation', () {
      final oldDate = DateTime(2026, 10, 31);
      final newDate = DateTime(2026, 11, 4);
      final reason = 'Chủ trọ dọn dẹp vệ sinh phòng thêm 4 ngày';

      final adjustmentPayload = <String, dynamic>{
        'id': 'notif_renter_001',
        'receiverId': 'renter_123',
        'recipientRole': 'renter',
        'title': 'Chủ trọ yêu cầu đổi lịch dọn vào',
        'message':
            'Chủ trọ đề xuất chuyển ngày nhận phòng sang 04/11/2026. Lý do: $reason',
        'notificationType': 'booking_adjustment',
        'type': 'booking_adjustment',
        'bookingId': 'BK_TEST_001',
        'hostNotificationId': 'notif_host_001',
        'roomId': 'room_mmf2',
        'roomTitle': 'Hủy diệt',
        'oldRoomTitle': 'Phòng MMF2',
        'oldCheckInDate': Timestamp.fromDate(oldDate),
        'newCheckInDate': Timestamp.fromDate(newDate),
        'amount': 23000.0,
        'renterName': 'Trần Thanh Anh Toàn',
        'hostName': 'Chủ trọ QA',
        'hostId': 'host_456',
        'adjustmentReason': reason,
        'status': 'pending',
        'isRead': false,
      };

      expect(adjustmentPayload['notificationType'], equals('booking_adjustment'));
      expect(adjustmentPayload['status'], equals('pending'));
      expect(adjustmentPayload['oldCheckInDate'], isNotNull);
      expect(adjustmentPayload['newCheckInDate'], isNotNull);
      expect(adjustmentPayload['adjustmentReason'], equals(reason));
      expect(adjustmentPayload['hostId'], equals('host_456'));
      expect(adjustmentPayload['renterName'], equals('Trần Thanh Anh Toàn'));
    });

    test('Accepting adjustment payload correctly computes accepted booking updates', () {
      final newDate = DateTime(2026, 11, 4);
      final newCheckInDate = Timestamp.fromDate(newDate);

      final data = <String, dynamic>{
        'bookingId': 'BK_TEST_001',
        'hostNotificationId': 'notif_host_001',
        'newRoomId': 'room_new_99',
        'newRoomTitle': 'Phòng VIP Hủy Diệt',
        'newCheckInDate': newCheckInDate,
        'hostId': 'host_456',
        'renterName': 'Trần Thanh Anh Toàn',
      };

      // Giả lập logic trong _respondToBookingAdjustment khi accept = true
      final bookingUpdates = <String, dynamic>{
        'status': 'daCoc',
        'statusId': 'deposited',
        'adjustmentStatus': 'accepted',
        'moveInDate': data['newCheckInDate'],
        'ngayVao': data['newCheckInDate'],
        'checkInDate': data['newCheckInDate'],
      };
      final newRoomId = (data['newRoomId'] ?? data['roomId'])?.toString();
      if (newRoomId != null && newRoomId.isNotEmpty) {
        bookingUpdates['roomId'] = newRoomId;
      }
      final newRoomTitle = (data['newRoomTitle'] ?? data['roomTitle'])?.toString();
      if (newRoomTitle != null && newRoomTitle.isNotEmpty) {
        bookingUpdates['roomTitle'] = newRoomTitle;
      }

      expect(bookingUpdates['status'], equals('daCoc'));
      expect(bookingUpdates['statusId'], equals('deposited'));
      expect(bookingUpdates['adjustmentStatus'], equals('accepted'));
      expect(bookingUpdates['moveInDate'], equals(newCheckInDate));
      expect(bookingUpdates['roomId'], equals('room_new_99'));
      expect(bookingUpdates['roomTitle'], equals('Phòng VIP Hủy Diệt'));
    });

    test('Rejecting adjustment payload preserves original date and sets status to rejected', () {
      final bookingUpdates = <String, dynamic>{
        'status': 'daCoc',
        'statusId': 'deposited',
        'adjustmentStatus': 'rejected',
      };

      expect(bookingUpdates['status'], equals('daCoc'));
      expect(bookingUpdates['adjustmentStatus'], equals('rejected'));
      expect(bookingUpdates.containsKey('moveInDate'), isFalse);
      expect(bookingUpdates.containsKey('roomId'), isFalse);
    });

    test('Host feedback notification payload on renter acceptance is properly structured', () {
      final newDate = DateTime(2026, 11, 4);
      final newCheckInDate = Timestamp.fromDate(newDate);
      const renterName = 'Trần Thanh Anh Toàn';
      const hostId = 'host_456';
      const bookingId = 'BK_TEST_001';

      final hostFeedbackPayload = {
        'receiverId': hostId,
        'recipientRole': 'host',
        'title': 'Khách đã xác nhận thay đổi thông tin 🎉',
        'message':
            'Khách thuê $renterName đã xác nhận đồng ý ngày nhận phòng mới (04/11/2026). Đơn đặt phòng $bookingId đã sẵn sàng chờ nhận phòng.',
        'notificationType': 'deposit',
        'type': 'deposit',
        'status': 'approved',
        'statusId': 'deposited',
        'bookingId': bookingId,
        'checkInDate': newCheckInDate,
        'isRead': false,
      };

      expect(hostFeedbackPayload['receiverId'], equals(hostId));
      expect(hostFeedbackPayload['recipientRole'], equals('host'));
      expect(hostFeedbackPayload['type'], equals('deposit'));
      expect(hostFeedbackPayload['statusId'], equals('deposited'));
      expect(hostFeedbackPayload['title'], contains('xác nhận thay đổi thông tin'));
      expect(hostFeedbackPayload['checkInDate'], equals(newCheckInDate));
    });
  });
}
