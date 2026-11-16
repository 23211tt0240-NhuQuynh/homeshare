import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/repositories/checkin_checkout_repository.dart';
import 'package:home_share/features/host/screens/host_checkin_checkout_screen.dart';

CheckinCheckoutItem item({required String roomCode, required int floor}) {
  return CheckinCheckoutItem(
    id: roomCode,
    bookingId: 'booking-$roomCode',
    roomId: 'room-$roomCode',
    roomCode: roomCode,
    renterId: 'renter-$roomCode',
    renterName: 'Người thuê $roomCode',
    propertyName: 'Nhà trọ',
    floor: floor,
    deposit: 1000000,
    expectedDate: DateTime(2026, 11, 16),
    status: 'dangO',
  );
}

void main() {
  final items = [
    item(roomCode: '101', floor: 1),
    item(roomCode: '102', floor: 1),
    item(roomCode: '201', floor: 2),
  ];

  test('lọc check-in/out theo tầng', () {
    expect(
      applyCheckinCheckoutFilters(items, floor: 1).map((item) => item.roomCode),
      ['101', '102'],
    );
  });

  test('lọc check-in/out theo phòng và kết hợp tầng', () {
    expect(
      applyCheckinCheckoutFilters(
        items,
        floor: 2,
        roomCode: '201',
      ).map((item) => item.roomCode),
      ['201'],
    );
    expect(
      applyCheckinCheckoutFilters(items, floor: 1, roomCode: '201'),
      isEmpty,
    );
  });
}
