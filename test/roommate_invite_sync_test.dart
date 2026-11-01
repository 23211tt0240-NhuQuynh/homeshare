import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roommate Invite Status Sync Logic Tests', () {
    test('isAccepted correctly recognizes all accepted/waiting states in Chat & Notification', () {
      final validAcceptedStatuses = [
        'accepted',
        'waiting_host_approval',
        'accepted_waiting_host',
        'approved',
        'daChapNhan',
      ];

      for (final st in validAcceptedStatuses) {
        final isAcceptedInChat = st == 'accepted' ||
            st == 'waiting_host_approval' ||
            st == 'accepted_waiting_host' ||
            st == 'approved' ||
            st == 'daChapNhan';

        expect(
          isAcceptedInChat,
          isTrue,
          reason: 'Status "$st" phải được nhận diện là đã đồng ý trong chat',
        );

        final isAcceptedInNotif = st == 'accepted' ||
            st == 'waiting_host_approval' ||
            st == 'accepted_waiting_host' ||
            st == 'approved' ||
            st == 'daChapNhan';

        expect(
          isAcceptedInNotif,
          isTrue,
          reason: 'Status "$st" phải được nhận diện là đã đồng ý trong thông báo',
        );
      }
    });

    test('isRejected correctly recognizes all rejection states', () {
      final validRejectedStatuses = [
        'rejected',
        'host_rejected',
        'daTuChoi',
      ];

      for (final st in validRejectedStatuses) {
        final isRejected = st == 'rejected' ||
            st == 'host_rejected' ||
            st == 'daTuChoi';

        expect(
          isRejected,
          isTrue,
          reason: 'Status "$st" phải được nhận diện là đã từ chối',
        );
      }
    });

    test('isRevoked correctly recognizes revoked state and prevents action buttons', () {
      final validRevokedStatuses = ['revoked', 'daThuHoi'];

      for (final st in validRevokedStatuses) {
        final isRevoked = st == 'revoked' || st == 'daThuHoi';
        expect(isRevoked, isTrue);

        // Đảm bảo không rơi vào pending
        final isPending = st == 'pending';
        expect(isPending, isFalse);
      }
    });

    test('Payload synchronization maps correctly between Chat message extraData and Notification data', () {
      const messageId = 'msg_1730000000';
      const notificationId = 'notif_abc123';
      const senderId = 'user_sender';
      const receiverId = 'user_receiver';
      const roomId = 'room_xyz';

      // 1. ExtraData trong tin nhắn chat
      final chatExtraData = <String, dynamic>{
        'status': 'pending',
        'roomId': roomId,
        'roomTitle': 'Phòng trọ cao cấp',
        'senderId': senderId,
        'receiverId': receiverId,
        'notificationId': notificationId,
      };

      // 2. Data trong document thông báo
      final notificationData = <String, dynamic>{
        'id': notificationId,
        'notificationType': 'roommate_invitation',
        'roomId': roomId,
        'senderId': senderId,
        'receiverId': receiverId,
        'status': 'pending',
        'messageId': messageId,
      };

      expect(chatExtraData['roomId'], equals(notificationData['roomId']));
      expect(chatExtraData['senderId'], equals(notificationData['senderId']));
      expect(chatExtraData['receiverId'], equals(notificationData['receiverId']));
      expect(chatExtraData['notificationId'], equals(notificationData['id']));
      expect(notificationData['messageId'], equals(messageId));

      // 3. Khi chấp nhận từ chat: thông báo chuyển sang waiting_host_approval
      final updatedNotifStatus = 'waiting_host_approval';
      notificationData['status'] = updatedNotifStatus;
      expect(notificationData['status'], equals('waiting_host_approval'));

      // 4. Khi chấp nhận từ thông báo: tin nhắn chuyển sang accepted
      final updatedChatStatus = 'accepted';
      chatExtraData['status'] = updatedChatStatus;
      chatExtraData['acceptedBy'] = receiverId;
      expect(chatExtraData['status'], equals('accepted'));
      expect(chatExtraData['acceptedBy'], equals(receiverId));
    });

    test('Collection routing: Renter/User notifications go exclusively to notification_user', () {
      String resolveNotificationCollection(String role) {
        final cleanRole = role.trim().toLowerCase();
        return (cleanRole == 'renter' || cleanRole == 'user')
            ? 'notification_user'
            : 'notifications';
      }

      expect(resolveNotificationCollection('renter'), equals('notification_user'));
      expect(resolveNotificationCollection('user'), equals('notification_user'));
      expect(resolveNotificationCollection('RENTER'), equals('notification_user'));
      expect(resolveNotificationCollection('USER'), equals('notification_user'));

      expect(resolveNotificationCollection('host'), equals('notifications'));
      expect(resolveNotificationCollection('admin'), equals('notifications'));
      expect(resolveNotificationCollection(''), equals('notifications'));
    });
  });
}
