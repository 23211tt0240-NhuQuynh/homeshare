import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/host/repositories/tenant_repository.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';

void main() {
  group('Roommate Invitation and Host Notification Flow Tests', () {
    test('1. RoomModel and RoomCode must NOT contain random hash codes like #OG- or #LT-', () {
      final room = RoomModel.fromMap({
        'title': 'Phòng trọ cao cấp Linh Trung',
        'address': 'Số 8, Linh Trung, Thủ Đức',
        'price': 3600000,
        'roomCode': 'P101',
      }, 'room_101');

      // roomCode phải là mã phòng thực tế, không chứa ký tự hash code
      expect(room.roomCode, equals('P101'));
      expect(room.roomCode.contains('#OG-'), isFalse);
      expect(room.roomCode.contains('#LT-'), isFalse);

      final displayCode = room.roomCode.isNotEmpty ? room.roomCode : (room.maPhong.isNotEmpty ? room.maPhong : 'P001');
      expect(displayCode, equals('P101'));
    });

    test('2. TenantItem correctly recognizes group tenancy when roommate is accepted', () {
      final now = DateTime.now();
      final roommates = [
        ResidentModel(
          id: 'res_1',
          periodId: 'p_101',
          roomId: 'room_101',
          userId: 'user_primary',
          fullName: 'Nguyễn Văn A',
          formId: 'chinh',
          statusId: 'dangO',
          moveInDate: now,
        ),
        ResidentModel(
          id: 'res_2',
          periodId: 'p_101',
          roomId: 'room_101',
          userId: 'user_roommate',
          fullName: 'Trần Thị B',
          formId: 'oGhep',
          statusId: 'dangO',
          moveInDate: now,
        ),
      ];

      final tenantItem = TenantItem(
        id: 'item_101',
        primaryName: 'Nguyễn Văn A & Trần Thị B',
        phone: '0912345678',
        roomId: 'room_101',
        roomName: 'P.101',
        propertyId: 'prop_1',
        propertyName: 'Nhà trọ Linh Trung',
        floor: 1,
        moveInDate: now,
        roommates: roommates,
      );

      expect(tenantItem.isGroup, isTrue);
      expect(tenantItem.roommates.length, equals(2));
      expect(tenantItem.displayName, contains('&'));
      expect(tenantItem.displayName, equals('Nguyễn Văn A & Trần Thị B'));
    });

    test('3. HostNotificationModel parses pendingAction for new roommate accepted without hash code', () {
      final now = DateTime.now();
      final notification = HostNotificationModel(
        id: 'notif_999',
        receiverId: 'host_001',
        senderId: 'user_roommate',
        type: HostNotificationType.pendingAction,
        title: 'Thông báo có người ở ghép mới',
        message: 'Trần Thị B đã chấp nhận lời mời ở ghép cùng Nguyễn Văn A tại phòng Căn hộ mini. Người này đã được tự động thêm vào danh sách quản lý người thuê của phòng.',
        roomId: 'room_101',
        roomCode: 'P101',
        roomTitle: 'Căn hộ mini P101',
        renterName: 'Nguyễn Văn A & Trần Thị B',
        createdAt: now,
      );

      expect(notification.type, equals(HostNotificationType.pendingAction));
      expect(notification.title, equals('Thông báo có người ở ghép mới'));
      expect(notification.displayRoomCode, equals('P101'));
      expect(notification.displayRoomCode.contains('#OG-'), isFalse);
      expect(notification.displayRoomCode.contains('#LT-'), isFalse);
      expect(notification.renterName, equals('Nguyễn Văn A & Trần Thị B'));
    });
  });
}
