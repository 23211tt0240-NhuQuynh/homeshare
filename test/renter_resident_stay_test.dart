import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/booking_service.dart';
import 'package:home_share/core/services/resident_service.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/resident_model.dart';

BookingRequestModel _booking({
  required String id,
  required String roomId,
  String status = 'dangO',
  DateTime? createdAt,
}) {
  return BookingRequestModel(
    id: id,
    renterId: 'user_1',
    renterName: 'Người thuê',
    renterPhone: '0900000000',
    roomId: roomId,
    roomTitle: 'Phòng $roomId',
    roomAddress: 'Địa chỉ $roomId',
    roomPrice: 3000000,
    hostName: 'Chủ trọ',
    status: status,
    moveInDate: DateTime(2026, 10, 1),
    createdAt: createdAt ?? DateTime(2026, 10, 1),
  );
}

void main() {
  group('mergeRenterStayLists', () {
    test('thêm chỗ ở ghép khi user chưa có booking của phòng đó', () {
      final merged = BookingService.mergeRenterStayLists(
        bookings: [_booking(id: 'bk1', roomId: 'room_a')],
        residentStays: [
          _booking(
            id: 'res_kaito',
            roomId: 'room_b',
            createdAt: DateTime(2026, 10, 20),
          ),
        ],
      );

      expect(merged.map((b) => b.id), ['res_kaito', 'bk1']);
      expect(merged.first.isActive, isTrue);
    });

    test('không nhân đôi nếu residents trùng roomId với booking', () {
      final merged = BookingService.mergeRenterStayLists(
        bookings: [_booking(id: 'bk1', roomId: 'room_a')],
        residentStays: [_booking(id: 'res_same', roomId: 'room_a')],
      );

      expect(merged, hasLength(1));
      expect(merged.single.id, 'bk1');
    });
  });

  group('ResidentService.isActive', () {
    test('oGhep dangO chưa rời thì vẫn đang ở', () {
      final resident = ResidentModel(
        id: 'res_kaito',
        periodId: 'period_1',
        roomId: 'room_b',
        userId: 'kaito-kid',
        fullName: 'Kaito Kid',
        formId: 'oGhep',
        statusId: 'dangO',
        moveInDate: DateTime(2026, 10, 20),
      );
      expect(ResidentService.isActive(resident), isTrue);
    });

    test('đã rời phòng thì không còn active', () {
      final resident = ResidentModel(
        id: 'res_left',
        periodId: 'period_1',
        roomId: 'room_b',
        userId: 'kaito-kid',
        fullName: 'Kaito Kid',
        formId: 'oGhep',
        statusId: 'daRoi',
        moveInDate: DateTime(2026, 9, 1),
        moveOutDate: DateTime(2026, 10, 1),
      );
      expect(ResidentService.isActive(resident), isFalse);
    });
  });
}
