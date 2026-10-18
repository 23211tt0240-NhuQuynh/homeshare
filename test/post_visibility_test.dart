import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/data/models/host_post_model.dart';

void main() {
  group('1. RoomModel Host Post Compatibility Tests', () {
    test('RoomModel.fromMap correctly parses rentalPrice from Host post payload', () {
      final postData = {
        'id': 'post_test_123',
        'title': 'Phòng trọ cao cấp trung tâm Q1',
        'description': 'Phòng mới xây có gác, ban công',
        'rentalPrice': 4500000.0,
        'depositAmount': 4500000.0,
        'contactPhone': '0987654321',
        'address': '123 Hai Bà Trưng, Phường Bến Nghé, Quận 1',
        'district': 'Quận 1',
        'city': 'TP. Hồ Chí Minh',
        'area': 30.0,
        'hostId': 'host_uid_999',
        'authorName': 'Nguyễn Văn Chủ Trọ',
        'statusId': 'dangHienThi',
        'status': 'dangHienThi',
        'amenities': ['Wifi', 'Máy lạnh'],
        'images': ['https://example.com/img1.jpg'],
      };

      final room = RoomModel.fromMap(postData, 'post_test_123');

      expect(room.id, equals('post_test_123'));
      expect(room.price, equals(4500000.0));
      expect(room.deposit, equals(4500000.0));
      expect(room.hostPhone, equals('0987654321'));
      expect(room.hostName, equals('Nguyễn Văn Chủ Trọ'));
      expect(room.isAvailable, isTrue);
      expect(room.amenities, contains('Wifi'));
    });

    test('RoomFilterParams defaults to city "Tất cả" so dashboard shows all rooms', () {
      const params = RoomFilterParams();
      expect(params.city, equals('Tất cả'));
      expect(params.district, equals('Tất cả'));
      expect(params.rentalType, equals('all'));
    });
  });

  group('2. Roommate Post Community Visibility Tests', () {
    test('RoommateFilterParams defaults to hasRoom: null so all posts are shown', () {
      const params = RoommateFilterParams();
      expect(params.hasRoom, isNull);
    });

    test('RoommateFilterParams copyWith can filter hasRoom correctly', () {
      const params = RoommateFilterParams();
      final hasRoomOnly = params.copyWith(hasRoom: true);
      expect(hasRoomOnly.hasRoom, isTrue);

      final needRoomOnly = params.copyWith(hasRoom: false);
      expect(needRoomOnly.hasRoom, isFalse);

      final allRooms = needRoomOnly.copyWith(clearHasRoom: true);
      expect(allRooms.hasRoom, isNull);
    });
  });

  group('3. Host Post Model & Identity Tests', () {
    test('HostPostModel isActive works for dangHienThi status', () {
      final post = HostPostModel(
        id: 'post_1',
        hostId: 'host_123',
        statusId: 'dangHienThi',
        status: 'dangHienThi',
        title: 'Phòng mẫu',
        rentalPrice: 3000000,
      );

      expect(post.isActive, isTrue);
      expect(post.chuNhaId, equals('host_123'));
      expect(post.giaThue, equals(3000000));
    });
  });
}
