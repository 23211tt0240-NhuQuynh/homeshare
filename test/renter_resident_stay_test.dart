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
  DateTime? acceptedDate,
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
    acceptedDate: acceptedDate,
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

  group('applyCheckoutOverlayToStay', () {
    test('check-in mới sau checkout cũ thì vẫn đang ở', () {
      final stay = _booking(
        id: 'bk_new',
        roomId: 'charizard',
        status: 'dangO',
        createdAt: DateTime(2026, 10, 30, 15, 21),
        acceptedDate: DateTime(2026, 10, 30, 15, 21),
      );

      final result = BookingService.applyCheckoutOverlayToStay(
        stay: stay,
        latestCheckoutAt: DateTime(2026, 10, 29, 10),
      );

      expect(result.isActive, isTrue);
      expect(result.isEnded, isFalse);
    });

    test('checkout sau lần nhận phòng thì mới gắn đã trả phòng', () {
      final stay = _booking(
        id: 'bk_old',
        roomId: 'charizard',
        status: 'dangO',
        createdAt: DateTime(2026, 10, 1),
        acceptedDate: DateTime(2026, 10, 1, 9),
      );

      final result = BookingService.applyCheckoutOverlayToStay(
        stay: stay,
        latestCheckoutAt: DateTime(2026, 10, 30, 15, 21),
      );

      expect(result.isEnded, isTrue);
      expect(result.status, 'checked_out');
    });

    test('đơn bị gắn checked_out nhầm sau check-in mới thì khôi phục đang ở', () {
      final stay = _booking(
        id: 'bk_healed',
        roomId: 'charizard',
        status: 'checked_out',
        createdAt: DateTime(2026, 10, 30, 15, 21),
        acceptedDate: DateTime(2026, 10, 30, 15, 21),
      );

      final result = BookingService.applyCheckoutOverlayToStay(
        stay: stay,
        latestCheckoutAt: DateTime(2026, 10, 29, 18),
      );

      expect(result.isActive, isTrue);
      expect(result.status, 'dangO');
    });

    test('không có checkout_records thì giữ nguyên trạng thái đơn', () {
      final active = _booking(id: 'bk1', roomId: 'r1');
      final ended = _booking(id: 'bk2', roomId: 'r1', status: 'checked_out');

      expect(
        BookingService.applyCheckoutOverlayToStay(
          stay: active,
          latestCheckoutAt: null,
        ).isActive,
        isTrue,
      );
      expect(
        BookingService.applyCheckoutOverlayToStay(
          stay: ended,
          latestCheckoutAt: null,
        ).isEnded,
        isTrue,
      );
    });
  });

  group('reconcileStayWithOccupancy', () {
    test('còn residents dangO thì đơn thuê phải đang ở dù có checkout cũ', () {
      final stay = _booking(
        id: 'bk_charizard',
        roomId: 'NCQ3ZSCCEN34',
        status: 'checked_out',
        createdAt: DateTime(2026, 10, 30, 15, 51),
        acceptedDate: DateTime(2026, 10, 30, 15, 51),
      );

      final result = BookingService.reconcileStayWithOccupancy(
        stay: stay,
        hasActiveResident: true,
        latestCheckoutAt: DateTime(2026, 10, 29, 18),
      );

      expect(result.isActive, isTrue);
      expect(result.status, 'dangO');
    });

    test('không còn cư dân thì checkout sau nhận phòng mới được trả phòng', () {
      final stay = _booking(
        id: 'bk_out',
        roomId: 'NCQ3ZSCCEN34',
        acceptedDate: DateTime(2026, 10, 1, 9),
      );

      final result = BookingService.reconcileStayWithOccupancy(
        stay: stay,
        hasActiveResident: false,
        latestCheckoutAt: DateTime(2026, 10, 30, 16),
      );

      expect(result.isEnded, isTrue);
    });
  });
}
