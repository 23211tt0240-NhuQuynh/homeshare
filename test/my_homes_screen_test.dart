import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/features/renter/screens/my_homes_screen.dart';

void main() {
  group('MyHomesScreen & PastRentalHomeItem Tests', () {
    test('PastRentalHomeItem constructs correctly with all details', () {
      final moveIn = DateTime(2026, 1, 10);
      final moveOut = DateTime(2026, 7, 10);

      final item = PastRentalHomeItem(
        id: 'CR_001',
        roomId: 'ROOM_302',
        roomTitle: 'Phòng 302 Dãy A',
        roomAddress: '123 Đường Điện Biên Phủ, Bình Thạnh',
        hostId: 'HOST_99',
        hostName: 'Nguyễn Văn Chủ',
        hostPhone: '0901234567',
        roomPrice: 3500000,
        depositAmount: 3500000,
        deductionAmount: 200000,
        refundAmount: 3300000,
        moveInDate: moveIn,
        moveOutDate: moveOut,
        status: 'Đã hoàn tất trả phòng',
        note: 'Bàn giao đầy đủ 2 chìa khóa, phòng sạch sẽ',
        finalElectricityMeter: 1420.5,
        finalWaterMeter: 85.0,
        hasCheckoutRecord: true,
      );

      expect(item.id, equals('CR_001'));
      expect(item.roomId, equals('ROOM_302'));
      expect(item.roomPrice, equals(3500000));
      expect(item.depositAmount, equals(3500000));
      expect(item.deductionAmount, equals(200000));
      expect(item.refundAmount, equals(3300000));
      expect(item.hasCheckoutRecord, isTrue);
      expect(item.finalElectricityMeter, equals(1420.5));
      expect(item.finalWaterMeter, equals(85.0));
      expect(item.moveOutDate, equals(moveOut));
    });

    test('BookingRequestModel isActive correctly segregates active vs past homes', () {
      final activeBooking = BookingRequestModel(
        id: 'BK_ACTIVE',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_1',
        roomTitle: 'Phòng đang ở',
        roomAddress: '123 Test St',
        roomPrice: 3000000,
        deposit: 3000000,
        status: 'active',
        moveInDate: DateTime.now(),
        createdAt: DateTime.now(),
        hostName: 'Chủ trọ A',
      );

      final completedBooking = BookingRequestModel(
        id: 'BK_PAST',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_2',
        roomTitle: 'Phòng đã ở trước đây',
        roomAddress: '456 Test St',
        roomPrice: 3200000,
        deposit: 3200000,
        status: 'completed',
        moveInDate: DateTime(2025, 5, 1),
        createdAt: DateTime(2025, 5, 1),
        hostName: 'Chủ trọ B',
      );

      final checkedOutBooking = BookingRequestModel(
        id: 'BK_CHECKED_OUT',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_3',
        roomTitle: 'Phòng đã check-out',
        roomAddress: '789 Test St',
        roomPrice: 4000000,
        deposit: 4000000,
        status: 'checked_out',
        moveInDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        hostName: 'Chủ trọ C',
      );

      expect(activeBooking.isActive, isTrue);
      expect(completedBooking.isActive, isFalse);
      expect(checkedOutBooking.isActive, isFalse);

      final allBookings = [activeBooking, completedBooking, checkedOutBooking];
      final activeHomes = allBookings.where((b) => b.isActive).toList();
      expect(activeHomes.length, equals(1));
      expect(activeHomes.first.id, equals('BK_ACTIVE'));
    });

    test('mergeEndedBookingsIntoPastHomes thêm đơn đã trả phòng chưa có trong lịch sử', () {
      final existing = PastRentalHomeItem(
        id: 'CR_001',
        roomId: 'ROOM_A',
        roomTitle: 'Phòng A',
        roomAddress: 'Địa chỉ A',
        hostId: 'HOST_1',
        hostName: 'Chủ A',
        roomPrice: 3000000,
        moveInDate: DateTime(2026, 1, 1),
        moveOutDate: DateTime(2026, 6, 1),
      );
      final ended = BookingRequestModel(
        id: 'BK_ENDED',
        renterId: 'RENTER_1',
        renterName: 'Người thuê',
        renterPhone: '0900000000',
        roomId: 'ROOM_B',
        roomTitle: 'Phòng B host_rooms',
        roomAddress: 'Địa chỉ B',
        roomPrice: 2500000,
        hostName: 'Chủ B',
        status: 'checked_out',
        moveInDate: DateTime(2026, 3, 1),
        moveOutDate: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 3, 1),
      );

      final merged = mergeEndedBookingsIntoPastHomes([existing], [ended]);
      expect(merged.map((item) => item.roomId), ['ROOM_B', 'ROOM_A']);
      expect(merged.first.roomTitle, 'Phòng B host_rooms');
      expect(merged.first.status, 'Đã trả phòng');
    });

    test('mergeEndedBookingsIntoPastHomes không nhân đôi phòng đã có checkout', () {
      final existing = PastRentalHomeItem(
        id: 'CR_001',
        roomId: 'ROOM_A',
        roomTitle: 'Phòng A',
        roomAddress: 'Địa chỉ A',
        hostId: 'HOST_1',
        hostName: 'Chủ A',
        roomPrice: 3000000,
        moveInDate: DateTime(2026, 1, 1),
        moveOutDate: DateTime(2026, 6, 1),
      );
      final ended = BookingRequestModel(
        id: 'BK_SAME',
        renterId: 'RENTER_1',
        renterName: 'Người thuê',
        renterPhone: '0900000000',
        roomId: 'ROOM_A',
        roomTitle: 'Phòng A',
        roomAddress: 'Địa chỉ A',
        roomPrice: 3000000,
        hostName: 'Chủ A',
        status: 'checked_out',
        moveInDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final merged = mergeEndedBookingsIntoPastHomes([existing], [ended]);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'CR_001');
    });
  });
}
