import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/id_generator.dart';
import 'package:home_share/data/models/room_model.dart';

void main() {
  group('IdGenerator Tests', () {
    test('roomCode generates sequential code P001, P002...', () {
      expect(IdGenerator.roomCode(1), 'P001');
      expect(IdGenerator.roomCode(2), 'P002');
      expect(IdGenerator.roomCode(10), 'P010');
      expect(IdGenerator.roomCode(100), 'P100');
    });

    test('transferContent generates 2-part note [MÃ_NGƯỜI_DÙNG] [MÃ_PHÒNG]', () {
      final note1 = IdGenerator.transferContent(
        renterCode: 'NT001',
        hostCode: 'CT001',
        roomCode: 'P001',
      );
      expect(note1, 'NT001 P001');

      final note2 = IdGenerator.transferContent(
        renterCode: 'NT002',
        hostCode: 'CT001',
        roomCode: 'P002',
      );
      expect(note2, 'NT002 P002');

      final note3 = IdGenerator.transferContent(
        renterCode: 'NT001',
        roomCode: 'P005',
      );
      expect(note3, 'NT001 P005');
    });

    test('booking ID includes date, room code and renter code', () {
      final bookingId = IdGenerator.booking(
        renterCode: 'NT001',
        roomCode: 'P002',
      );
      expect(bookingId, contains('P002'));
      expect(bookingId, contains('NT001'));
      expect(bookingId, startsWith('DP_'));
    });
  });

  group('RoomModel maPhong and aliases Tests', () {
    test('maPhong returns roomCode if present', () {
      final room = RoomModel(
        id: 'r1',
        roomCode: 'P002',
        title: 'Phòng 2',
        description: 'desc',
        price: 3000000,
        deposit: 3000000,
        address: 'Thủ Đức',
        district: 'Thủ Đức',
        city: 'TP. HCM',
        area: 25,
        hostId: 'h1',
        hostName: 'Chủ nhà',
        hostPhone: '0901234567',
        images: const [],
        amenities: const [],
        roomType: 'room',
        createdAt: DateTime.now(),
      );
      expect(room.maPhong, 'P002');
      expect(room.soPhong, 'P002');
    });

    test('fromMap parses maPhong, maNhaTro, chuNhaId correctly', () {
      final room = RoomModel.fromMap({
        'maPhong': 'P003',
        'maNhaTro': 'NT_01',
        'chuNhaId': 'CT001',
        'tieuDe': 'Phòng trọ cao cấp',
        'giaThue': 4000000,
        'tienCoc': 4000000,
        'diaChi': 'Quận 9',
        'quanHuyen': 'TP. Thủ Đức',
        'thanhPho': 'TP. Hồ Chí Minh',
        'dienTich': 30.0,
      }, 'room_doc_123');

      expect(room.roomCode, 'P003');
      expect(room.maPhong, 'P003');
      expect(room.propertyId, 'NT_01');
      expect(room.hostId, 'CT001');
      expect(room.price, 4000000);
      expect(room.deposit, 4000000);
    });

    test('fromMap fallback resolves P00X from sample room IDs', () {
      final room = RoomModel.fromMap({}, 'sample_room_2');
      expect(room.maPhong, 'P002');

      final room3 = RoomModel.fromMap({}, 'sample_room_3');
      expect(room3.maPhong, 'P003');
    });
  });
}
