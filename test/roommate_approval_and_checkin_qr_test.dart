import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';

void main() {
  group('Roommate Approval and Check-in QR Tests', () {
    test('BookingRequestModel.toQrData includes all money and payment fields', () {
      final booking = BookingRequestModel(
        id: 'BK_TEST_001',
        renterId: 'renter_123',
        renterName: 'Nguyễn Văn A',
        renterPhone: '0987654321',
        roomId: 'room_456',
        roomTitle: 'Phòng 204 Đẹp Thoáng',
        roomAddress: '123 Đường ABC, TP.HCM',
        roomPrice: 3500000.0,
        deposit: 1500000.0,
        totalAmount: 3500000.0,
        paymentOption: 'full',
        hostName: 'Chủ Trọ Bác Ba',
        moveInDate: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 10, 1),
      );

      final qrData = booking.toQrData();

      expect(qrData['bookingId'], 'BK_TEST_001');
      expect(qrData['roomPrice'], 3500000.0);
      expect(qrData['deposit'], 1500000.0);
      expect(qrData['totalAmount'], 3500000.0);
      expect(qrData['paymentAmount'], 3500000.0);
      expect(qrData['paidAmount'], 3500000.0);
      expect(qrData['paymentOption'], 'full');
    });

    test('HostNotificationModel recognizes roommate approval request', () {
      final notif = HostNotificationModel(
        id: 'notif_999',
        receiverId: 'host_001',
        type: HostNotificationType.pendingAction,
        title: 'Yêu cầu duyệt người ở ghép mới',
        message: 'Trần Thị B đã đồng ý ở ghép cùng Nguyễn Văn A',
        actionType: 'roommate_approval',
        primaryTenantId: 'renter_123',
        primaryTenantName: 'Nguyễn Văn A',
        newRoommateId: 'renter_789',
        newRoommateName: 'Trần Thị B',
        roomId: 'room_456',
        createdAt: DateTime.now(),
      );

      expect(notif.isRoommateApproval, isTrue);
      expect(notif.primaryTenantName, 'Nguyễn Văn A');
      expect(notif.newRoommateName, 'Trần Thị B');
    });
  });
}
