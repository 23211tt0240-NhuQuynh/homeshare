import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/room_model.dart';
import '../../data/models/roommate_post_model.dart';
import '../../firebase_options.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/chat/screens/chat_detail_screen.dart';
import '../../features/host/notifications/screens/host_notifications_screen.dart';
import '../../features/renter/screens/renter_bookings_screen.dart';
import '../../features/renter/screens/room_detail_screen.dart';
import '../../features/renter/screens/roommate_post_detail_screen.dart';
import '../../features/renter/screens/user_notifications_screen.dart';
import 'call_push_service.dart'
    show navigatorKey, callNotificationChannelId, IncomingCallRouter;
import 'call_service.dart' show CallSession;

/// ID kênh thông báo tiêu chuẩn cho HomeShare
const String generalNotificationChannelId = 'homeshare_general_channel';
const String generalNotificationChannelName = 'Thông báo chung';
const String generalNotificationChannelDescription =
    'Nhận thông báo tin nhắn, trạng thái đặt phòng, bài đăng và lời mời ở ghép';

/// 1. Model dữ liệu chuẩn của Notification Payload
class PushNotificationPayload {
  final String type;
  final String targetId;
  final String senderId;
  final String notificationId;
  final String route;
  final String title;
  final String body;
  final Map<String, dynamic> rawData;

  const PushNotificationPayload({
    required this.type,
    required this.targetId,
    required this.senderId,
    required this.notificationId,
    required this.route,
    required this.title,
    required this.body,
    required this.rawData,
  });

  /// Factory parse an toàn từ Map, không bao giờ ném Exception
  factory PushNotificationPayload.fromMap(
    Map<dynamic, dynamic>? raw, {
    String title = '',
    String body = '',
  }) {
    if (raw == null || raw.isEmpty) {
      return PushNotificationPayload(
        type: 'system',
        targetId: '',
        senderId: '',
        notificationId: '',
        route: '',
        title: title,
        body: body,
        rawData: const {},
      );
    }

    final map = <String, dynamic>{};
    raw.forEach((k, v) {
      if (k != null) {
        map[k.toString()] = v;
      }
    });

    final rawType = (map['type'] ?? map['notificationType'] ?? 'system')
        .toString();
    String normalizedType = rawType.toLowerCase();

    // Chuẩn hóa loại thông báo tương thích ngược
    if (normalizedType == 'roommate_invitation' ||
        normalizedType == 'roommate') {
      normalizedType = 'roommate_message';
    } else if (normalizedType == 'pendingaction') {
      normalizedType = 'booking_created';
    } else if (normalizedType == 'booking' ||
        normalizedType == 'booking_approved') {
      normalizedType = 'booking_approved';
    } else if (normalizedType == 'cancellation_invoice' ||
        normalizedType == 'refund') {
      normalizedType = 'booking_rejected';
    }

    final targetId =
        (map['targetId'] ??
                map['bookingId'] ??
                map['roomId'] ??
                map['postId'] ??
                map['chatId'] ??
                map['conversationId'] ??
                '')
            .toString();

    final senderId = (map['senderId'] ?? map['nguoiGuiId'] ?? '').toString();
    final notificationId = (map['notificationId'] ?? map['id'] ?? '')
        .toString();
    final route = (map['route'] ?? '').toString();
    final parsedTitle = (map['title'] ?? map['tieuDe'] ?? title).toString();
    final parsedBody = (map['body'] ?? map['message'] ?? map['noiDung'] ?? body)
        .toString();

    return PushNotificationPayload(
      type: normalizedType,
      targetId: targetId,
      senderId: senderId,
      notificationId: notificationId,
      route: route,
      title: parsedTitle,
      body: parsedBody,
      rawData: map,
    );
  }

  bool get isValid =>
      rawData.isNotEmpty && (targetId.isNotEmpty || route.isNotEmpty);

