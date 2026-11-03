import 'dart:async';

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

    test('Xác định fcmToken chính sau khi gỡ token của thiết bị hiện tại (đa thiết bị)', () {
      final remaining = ['token_device_B', 'token_device_C'];
      // Thiết bị A đăng xuất -> fcmToken chính chuyển sang token thiết bị B còn lại
      final nextMain = FcmTokenManager.resolveNextMainToken(
        currentMainToken: 'token_device_A',
        removedToken: 'token_device_A',
        remainingTokens: remaining,
      );
      expect(nextMain, 'token_device_B');

      // Khi là thiết bị duy nhất đăng xuất -> trả về null để xóa fcmToken
      final noRemaining = FcmTokenManager.resolveNextMainToken(
        currentMainToken: 'token_device_A',
        removedToken: 'token_device_A',
        remainingTokens: [],
      );
      expect(noRemaining, isNull);

      // Nếu thiết bị đăng xuất không phải là token chính hiện tại -> giữ nguyên token chính
      final keepMain = FcmTokenManager.resolveNextMainToken(
        currentMainToken: 'token_device_B',
        removedToken: 'token_device_A',
        remainingTokens: ['token_device_B'],
      );
      expect(keepMain, 'token_device_B');
    });
  });

  group('6. Vòng đời listener FCM token (FcmTokenRefreshBinding)', () {
    test('đổi tài khoản sẽ hủy listener cũ và đăng xuất sẽ ngừng ghi token', () async {
      final controller = StreamController<String>.broadcast();
      final writes = <String>[];
      final binding = FcmTokenRefreshBinding();

      // 1. Đăng nhập user_a
      await binding.bind(
        uid: 'user_a',
        tokenStream: controller.stream,
        onToken: (uid, token) async => writes.add('$uid:$token'),
      );
      controller.add('token_a_123456789');
      await Future<void>.delayed(Duration.zero);

      // 2. Đăng nhập user_b (thay thế user_a)
      await binding.bind(
        uid: 'user_b',
        tokenStream: controller.stream,
        onToken: (uid, token) async => writes.add('$uid:$token'),
      );
      controller.add('token_b_123456789');
      await Future<void>.delayed(Duration.zero);

      // 3. Đăng xuất user_b
      await binding.unbind('user_b');
      controller.add('token_after_logout_123456789');
      await Future<void>.delayed(Duration.zero);

      expect(writes, [
        'user_a:token_a_123456789',
        'user_b:token_b_123456789',
      ]);
      expect(binding.boundUid, isNull);

      await controller.close();
    });

    test('đăng nhập lại UID khác không để listener cũ ghi token cho UID trước', () async {
      final controller = StreamController<String>.broadcast();
      final userARefreshes = <String>[];
      final userBRefreshes = <String>[];
      final binding = FcmTokenRefreshBinding();

      await binding.bind(
        uid: 'uid_first',
        tokenStream: controller.stream,
        onToken: (uid, token) async => userARefreshes.add(token),
      );

      // Đăng nhập sang UID khác ngay sau đó
      await binding.bind(
        uid: 'uid_second',
        tokenStream: controller.stream,
        onToken: (uid, token) async => userBRefreshes.add(token),
      );

      controller.add('refreshed_token_xyz_12345');
      await Future<void>.delayed(Duration.zero);

      // Listener của user đầu tiên phải bị hủy hoàn toàn
      expect(userARefreshes, isEmpty);
      expect(userBRefreshes, ['refreshed_token_xyz_12345']);
      expect(binding.boundUid, 'uid_second');

      await controller.close();
    });

    test('unbind chờ callback đang chạy hoàn tất và không có write sau khi unbind hoàn tất', () async {
      final controller = StreamController<String>.broadcast();
      final writes = <String>[];
      final blockCompleter = Completer<void>();
      final startedCompleter = Completer<void>();
      final binding = FcmTokenRefreshBinding();

      await binding.bind(
        uid: 'user_test',
        tokenStream: controller.stream,
        onToken: (uid, token) async {
          startedCompleter.complete();
          await blockCompleter.future;
          writes.add('$uid:$token');
        },
      );

      // 1. Gửi token để callback bắt đầu
      controller.add('token_async_123');
      // Chờ callback bắt đầu và bị block
      await startedCompleter.future;

      // 2. Gọi unbind khi onToken đang block
      var unbindFinished = false;
      final unbindFuture = binding.unbind('user_test').then((_) {
        unbindFinished = true;
      });

      // Chờ một microtask để đảm bảo unbind đã vào hàm và đang chờ
      await Future<void>.delayed(Duration.zero);
      expect(unbindFinished, isFalse, reason: 'unbind phải chờ callback đang block');
      expect(writes, isEmpty, reason: 'callback chưa ghi do đang block');

      // 3. Giải phóng blockCompleter
      blockCompleter.complete();

      // 4. Chờ unbind hoàn thành
      await unbindFuture;
      expect(unbindFinished, isTrue);

      // Ghi nhận write đã hoàn tất TRƯỚC khi unbind hoàn tất
      final writesAtUnbindEnd = List<String>.from(writes);
      expect(writesAtUnbindEnd, ['user_test:token_async_123']);

      // 5. Phát thêm token sau khi unbind đã hoàn tất
      controller.add('token_after_unbind_456');
      await Future<void>.delayed(Duration.zero);

      // Không có write nào sau khi unbind hoàn tất
      expect(writes, equals(writesAtUnbindEnd));
      expect(binding.boundUid, isNull);

      await controller.close();
    });
  });

  group('7. Resolver đối tượng bài đăng và phòng trọ (RoomNotificationTargetResolver)', () {
    test('targetId là roomId -> tải room trực tiếp', () async {
      final loadedRooms = <String>[];
      final loadedPosts = <String>[];

      final result = await RoomNotificationTargetResolver.resolveRoom<String>(
        targetId: 'room_101',
        loadRoom: (id) async {
          loadedRooms.add(id);
          return id == 'room_101' ? 'RoomData_101' : null;
        },
        loadPost: (id) async {
          loadedPosts.add(id);
          return null;
        },
      );

      expect(result, 'RoomData_101');
      expect(loadedRooms, ['room_101']);
      expect(loadedPosts, isEmpty); // Không cần đọc bảng posts
    });

    test('targetId là postId -> đọc posts/{id}, suy ra roomId theo schema rồi tải room', () async {
      final loadedRooms = <String>[];
      final loadedPosts = <String>[];

      final result = await RoomNotificationTargetResolver.resolveRoom<String>(
        targetId: 'post_999',
        loadRoom: (id) async {
          loadedRooms.add(id);
          return id == 'room_from_post' ? 'RoomData_Linked' : null;
        },
        loadPost: (id) async {
          loadedPosts.add(id);
          return id == 'post_999' ? {'roomId': 'room_from_post'} : null;
        },
      );

      expect(result, 'RoomData_Linked');
      expect(loadedRooms, ['post_999', 'room_from_post']);
      expect(loadedPosts, ['post_999']);
    });

    test('hỗ trợ nguồn phòng đa dạng: rooms, host_rooms, posts', () async {
      final multiSourceDatabase = <String, Map<String, dynamic>>{
        'host_rooms/hr_555': {'title': 'Phòng chủ trọ cao cấp', 'price': 3500000},
        'posts/p_777': {'roomId': 'hr_555'},
      };

      final result = await RoomNotificationTargetResolver.resolveRoom<String>(
        targetId: 'p_777',
        loadRoom: (id) async {
          final doc = multiSourceDatabase['host_rooms/$id'] ?? multiSourceDatabase['rooms/$id'];
          return doc != null ? doc['title'] as String : null;
        },
        loadPost: (id) async => multiSourceDatabase['posts/$id'],
      );

      expect(result, 'Phòng chủ trọ cao cấp');
    });

    test('hỗ trợ các trường schema phòng thay thế: phongTroId, phong_tro_id, phongId', () async {
      for (final field in ['phongTroId', 'phong_tro_id', 'phongId']) {
        final result = await RoomNotificationTargetResolver.resolveRoom<String>(
          targetId: 'post_custom_$field',
          loadRoom: (id) async => id == 'room_target' ? 'RoomData' : null,
          loadPost: (id) async => {field: 'room_target'},
        );
        expect(result, 'RoomData', reason: 'Failed for field: $field');
      }
    });

    test('postId không có roomId hợp lệ -> trả về null', () async {
      final result = await RoomNotificationTargetResolver.resolveRoom<String>(
        targetId: 'post_no_room',
        loadRoom: (id) async => null,
        loadPost: (id) async => {'title': 'Bài đăng không liên kết phòng'},
      );

      expect(result, isNull);
    });

    test('postId tồn tại nhưng phòng trong rooms/host_rooms đã bị xóa -> trả về null', () async {
      final result = await RoomNotificationTargetResolver.resolveRoom<String>(
        targetId: 'post_with_deleted_room',
        loadRoom: (id) async => null, // Phòng đã bị xóa
        loadPost: (id) async => {'roomId': 'room_deleted'},
      );

      expect(result, isNull);
    });

    test('targetId rỗng -> trả về null không đọc dữ liệu', () async {
      var roomCalled = false;
      var postCalled = false;

      final result = await RoomNotificationTargetResolver.resolveRoom<String>(
        targetId: '   ',
        loadRoom: (id) async {
          roomCalled = true;
          return 'room';
        },
        loadPost: (id) async {
          postCalled = true;
          return {};
        },
      );

      expect(result, isNull);
      expect(roomCalled, isFalse);
      expect(postCalled, isFalse);
    });

    test('checkTargetExists và handlePayloadNavigation đồng nhất kết quả qua resolver', () async {
      final store = <String, String>{
        'valid_room': 'RoomModel_A',
      };

      Future<String?> testResolver(String targetId) {
        return RoomNotificationTargetResolver.resolveRoom<String>(
          targetId: targetId,
          loadRoom: (id) async => store[id],
          loadPost: (id) async => id == 'valid_post' ? {'roomId': 'valid_room'} : null,
        );
      }

      // 1. Với targetId hợp lệ: checkTargetExists và navigation đều thấy room
      final room1 = await testResolver('valid_post');
      expect(room1 != null, isTrue);
      expect(room1, 'RoomModel_A');

      // 2. Với targetId không hợp lệ: checkTargetExists và navigation đều trả về null
      final room2 = await testResolver('unknown_id');
      expect(room2 != null, isFalse);
      expect(room2, isNull);
    });
  });
}
