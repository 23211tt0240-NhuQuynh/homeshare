import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/push_notification_service.dart';

void main() {
  group('1. PushNotificationPayload - Parsing & Validation', () {
    test('Parse đầy đủ payload chuẩn từ map', () {
      final map = {
        'type': 'chat_message',
        'targetId': 'chat_123',
        'senderId': 'user_abc',
        'notificationId': 'notif_999',
        'route': '/chat/chat_123',
      };

      final payload = PushNotificationPayload.fromMap(
        map,
        title: 'Tin nhắn mới',
        body: 'Xin chào bạn!',
      );

      expect(payload.type, 'chat_message');
      expect(payload.targetId, 'chat_123');
      expect(payload.senderId, 'user_abc');
      expect(payload.notificationId, 'notif_999');
      expect(payload.route, '/chat/chat_123');
      expect(payload.title, 'Tin nhắn mới');
      expect(payload.body, 'Xin chào bạn!');
      expect(payload.isValid, isTrue);
    });

    test(
      'Xử lý payload thiếu dữ liệu - không bao giờ ném Exception (Crash)',
      () {
        final emptyPayload = PushNotificationPayload.fromMap({});
        expect(emptyPayload.type, 'system');
        expect(emptyPayload.targetId, isEmpty);
        expect(emptyPayload.senderId, isEmpty);
        expect(emptyPayload.notificationId, isEmpty);
        expect(emptyPayload.isValid, isFalse);

        final nullPayload = PushNotificationPayload.fromMap({
          'type': null,
          'targetId': null,
          'senderId': null,
          'notificationId': null,
        });
        expect(nullPayload.type, 'system');
        expect(nullPayload.targetId, isEmpty);
        expect(nullPayload.isValid, isFalse);
      },
    );

    test(
      'Fallback khóa dữ liệu tương thích ngược (bookingId, roomId, postId, chatId)',
      () {
        final bookingMap = {
          'type': 'booking',
          'bookingId': 'bk_001',
          'id': 'notif_b1',
        };
        final bookingPayload = PushNotificationPayload.fromMap(bookingMap);
        expect(bookingPayload.targetId, 'bk_001');
        expect(bookingPayload.notificationId, 'notif_b1');

        final roomMap = {'type': 'roommate_invitation', 'roomId': 'room_789'};
        final roomPayload = PushNotificationPayload.fromMap(roomMap);
        expect(roomPayload.type, 'roommate_message');
        expect(roomPayload.targetId, 'room_789');
      },
    );
  });

  group('2. Ánh xạ type sang màn hình đích (NotificationRouterLogic)', () {
    test('Ánh xạ chat_message -> chat', () {
      final payload = PushNotificationPayload.fromMap({
        'type': 'chat_message',
        'targetId': 'conv_123',
      });
      final dest = NotificationRouterLogic.resolveDestination(
        payload,
        userRole: 'renter',
      );
      expect(dest, NotificationRouteDestination.chat);
    });

    test('Ánh xạ booking_created -> bookingDetailHost', () {
      final payload = PushNotificationPayload.fromMap({
        'type': 'booking_created',
        'targetId': 'b_100',
      });
      final dest = NotificationRouterLogic.resolveDestination(
        payload,
        userRole: 'host',
      );
      expect(dest, NotificationRouteDestination.bookingDetailHost);
    });

    test(
      'Ánh xạ booking_approved / booking_rejected -> bookingDetailRenter',
      () {
        final approvedPayload = PushNotificationPayload.fromMap({
          'type': 'booking_approved',
          'targetId': 'b_101',
        });
        expect(
          NotificationRouterLogic.resolveDestination(
            approvedPayload,
            userRole: 'renter',
          ),
          NotificationRouteDestination.bookingDetailRenter,
        );

        final rejectedPayload = PushNotificationPayload.fromMap({
          'type': 'booking_rejected',
          'targetId': 'b_102',
        });
        expect(
          NotificationRouterLogic.resolveDestination(
            rejectedPayload,
            userRole: 'renter',
          ),
          NotificationRouteDestination.bookingDetailRenter,
        );
      },
    );

    test('Ánh xạ post_approved / post_rejected -> roomDetail', () {
      final approvedPayload = PushNotificationPayload.fromMap({
        'type': 'post_approved',
        'targetId': 'room_456',
      });
      expect(
        NotificationRouterLogic.resolveDestination(
          approvedPayload,
          userRole: 'host',
        ),
        NotificationRouteDestination.roomDetail,
      );

      final rejectedPayload = PushNotificationPayload.fromMap({
        'type': 'post_rejected',
        'targetId': 'room_456',
      });
      expect(
        NotificationRouterLogic.resolveDestination(
          rejectedPayload,
          userRole: 'host',
        ),
        NotificationRouteDestination.roomDetail,
      );
    });

    test('Ánh xạ roommate_message -> roommatePost', () {
      final payload = PushNotificationPayload.fromMap({
        'type': 'roommate_message',
        'targetId': 'rm_789',
      });
      expect(
        NotificationRouterLogic.resolveDestination(payload, userRole: 'renter'),
        NotificationRouteDestination.roommatePost,
      );
    });

    test('Ánh xạ system -> systemNotifications', () {
      final payload = PushNotificationPayload.fromMap({
        'type': 'system',
        'targetId': 'sys_001',
      });
      expect(
        NotificationRouterLogic.resolveDestination(payload, userRole: 'renter'),
        NotificationRouteDestination.systemNotifications,
      );
    });
  });

  group(
    '3. Xử lý Trạng thái Đăng nhập & Không điều hướng khi đối tượng không tồn tại',
    () {
      test('Nếu người dùng chưa đăng nhập -> trả về loginRequired', () async {
        final payload = PushNotificationPayload.fromMap({
          'type': 'booking_approved',
          'targetId': 'b_999',
        });

        final result = await NotificationRouterLogic.prepareNavigation(
          payload: payload,
          isAuthenticated: false,
          userRole: null,
          checkTargetExists: (type, targetId) async => true,
        );

        expect(result.status, NavigationResultStatus.loginRequired);
        expect(result.pendingPayload, equals(payload));
      });

      test(
        'Khi đối tượng KHÔNG tồn tại -> trả về targetNotFound, không điều hướng và không crash',
        () async {
          final payload = PushNotificationPayload.fromMap({
            'type': 'booking_approved',
            'targetId': 'b_deleted',
          });

          final result = await NotificationRouterLogic.prepareNavigation(
            payload: payload,
            isAuthenticated: true,
            userRole: 'renter',
            checkTargetExists: (type, targetId) async =>
                false, // Báo không tồn tại
          );

          expect(result.status, NavigationResultStatus.targetNotFound);
          expect(result.errorMessage, contains('không tồn tại hoặc đã bị xóa'));
        },
      );

      test('Khi đối tượng hợp lệ & đã đăng nhập -> trả về ready', () async {
        final payload = PushNotificationPayload.fromMap({
          'type': 'chat_message',
          'targetId': 'chat_valid',
        });

        final result = await NotificationRouterLogic.prepareNavigation(
          payload: payload,
          isAuthenticated: true,
          userRole: 'renter',
          checkTargetExists: (type, targetId) async => true,
        );

        expect(result.status, NavigationResultStatus.ready);
        expect(result.destination, NotificationRouteDestination.chat);
      });
    },
  );

  group(
    '4. Chống hiển thị notification trùng lặp (NotificationDeduplicator)',
    () {
      late NotificationDeduplicator deduplicator;

      setUp(() {
        deduplicator = NotificationDeduplicator(
          ttl: const Duration(seconds: 10),
        );
      });

      test('Thông báo đầu tiên được phép xử lý', () {
        expect(deduplicator.shouldProcess('notif_1'), isTrue);
      });

      test('Thông báo trùng ID trong khoảng thời gian TTL bị chặn', () {
        expect(deduplicator.shouldProcess('notif_1'), isTrue);
        // Gửi lại ngay lập tức
        expect(deduplicator.shouldProcess('notif_1'), isFalse);
      });

      test('Thông báo khác ID vẫn được phép xử lý bình thường', () {
        expect(deduplicator.shouldProcess('notif_1'), isTrue);
        expect(deduplicator.shouldProcess('notif_2'), isTrue);
      });

      test('Sau khi reset hoặc ID rỗng thì xử lý an toàn', () {
        deduplicator.shouldProcess('notif_1');
        deduplicator.reset();
        expect(deduplicator.shouldProcess('notif_1'), isTrue);
        expect(deduplicator.shouldProcess(''), isTrue);
      });
    },
  );

  group('5. Quản lý lưu và xóa FCM Token (FcmTokenManager)', () {
    test('Xác thực tính hợp lệ của FCM token', () {
      expect(FcmTokenManager.isTokenValid(null), isFalse);
      expect(FcmTokenManager.isTokenValid(''), isFalse);
      expect(FcmTokenManager.isTokenValid('   '), isFalse);
      expect(FcmTokenManager.isTokenValid('abc'), isFalse); // Quá ngắn
      expect(
        FcmTokenManager.isTokenValid('fcm_token_valid_sample_string_123456789'),
        isTrue,
      );
    });

    test('Không lưu trùng token khi thêm vào danh sách nhiều thiết bị', () {
      final currentTokens = ['token_device_A', 'token_device_B'];

      // Thêm token mới
      final added = FcmTokenManager.deduplicateTokens(
        currentTokens,
        'token_device_C',
      );
      expect(added, ['token_device_A', 'token_device_B', 'token_device_C']);

      // Thêm token đã tồn tại -> không bị duplicate
      final duplicated = FcmTokenManager.deduplicateTokens(
        added,
        'token_device_A',
      );
      expect(duplicated, [
        'token_device_A',
        'token_device_B',
        'token_device_C',
      ]);
    });

    test('Xóa token thiết bị hiện tại khi đăng xuất', () {
      final currentTokens = [
        'token_device_A',
        'token_device_B',
        'token_device_C',
      ];

      final remaining = FcmTokenManager.removeToken(
        currentTokens,
        'token_device_B',
      );
      expect(remaining, ['token_device_A', 'token_device_C']);
      expect(remaining.contains('token_device_B'), isFalse);
    });

    test('Tạo document data lưu trữ Firestore chuẩn xác', () {
      final data = FcmTokenManager.buildTokenDocData(
        'sample_token',
        platform: 'android',
        deviceId: 'device_01',
      );

      expect(data['token'], 'sample_token');
      expect(data['platform'], 'android');
      expect(data['deviceId'], 'device_01');
      expect(data.containsKey('updatedAt'), isTrue);
    });
  });
}