  Map<String, dynamic> toMap() => {
    'type': type,
    'targetId': targetId,
    'senderId': senderId,
    'notificationId': notificationId,
    'route': route,
    'title': title,
    'body': body,
    'rawData': rawData,
  };

  String toJson() => jsonEncode(toMap());
}

/// 2. Danh sách các điểm đến điều hướng
enum NotificationRouteDestination {
  chat,
  bookingDetailHost,
  bookingDetailRenter,
  roomDetail,
  roommatePost,
  systemNotifications,
  unknown,
}

enum NavigationResultStatus {
  ready,
  loginRequired,
  targetNotFound,
  invalidPayload,
}

class NotificationNavigationResult {
  final NavigationResultStatus status;
  final NotificationRouteDestination? destination;
  final PushNotificationPayload? payload;
  final PushNotificationPayload? pendingPayload;
  final String? errorMessage;

  const NotificationNavigationResult({
    required this.status,
    this.destination,
    this.payload,
    this.pendingPayload,
    this.errorMessage,
  });
}

/// 3. Bộ định tuyến logic (Pure Router Logic - Testable độc lập)
class NotificationRouterLogic {
  static NotificationRouteDestination resolveDestination(
    PushNotificationPayload payload, {
    required String? userRole,
  }) {
    switch (payload.type) {
      case 'chat_message':
        return NotificationRouteDestination.chat;
      case 'booking_created':
        return NotificationRouteDestination.bookingDetailHost;
      case 'booking_approved':
      case 'booking_rejected':
        return NotificationRouteDestination.bookingDetailRenter;
      case 'post_approved':
      case 'post_rejected':
        return NotificationRouteDestination.roomDetail;
      case 'roommate_message':
        return NotificationRouteDestination.roommatePost;
      case 'system':
        return NotificationRouteDestination.systemNotifications;
      default:
        return NotificationRouteDestination.unknown;
    }
  }

  static Future<NotificationNavigationResult> prepareNavigation({
    required PushNotificationPayload payload,
    required bool isAuthenticated,
    required String? userRole,
    required Future<bool> Function(String type, String targetId)
    checkTargetExists,
  }) async {
    if (!isAuthenticated) {
      return NotificationNavigationResult(
        status: NavigationResultStatus.loginRequired,
        pendingPayload: payload,
      );
    }

    final dest = resolveDestination(payload, userRole: userRole);
    if (dest == NotificationRouteDestination.systemNotifications ||
        dest == NotificationRouteDestination.unknown) {
      return NotificationNavigationResult(
        status: NavigationResultStatus.ready,
        destination: dest,
        payload: payload,
      );
    }

    if (payload.targetId.isNotEmpty) {
      final exists = await checkTargetExists(payload.type, payload.targetId);
      if (!exists) {
        return const NotificationNavigationResult(
          status: NavigationResultStatus.targetNotFound,
          errorMessage: 'Đối tượng không tồn tại hoặc đã bị xóa.',
        );
      }
    }

    return NotificationNavigationResult(
      status: NavigationResultStatus.ready,
      destination: dest,
      payload: payload,
    );
  }
}

/// 4. Quản lý chống trùng thông báo (Deduplicator)
class NotificationDeduplicator {
  final Duration ttl;
  final Map<String, DateTime> _recentTimestamps = {};

  NotificationDeduplicator({this.ttl = const Duration(seconds: 10)});

  bool shouldProcess(String? notificationId) {
    if (notificationId == null || notificationId.trim().isEmpty) {
      return true;
    }
    final now = DateTime.now();
    _cleanExpired(now);

    final cleanId = notificationId.trim();
    if (_recentTimestamps.containsKey(cleanId)) {
      return false; // Trùng lặp trong TTL
    }

    _recentTimestamps[cleanId] = now;
    return true;
  }

  void _cleanExpired(DateTime now) {
    _recentTimestamps.removeWhere((_, time) => now.difference(time) > ttl);
  }

  void reset() {
    _recentTimestamps.clear();
  }
}

