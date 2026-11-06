import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/room_model.dart';

void main() {
  group('SearchFilter & Distance & Unposted Rooms Tests', () {
    test('RoomModel distanceTo calculates accurate Haversine distance', () {
      // Tọa độ Bến Thành, Quận 1 (10.7725, 106.6980)
      // Tọa độ Landmark 81, Bình Thạnh (10.7950, 106.7218)
      final roomWithCoords = RoomModel.fromMap({
        'title': 'Phòng gần Landmark 81',
        'address': '208 Nguyễn Hữu Cảnh',
        'district': 'Bình Thạnh',
        'city': 'TP. Hồ Chí Minh',
        'area': 25.0,
        'latitude': 10.7950,
        'longitude': 106.7218,
      }, 'room_1');

      final distance = roomWithCoords.distanceTo(10.7725, 106.6980);
      expect(distance, isNotNull);
      // Khoảng cách thực tế giữa Bến Thành và Landmark 81 là ~3.6 km (dung sai ±0.5 km)
      expect(distance!, greaterThan(2.5));
      expect(distance, lessThan(4.5));
    });

    test('RoomModel distanceTo falls back to approximate location when coordinates are absent', () {
      final roomNoCoords = RoomModel.fromMap({
        'title': 'Phòng trọ Thủ Đức',
        'address': 'Võ Văn Ngân, Linh Chiểu',
        'district': 'Thành phố Thủ Đức',
        'city': 'TP. Hồ Chí Minh',
        'area': 22.0,
      }, 'room_no_coord');

      // Điểm mốc Quận 1 (10.7769, 106.7009)
      final distance = roomNoCoords.distanceTo(10.7769, 106.7009);
      expect(distance, isNotNull);
      // Từ Q1 đến Thủ Đức khoảng 10-15km
      expect(distance!, greaterThan(5.0));
      expect(distance, lessThan(25.0));
    });

    test('RoomService.mergeDashboardListings respects includeUnpostedRooms flag', () {
      final post1 = RoomModel.fromMap({
        'title': 'Bài đăng công khai 1',
        'address': 'Quận 1',
        'district': 'Quận 1',
        'propertyId': 'prop_1',
        'isAvailable': true,
        'status': 'available',
      }, 'post_1');

      final unpostedMirror = RoomModel.fromMap({
        'roomCode': 'P202',
        'title': 'Phòng trong kho chưa đăng bài',
        'address': 'Quận 7',
        'district': 'Quận 7',
        'propertyId': 'prop_2',
        'isAvailable': true,
        'status': 'available',
      }, 'host_room_unposted');

      final deletedMirror = RoomModel.fromMap({
        'title': 'Phòng đã xóa',
        'address': 'Quận 3',
        'district': 'Quận 3',
        'propertyId': 'prop_3',
        'status': 'deleted',
        'isAvailable': false,
      }, 'host_room_deleted');

      // 1. Khi includeUnpostedRooms = false: Chỉ trả về posts
      final defaultListings = RoomService.mergeDashboardListings(
        roomMirrors: [unpostedMirror, deletedMirror],
        posts: [post1],
        includeUnpostedRooms: false,
      );
      expect(defaultListings.length, equals(1));
      expect(defaultListings.first.id, equals('post_1'));

      // 2. Khi includeUnpostedRooms = true: Trả về cả posts và unpostedMirror
      final mergedListings = RoomService.mergeDashboardListings(
        roomMirrors: [unpostedMirror, deletedMirror],
        posts: [post1],
        includeUnpostedRooms: true,
      );
      expect(mergedListings.length, equals(2));
      final unpostedItem = mergedListings.firstWhere((r) => r.id == 'host_room_unposted');
      expect(unpostedItem.isUnposted, isTrue);
      expect(unpostedItem.isDisplayable, isTrue);
    });

    test('RoomFilterParams equality and hashing includes new filter fields', () {
      const p1 = RoomFilterParams(
        city: 'TP. Hồ Chí Minh',
        district: 'Quận 1',
        hostQuery: 'Nguyễn Văn A',
        hostId: 'host_123',
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 5.0,
        includeUnpostedRooms: true,
      );

      const p2 = RoomFilterParams(
        city: 'TP. Hồ Chí Minh',
        district: 'Quận 1',
        hostQuery: 'Nguyễn Văn A',
        hostId: 'host_123',
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 5.0,
        includeUnpostedRooms: true,
      );

      const p3 = RoomFilterParams(
        city: 'TP. Hồ Chí Minh',
        district: 'Quận 1',
        hostQuery: 'Trần Thị B',
        hostId: 'host_456',
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 10.0,
        includeUnpostedRooms: false,
      );

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
    });

    test('HostInfo model supports equality and room count updates', () {
      const h1 = HostInfo(id: 'host_1', name: 'Cô Ba', phone: '0901234567', roomCount: 3);
      const h2 = HostInfo(id: 'host_1', name: 'Cô Ba', phone: '0901234567', roomCount: 3);
      final h3 = h1.copyWith(roomCount: 4);

      expect(h1, equals(h2));
      expect(h3.roomCount, equals(4));
      expect(h3.id, equals('host_1'));
    });

    test('RoomModel occupancyStatusLabel and isRentedOrOccupied correctly report vacant vs occupied', () {
      final vacantRoom = RoomModel.fromMap({
        'title': 'Phòng còn trống',
        'address': 'Quận 1',
        'district': 'Quận 1',
        'isAvailable': true,
        'status': 'available',
      }, 'room_vacant');

      final occupiedRoom = RoomModel.fromMap({
        'title': 'Phòng đã có người ở',
        'address': 'Quận 1',
        'district': 'Quận 1',
        'isAvailable': false,
        'status': 'occupied',
      }, 'room_occupied');

      expect(vacantRoom.isRentedOrOccupied, isFalse);
      expect(vacantRoom.occupancyStatusLabel, equals('Còn trống'));
      expect(vacantRoom.isDisplayable, isTrue);

      expect(occupiedRoom.isRentedOrOccupied, isTrue);
      expect(occupiedRoom.occupancyStatusLabel, equals('Đã có người ở'));
      expect(occupiedRoom.isDisplayable, isTrue);
    });

    test('BookingRequestModel.toQrData includes hostId and hostName to prevent checkin to wrong host', () {
      final booking = BookingRequestModel(
        id: 'bk_123',
        renterId: 'renter_1',
        renterName: 'Nguyễn Văn Thuê',
        renterPhone: '0912345678',
        renterGender: 'Nam',
        roomId: 'room_1',
        roomTitle: 'Phòng 101',
        roomAddress: 'Quận 1',
        roomPrice: 3000000,
        deposit: 1000000,
        totalAmount: 1000000,
        rentalMonths: 6,
        hostId: 'host_correct_456',
        hostName: 'Chủ Trọ A',
        status: 'daDuyet',
        paymentOption: 'deposit',
        moveInDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final qrData = booking.toQrData();
      expect(qrData['hostId'], equals('host_correct_456'));
      expect(qrData['hostName'], equals('Chủ Trọ A'));
      expect(qrData['bookingId'], equals('bk_123'));
    });
  });
}