/// 5. Quản lý FCM Tokens (Hỗ trợ đa thiết bị, không trùng lặp)
class FcmTokenManager {
  static bool isTokenValid(String? token) {
    if (token == null) return false;
    final trimmed = token.trim();
    return trimmed.isNotEmpty && trimmed.length >= 10;
  }

  static List<String> deduplicateTokens(
    List<String> existing,
    String newToken,
  ) {
    final cleanNew = newToken.trim();
    if (!isTokenValid(cleanNew)) return List.from(existing);
    final set = existing.toSet();
    set.add(cleanNew);
    return set.toList();
  }

  static List<String> removeToken(List<String> existing, String tokenToRemove) {
    final set = existing.toSet();
    set.remove(tokenToRemove.trim());
    return set.toList();
  }

  static Map<String, dynamic> buildTokenDocData(
    String token, {
    String platform = 'android',
    String? deviceId,
  }) {
    final data = <String, dynamic>{
      'token': token.trim(),
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (deviceId != null) {
      data['deviceId'] = deviceId;
    }
    return data;
  }
}

/// 6. Background message handler toàn cục
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  // Nếu là cuộc gọi, xử lý riêng
  if (message.data['type'] == 'incoming_call') {
    return;
  }
}

/// 7. Dịch vụ Push Notification chính của ứng dụng
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  static final NotificationDeduplicator _deduplicator =
      NotificationDeduplicator();

  static PushNotificationPayload? pendingPayload;
  static String? _currentDeviceToken;

  /// Khởi tạo Push Notification Service (gọi trong main() trước runApp)
  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Cấu hình local notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _localPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payloadStr = response.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final map = jsonDecode(payloadStr) as Map<String, dynamic>;
              final payload = PushNotificationPayload.fromMap(map);
              handlePayloadNavigation(payload);
            } catch (e) {
              debugPrint('[PushNotification] Error decoding payload: $e');
            }
          }
        },
      );

      // Tạo các kênh Android Notification Channel
      final androidPlatform = _localPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlatform != null) {
        // 1. Kênh thông báo chung HomeShare
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            generalNotificationChannelId,
            generalNotificationChannelName,
            description: generalNotificationChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        // 2. Kênh cuộc gọi (tương thích call_push_service)
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            callNotificationChannelId,
            'Cuộc gọi',
            description: 'Chuông cuộc gọi đến khi ứng dụng đang tắt',
            importance: Importance.max,
            playSound: true,
          ),
        );
      }

      // Lắng nghe khi app đang mở (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Lắng nghe khi người dùng bấm vào notification từ nền (Background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageOpened(message);
      });

      // Kiểm tra xem app có được mở từ trạng thái bị tắt hoàn toàn (Terminated)
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpened(initialMessage);
      }
    } catch (e) {
      debugPrint('[PushNotification] Init error: $e');
    }
  }

  /// Gắn mã token của máy hiện tại vào user Firestore sau khi đăng nhập
  static Future<void> bindUser(String uid) async {
    if (uid.isEmpty) return;

    try {
      // 1. Xin quyền thông báo (Android 13+ & iOS)
      await Permission.notification.request();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // 2. Lấy FCM Token
      final token = await messaging.getToken();
      if (FcmTokenManager.isTokenValid(token)) {
        _currentDeviceToken = token;
        await _saveUserToken(uid, token!);
      }

      // 3. Theo dõi khi token bị thay đổi
      messaging.onTokenRefresh.listen((newToken) async {
        if (FcmTokenManager.isTokenValid(newToken)) {
          _currentDeviceToken = newToken;
          await _saveUserToken(uid, newToken);
        }
      });

      // 4. Nếu có pending payload đang chờ đăng nhập, thực hiện điều hướng ngay
      if (pendingPayload != null) {
        final p = pendingPayload!;
        pendingPayload = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handlePayloadNavigation(p);
        });
      }
    } catch (e) {
      debugPrint('[PushNotification] bindUser error: $e');
    }
  }

  /// Hủy liên kết token khi người dùng đăng xuất
  static Future<void> unbindUser(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token =
          _currentDeviceToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final cleanToken = token.trim();
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

        final batch = FirebaseFirestore.instance.batch();
        // Xóa document token của máy này trong subcollection fcm_tokens
        final tokenDocRef = userRef.collection('fcm_tokens').doc(cleanToken);
        batch.delete(tokenDocRef);

        // Xóa khỏi array fcmTokens
        batch.set(userRef, {
          'fcmTokens': FieldValue.arrayRemove([cleanToken]),
        }, SetOptions(merge: true));

        // Nếu fcmToken chính trùng với token này, xóa để tránh gửi nhầm
        final userDoc = await userRef.get();
        if (userDoc.exists && userDoc.data()?['fcmToken'] == cleanToken) {
          batch.set(userRef, {
            'fcmToken': FieldValue.delete(),
          }, SetOptions(merge: true));
        }

        await batch.commit();
      }
      _currentDeviceToken = null;
    } catch (e) {
      debugPrint('[PushNotification] unbindUser error: $e');
    }
  }

  static Future<void> _saveUserToken(String uid, String token) async {
    final cleanToken = token.trim();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final batch = FirebaseFirestore.instance.batch();
    // 1. Lưu subcollection fcm_tokens (đảm bảo không bao giờ trùng lặp docId)
    final tokenDoc = userRef.collection('fcm_tokens').doc(cleanToken);
    batch.set(
      tokenDoc,
      FcmTokenManager.buildTokenDocData(cleanToken),
      SetOptions(merge: true),
    );

    // 2. Lưu array fcmTokens và single fcmToken (backward compatible 100%)
    batch.set(userRef, {
      'fcmToken': cleanToken,
      'fcmTokens': FieldValue.arrayUnion([cleanToken]),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Xử lý hiển thị thông báo khi app đang mở (Foreground)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Nếu là cuộc gọi thì nhường cho call_push_service
    if (message.data['type'] == 'incoming_call') return;

    final notifId = message.data['notificationId'] ?? message.messageId ?? '';
    if (!_deduplicator.shouldProcess(notifId)) return;

    final title =
        message.notification?.title ?? message.data['title'] ?? 'HomeShare';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        '';

    final payload = PushNotificationPayload.fromMap(
      message.data,
      title: title,
      body: body,
    );

    final androidDetails = AndroidNotificationDetails(
      generalNotificationChannelId,
      generalNotificationChannelName,
      channelDescription: generalNotificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    final localId = notifId.hashCode & 0x7FFFFFFF;
    await _localPlugin.show(
      localId,
      title,
      body,
      details,
      payload: payload.toJson(),
    );
  }

  /// Xử lý khi người dùng nhấn vào thông báo (Background / Terminated)
  static void _handleMessageOpened(RemoteMessage message) {
    if (message.data['type'] == 'incoming_call') {
      final callId = message.data['callId']?.toString() ?? '';
      if (callId.isNotEmpty) {
        FirebaseFirestore.instance.collection('calls').doc(callId).get().then((
          doc,
        ) {
          if (doc.exists) {
            IncomingCallRouter.show(CallSession.fromDoc(doc));
          }
        });
      }
      return;
    }

    final payload = PushNotificationPayload.fromMap(
      message.data,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
    );
    handlePayloadNavigation(payload);
  }

  /// Kiểm tra sự tồn tại của đối tượng đích trong Firestore
  static Future<bool> checkTargetExists(String type, String targetId) async {
    if (targetId.isEmpty) return false;
    final db = FirebaseFirestore.instance;

    try {
      switch (type) {
        case 'chat_message':
          final doc = await db.collection('chats').doc(targetId).get();
          return doc.exists;
        case 'booking_created':
        case 'booking_approved':
        case 'booking_rejected':
          final doc = await db.collection('bookings').doc(targetId).get();
          return doc.exists;
        case 'post_approved':
        case 'post_rejected':
          final doc = await db.collection('rooms').doc(targetId).get();
          if (doc.exists) return true;
          final postDoc = await db.collection('posts').doc(targetId).get();
          return postDoc.exists;
        case 'roommate_message':
          final doc = await db.collection('posts').doc(targetId).get();
          if (doc.exists) return true;
          final roomDoc = await db.collection('rooms').doc(targetId).get();
          return roomDoc.exists;
        default:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Thực hiện điều hướng an toàn vào màn hình đích
  static Future<void> handlePayloadNavigation(
    PushNotificationPayload payload,
  ) async {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      // Nếu navigator chưa sẵn sàng, lưu tạm payload để điều hướng sau
      pendingPayload = payload;
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final isAuthenticated = user != null;

    final result = await NotificationRouterLogic.prepareNavigation(
      payload: payload,
      isAuthenticated: isAuthenticated,
      userRole: null, // Sẽ tự điều hướng màn phù hợp
      checkTargetExists: checkTargetExists,
    );

    if (result.status == NavigationResultStatus.loginRequired) {
      pendingPayload = payload;
      nav.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (result.status == NavigationResultStatus.targetNotFound) {
      _showToast(
        nav,
        result.errorMessage ?? 'Đối tượng không tồn tại hoặc đã bị xóa.',
      );
      return;
    }

    if (result.status == NavigationResultStatus.ready) {
      final dest =
          result.destination ??
          NotificationRouteDestination.systemNotifications;
      final targetId = payload.targetId;

      switch (dest) {
        case NotificationRouteDestination.chat:
          final currentUid = user?.uid ?? '';
          final currentName = user?.displayName ?? 'Tôi';
          final otherId =
              payload.senderId.isNotEmpty && payload.senderId != currentUid
              ? payload.senderId
              : targetId;
          final otherName = payload.title.isNotEmpty
              ? payload.title
              : 'Người dùng';
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                currentUserId: currentUid,
                currentUserName: currentName,
                receiverId: otherId,
                receiverName: otherName,
              ),
            ),
          );
          break;

        case NotificationRouteDestination.bookingDetailHost:
          nav.push(
            MaterialPageRoute(builder: (_) => const HostNotificationsScreen()),
          );
          break;

        case NotificationRouteDestination.bookingDetailRenter:
          nav.push(
            MaterialPageRoute(builder: (_) => const RenterBookingsScreen()),
          );
          break;

        case NotificationRouteDestination.roomDetail:
          try {
            final doc = await FirebaseFirestore.instance
                .collection('rooms')
                .doc(targetId)
                .get();
            if (doc.exists && doc.data() != null) {
              final room = RoomModel.fromFirestore(doc);
              nav.push(
                MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
              );
            } else {
              _showToast(nav, 'Bài đăng phòng không tồn tại hoặc đã bị xóa.');
            }
          } catch (e) {
            debugPrint('[PushNotificationService] Lỗi tải chi tiết phòng: $e');
          }
          break;

        case NotificationRouteDestination.roommatePost:
          try {
            final doc = await FirebaseFirestore.instance
                .collection('posts')
                .doc(targetId)
                .get();
            if (doc.exists && doc.data() != null) {
              final post = RoommatePostModel.fromFirestore(doc);
              nav.push(
                MaterialPageRoute(
                  builder: (_) => RoommatePostDetailScreen(post: post),
                ),
              );
            } else {
              _showToast(nav, 'Bài đăng ở ghép không tồn tại hoặc đã bị xóa.');
            }
          } catch (e) {
            debugPrint(
              '[PushNotificationService] Lỗi tải chi tiết bài ở ghép: $e',
            );
          }
          break;

        case NotificationRouteDestination.systemNotifications:
        case NotificationRouteDestination.unknown:
          nav.push(
            MaterialPageRoute(builder: (_) => const UserNotificationsScreen()),
          );
          break;
      }
    }
  }

  static void _showToast(NavigatorState nav, String message) {
    if (!nav.mounted) return;
    ScaffoldMessenger.of(nav.context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

