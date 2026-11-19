import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../../core/utils/notification_write_utils.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'my_homes_screen.dart';
import 'renter_bookings_screen.dart';
import 'room_detail_screen.dart';
import 'roommate_community_screen.dart';
import 'roommate_post_detail_screen.dart';

/// Provider stream danh sách thông báo của User (Renter), đồng bộ hợp nhất từ `notification_user` và `notifications` cũ
final userNotificationsStreamProvider =
    StreamProvider.autoDispose<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final currentUserId = ref.watch(authStateProvider).value?.uid ?? '';
  if (currentUserId.isEmpty) {
    return Stream.value([]);
  }

  final controller = StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> legacyDocs = [];

  void emitMerged() {
    if (controller.isClosed) return;
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> map = {};
    for (final doc in legacyDocs) {
      map[doc.id] = doc;
    }
    for (final doc in userDocs) {
      map[doc.id] = doc;
    }

    // Chỉ lấy thông báo của user (người thuê / ở ghép), loại trừ thông báo của chủ trọ và cảnh báo vi phạm
    final docs = map.values.where((doc) {
      final data = doc.data();
      final role = (data['recipientRole'] ?? '').toString().toLowerCase();
      final type = (data['notificationType'] ?? data['type'] ?? '').toString();
      if (role == 'host' || type == 'warning') return false;
      return true;
    }).toList();

    // Sắp xếp client-side theo thời gian giảm dần (mới nhất lên đầu)
    docs.sort((a, b) {
      final tA = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    controller.add(docs);
  }

  final filter = Filter.or(
    Filter('receiverId', isEqualTo: currentUserId),
    Filter('recipientId', isEqualTo: currentUserId),
    Filter('userId', isEqualTo: currentUserId),
    Filter('nguoiNhanId', isEqualTo: currentUserId),
  );

  final subUser = FirebaseFirestore.instance
      .collection(FirestoreCollections.notificationUser)
      .where(filter)
      .snapshots()
      .listen(
        (snap) {
          userDocs = snap.docs;
          emitMerged();
        },
        onError: (err) {
          debugPrint('Error listening to notification_user: $err');
          emitMerged();
        },
      );

  final subLegacy = FirebaseFirestore.instance
      .collection('notifications')
      .where(filter)
      .snapshots()
      .listen(
        (snap) {
          legacyDocs = snap.docs;
          emitMerged();
        },
        onError: (err) {
          debugPrint('Error listening to notifications: $err');
          emitMerged();
        },
      );

  ref.onDispose(() {
    subUser.cancel();
    subLegacy.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider đếm số lượng thông báo chưa đọc của User
final userUnreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifs = ref.watch(userNotificationsStreamProvider).value ?? [];
  return notifs.where((doc) {
    final data = doc.data();
    final isRead = data['isRead'] == true || data['daDoc'] == true;
    return !isRead;
  }).length;
});

class _NotificationVisualConfig {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String categoryBadge;
  final Color badgeBg;
  final Color badgeColor;

  const _NotificationVisualConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.categoryBadge,
    required this.badgeBg,
    required this.badgeColor,
  });
}

class UserNotificationsScreen extends ConsumerStatefulWidget {
  const UserNotificationsScreen({super.key});

  @override
  ConsumerState<UserNotificationsScreen> createState() => _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends ConsumerState<UserNotificationsScreen> {
  Future<void> _markAllAsRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final isRead = doc.data()['isRead'] == true || doc.data()['daDoc'] == true;
      if (!isRead) {
        batch.update(doc.reference, notificationReadUpdate());
      }
    }
    await batch.commit();
  }

  Future<void> _markAsRead(DocumentReference docRef) async {
    try {
      await docRef.update(notificationReadUpdate());
    } catch (_) {}
  }

  Future<void> _acceptRoommateInvitation({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
  }) async {
    final currentUser = ref.read(userProfileProvider).value;
    final currentUserId = ref.read(authStateProvider).value?.uid ?? '';
    final currentUserName = currentUser?.displayName.isNotEmpty == true ? currentUser!.displayName : 'Người dùng';

    final senderId = data['senderId']?.toString() ?? '';
    final senderName = data['senderName']?.toString() ?? 'Người thuê';
    final roomId = data['roomId']?.toString() ?? '';
    final roomCode = data['roomCode']?.toString() ?? 'P001';
    final roomTitle = data['roomTitle']?.toString() ?? 'Phòng trọ HomeShare';

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Tìm hostId của phòng từ kho phòng chuẩn và bài đăng.
      String hostId = data['hostId']?.toString() ?? '';
      if (hostId.isEmpty && roomId.isNotEmpty) {
        try {
          final hostRoomDoc = await FirebaseFirestore.instance.collection('host_rooms').doc(roomId).get();
          if (hostRoomDoc.exists) {
            hostId = hostRoomDoc.data()?['hostId'] ?? hostRoomDoc.data()?['chuNhaId'] ?? '';
          }
        } catch (_) {}
      }
      if (hostId.isEmpty && roomId.isNotEmpty) {
        try {
          final postDoc = await FirebaseFirestore.instance.collection('posts').doc(roomId).get();
          if (postDoc.exists) {
            hostId = postDoc.data()?['hostId'] ?? postDoc.data()?['chuNhaId'] ?? '';
          }
        } catch (_) {}
      }
      if (hostId.isEmpty) {
        try {
          final bookingQuery = await FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: senderId)
              .limit(1)
              .get();
          if (bookingQuery.docs.isNotEmpty) {
            hostId = bookingQuery.docs.first.data()['hostId'] ?? bookingQuery.docs.first.data()['chuNhaId'] ?? '';
          }
        } catch (_) {}
      }
      if (hostId.isEmpty) {
        try {
          final hostQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'host')
              .limit(1)
              .get();
          if (hostQuery.docs.isNotEmpty) {
            hostId = hostQuery.docs.first.id;
          }
        } catch (_) {}
      }

      // 2. Gửi thông báo đến chuông của Chủ nhà để Chủ nhà xác nhận duyệt mới được vào phòng
      if (hostId.isNotEmpty) {
        await ref.read(chatServiceProvider).notifyHostRoommateAccepted(
          hostId: hostId,
          roomId: roomId,
          roomCode: roomCode,
          roomTitle: roomTitle,
          primaryTenantName: senderName,
          primaryTenantId: senderId,
          newRoommateName: currentUserName,
          newRoommateId: currentUserId,
          userNotificationId: doc.id,
        );
      }

      // 3. Cập nhật thông báo thành waiting_host_approval (chờ chủ trọ xác nhận)
      await doc.reference.update({
        'status': 'waiting_host_approval',
        ...notificationReadUpdate(),
        'nguoiNhanId': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        'statusId': FieldValue.delete(),
      });

      // 4. Đồng bộ tức thời sang tin nhắn Chat trong Realtime Database
      await ref.read(chatServiceProvider).syncRoommateInviteFromNotificationToChat(
            senderId: senderId,
            receiverId: currentUserId,
            roomId: roomId,
            newStatus: 'accepted',
            acceptedBy: currentUserId,
            acceptedByName: currentUserName,
            messageId: data['messageId']?.toString() ?? '',
          );

      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn đã đồng ý lời mời ở ghép! Đã gửi yêu cầu đến Chủ trọ. Khi Chủ trọ xác nhận duyệt, bạn sẽ chính thức được vào phòng.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chấp nhận: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _rejectRoommateInvitation({
    required BuildContext context,
    required DocumentSnapshot doc,
  }) async {
    try {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final currentUserId = ref.read(authStateProvider).value?.uid ?? '';
      final senderId = data['senderId']?.toString() ?? '';
      final roomId = data['roomId']?.toString() ?? '';

      await doc.reference.update({
        'status': 'rejected',
        ...notificationReadUpdate(),
        'nguoiNhanId': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        'statusId': FieldValue.delete(),
      });

      // Đồng bộ tức thời sang tin nhắn Chat trong Realtime Database
      await ref.read(chatServiceProvider).syncRoommateInviteFromNotificationToChat(
            senderId: senderId,
            receiverId: currentUserId,
            roomId: roomId,
            newStatus: 'rejected',
            messageId: data['messageId']?.toString() ?? '',
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối lời mời ở ghép.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi từ chối: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _openChatWithSender({
    required BuildContext context,
    required String senderId,
    required String senderName,
  }) {
    final currentUserId = ref.read(authStateProvider).value?.uid ?? '';
    final currentUserName = ref.read(userProfileProvider).value?.displayName ?? 'Tôi';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          receiverId: senderId,
          receiverName: senderName,
        ),
      ),
    );
  }

  Future<void> _openRoomDetailById(BuildContext context, String roomId) async {
    try {
      bool dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ).then((_) => dialogOpen = false);

      final roomService = ref.read(roomServiceProvider);
      RoomModel? room = await roomService.getRoomById(roomId);

      if (dialogOpen && context.mounted) {
        Navigator.pop(context);
      }

      final resolvedRoom = room;
      if (resolvedRoom != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailScreen(room: resolvedRoom)),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy thông tin chi tiết phòng trọ này.'),
            backgroundColor: Color(0xFFD92D20),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở phòng: '),
            backgroundColor: const Color(0xFFD92D20),
          ),
        );
      }
    }
  }

  Future<void> _openPostDetailById(BuildContext context, String postId) async {
    try {
      bool dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ).then((_) => dialogOpen = false);

      final doc = await FirebaseFirestore.instance.collection('roommate_posts').doc(postId).get();
      RoommatePostModel? post;
      if (doc.exists) {
        post = RoommatePostModel.fromFirestore(doc);
      } else {
        final demos = RoommateService.getDemoRoommatePosts();
        final match = demos.where((p) => p.id == postId);
        if (match.isNotEmpty) post = match.first;
      }

      if (dialogOpen && context.mounted) {
        Navigator.pop(context);
      }

      final resolvedPost = post;
      if (resolvedPost != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoommatePostDetailScreen(post: resolvedPost)),
        );
      } else if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()),
        );
      }
    }
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) async {
    _markAsRead(doc.reference);

    final rawType = (data['notificationType'] ?? data['type'] ?? '').toString();
    final type = rawType.toLowerCase().trim();
    final status = (data['status'] ?? '').toString().toLowerCase().trim();
    final title = (data['title'] ?? data['tieuDe'] ?? '').toString().toLowerCase();
    final message = (data['message'] ?? data['body'] ?? data['noiDung'] ?? '').toString().toLowerCase();

    final roomId = (data['roomId'] ?? '').toString();
    final bookingId = (data['bookingId'] ?? '').toString();
    final postId = (data['postId'] ?? '').toString();
    final senderId = (data['senderId'] ?? data['nguoiGuiId'] ?? data['peerId'] ?? '').toString();
    final senderName = (data['senderName'] ?? data['nguoiGuiTen'] ?? data['peerName'] ?? 'Người gửi').toString();

    // 1. Nhận phòng / Ở ghép đã duyệt vào phòng / Đang ở -> MyHomesScreen (Tab 0: Phòng đang thuê)
    if (type == 'roommate_approved' ||
        type == 'checkin' ||
        type == 'check_in' ||
        type == 'nhan_phong' ||
        title.contains('duyệt vào phòng') ||
        title.contains('duyệt bạn cùng phòng') ||
        title.contains('nhận phòng') ||
        title.contains('bàn giao') ||
        message.contains('duyệt vào ở ghép') ||
        message.contains('vào ở ghép cùng')) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyHomesScreen(initialTab: 0)),
        );
      }
      return;
    }

    // 2. Trả phòng / Lịch sử thuê -> MyHomesScreen (Tab 1: Lịch sử đã ở)
    if (type == 'checkout' ||
        type == 'check_out' ||
        type == 'da_tra_phong' ||
        title.contains('trả phòng') ||
        message.contains('trả phòng')) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyHomesScreen(initialTab: 1)),
        );
      }
      return;
    }

    // 3. Lời mời ở ghép -> Xem chi tiết phòng hoặc nhắn tin
    if (type == 'roommate_invitation') {
      if (roomId.isNotEmpty) {
        await _openRoomDetailById(context, roomId);
        return;
      }
      if (senderId.isNotEmpty && context.mounted) {
        _openChatWithSender(
          context: context,
          senderId: senderId,
          senderName: senderName,
        );
        return;
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()),
        );
      }
      return;
    }

    // 4. Đổi lịch dọn vào -> RenterBookingsScreen (Đang xử lý)
    if (type == 'booking_adjustment' ||
        type == 'change_move_in_date' ||
        type == 'booking_date_change' ||
        data['newCheckInDate'] != null ||
        title.contains('đổi lịch') ||
        message.contains('đổi lịch')) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RenterBookingsScreen(initialStatusFilter: 'Đang xử lý'),
          ),
        );
      }
      return;
    }

    // 5. Đơn bị hủy / Hoàn tiền -> RenterBookingsScreen (Đã hủy)
    if (type == 'cancellation_invoice' ||
        type == 'refund' ||
        type == 'cancelled' ||
        status == 'cancelled' ||
        status == 'rejected' ||
        title.contains('hủy') ||
        title.contains('hoàn tiền') ||
        message.contains('đã bị hủy') ||
        message.contains('đã được hủy')) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RenterBookingsScreen(initialStatusFilter: 'Đã hủy'),
          ),
        );
      }
      return;
    }

    // 6. Đơn thuê đã duyệt / Đặt cọc / Thanh toán -> RenterBookingsScreen (Đã duyệt)
    if (type == 'booking_approved' ||
        status == 'approved' ||
        type == 'payment' ||
        type == 'deposit' ||
        type == 'deposit_paid' ||
        type == 'payment_completed' ||
        title.contains('đã được duyệt') ||
        title.contains('đặt cọc') ||
        title.contains('thanh toán')) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RenterBookingsScreen(initialStatusFilter: 'Đã duyệt'),
          ),
        );
      }
      return;
    }

    // 7. Đơn thuê chung -> RenterBookingsScreen
    if (type == 'booking' || bookingId.isNotEmpty) {
      if (context.mounted) {
        final initialFilter = status == 'approved'
            ? 'Đã duyệt'
            : (status == 'pending' ? 'Đang xử lý' : 'Tất cả');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RenterBookingsScreen(initialStatusFilter: initialFilter),
          ),
        );
      }
      return;
    }

    // 8. Bài đăng ở ghép (Post)
    if (type == 'roommate_post' ||
        type == 'post_approved' ||
        type == 'post_rejected' ||
        postId.isNotEmpty ||
        title.contains('bài đăng')) {
      if (postId.isNotEmpty) {
        await _openPostDetailById(context, postId);
        return;
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()),
        );
      }
      return;
    }

    // 9. Tin nhắn trò chuyện
    if (type == 'chat_message' || type == 'chat' || title.contains('tin nhắn')) {
      if (senderId.isNotEmpty && context.mounted) {
        _openChatWithSender(
          context: context,
          senderId: senderId,
          senderName: senderName,
        );
        return;
      }
    }

    // 10. Thông báo có roomId
    if (roomId.isNotEmpty) {
      await _openRoomDetailById(context, roomId);
      return;
    }

    // 11. Từ chối ở ghép -> Nhắn tin với sender hoặc chuyển sang cộng đồng ở ghép
    if (type == 'roommate_rejected' || title.contains('từ chối yêu cầu vào ở ghép')) {
      if (senderId.isNotEmpty && context.mounted) {
        _openChatWithSender(
          context: context,
          senderId: senderId,
          senderName: senderName,
        );
        return;
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()),
        );
      }
      return;
    }
  }

  Future<void> _respondToBookingAdjustment({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required bool accept,
  }) async {
    final bookingId = (data['bookingId'] ?? '').toString();
    final hostNotifId = (data['hostNotificationId'] ?? '').toString();
    final newCheckInDate = data['newCheckInDate'] as Timestamp?;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final batch = FirebaseFirestore.instance.batch();

      // 1. Cập nhật thông báo người thuê
      batch.set(doc.reference, {
        'status': accept ? 'accepted' : 'rejected',
        'statusId': FieldValue.delete(),
        ...notificationReadUpdate(),
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Cập nhật booking gốc
      if (bookingId.isNotEmpty) {
        final bRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
        final bookingUpdates = <String, dynamic>{
          'status': 'daCoc',
          'statusId': FieldValue.delete(),
          'adjustmentStatus': accept ? 'accepted' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (accept) {
          if (newCheckInDate != null) {
            bookingUpdates['moveInDate'] = newCheckInDate;
            bookingUpdates['ngayVao'] = newCheckInDate;
            bookingUpdates['ngayDonVao'] = newCheckInDate;
            bookingUpdates['checkInDate'] = newCheckInDate;
            bookingUpdates['expectedCheckInDate'] = newCheckInDate;
          }
          final newRoomId = (data['newRoomId'] ?? data['roomId'])?.toString();
          if (newRoomId != null && newRoomId.isNotEmpty) {
            bookingUpdates['roomId'] = newRoomId;
            bookingUpdates['phongId'] = newRoomId;
          }
          final newRoomTitle = (data['newRoomTitle'] ?? data['roomTitle'])?.toString();
          if (newRoomTitle != null && newRoomTitle.isNotEmpty) {
            bookingUpdates['roomTitle'] = newRoomTitle;
            bookingUpdates['tieuDePhong'] = newRoomTitle;
          }
        }
        batch.set(bRef, bookingUpdates, SetOptions(merge: true));
      }

      // 3. Cập nhật thông báo của chủ trọ
      if (hostNotifId.isNotEmpty) {
        final hRef = FirebaseFirestore.instance.collection('notifications').doc(hostNotifId);
        final hostUpdates = <String, dynamic>{
          'status': accept ? 'approved' : 'rejected',
          'statusId': FieldValue.delete(),
          'adjustmentStatus': accept ? 'accepted' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (accept && newCheckInDate != null) {
          hostUpdates['checkInDate'] = newCheckInDate;
        }
        batch.set(hRef, hostUpdates, SetOptions(merge: true));
      } else if (bookingId.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('notifications')
              .where('bookingId', isEqualTo: bookingId)
              .where('recipientRole', isEqualTo: 'host')
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final hRef = q.docs.first.reference;
            final hostUpdates = <String, dynamic>{
              'status': accept ? 'approved' : 'rejected',
              'statusId': FieldValue.delete(),
              'adjustmentStatus': accept ? 'accepted' : 'rejected',
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (accept && newCheckInDate != null) {
              hostUpdates['checkInDate'] = newCheckInDate;
            }
            batch.set(hRef, hostUpdates, SetOptions(merge: true));
          }
        } catch (_) {}
      }

      // 4. Gửi thông báo đến chuông của Chủ trọ về phản hồi của khách
      String hostId = (data['hostId'] ?? data['chuNhaId'] ?? '').toString();
      String renterId = (data['senderId'] ?? data['userId'] ?? data['recipientId'] ?? '').toString();
      String renterName = (data['renterName'] ?? data['userName'] ?? 'Khách thuê').toString();
      String roomCode = (data['roomCode'] ?? '').toString();
      String roomId = (data['newRoomId'] ?? data['roomId'] ?? '').toString();
      String roomTitle = (data['newRoomTitle'] ?? data['roomTitle'] ?? '').toString();
      double depositAmount = 0.0;
      final rawAmt = data['amount'] ?? data['depositAmount'] ?? data['tienCoc'];
      if (rawAmt is num) depositAmount = rawAmt.toDouble();
      final oldDateTs = (data['oldCheckInDate'] ?? data['checkInDate']) as Timestamp?;

      if (bookingId.isNotEmpty) {
        try {
          final bDoc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
          if (bDoc.exists && bDoc.data() != null) {
            final bData = bDoc.data()!;
            if (hostId.isEmpty) hostId = (bData['hostId'] ?? bData['chuNhaId'] ?? '').toString();
            if (renterId.isEmpty) renterId = (bData['renterId'] ?? bData['nguoiDungId'] ?? bData['userId'] ?? '').toString();
            if (renterName.isEmpty || renterName == 'Khách thuê') {
              renterName = (bData['renterName'] ?? bData['userName'] ?? bData['tenNguoiO'] ?? 'Khách thuê').toString();
            }
            if (roomCode.isEmpty) roomCode = (bData['roomCode'] ?? bData['maPhong'] ?? '').toString();
            if (roomId.isEmpty) roomId = (bData['roomId'] ?? bData['phongId'] ?? '').toString();
            if (roomTitle.isEmpty) roomTitle = (bData['roomTitle'] ?? bData['tieuDePhong'] ?? '').toString();
            if (depositAmount <= 0) {
              final bAmt = bData['depositAmount'] ?? bData['paymentAmount'] ?? bData['tienCoc'] ?? bData['amount'];
              if (bAmt is num) depositAmount = bAmt.toDouble();
            }
          }
        } catch (_) {}
      }

      if (hostId.isNotEmpty) {
        final hostNotifRef = FirebaseFirestore.instance.collection('notifications').doc();
        final dateStr = newCheckInDate != null
            ? DateFormat('dd/MM/yyyy').format(newCheckInDate.toDate())
            : '';
        if (accept) {
          batch.set(hostNotifRef, {
            'id': hostNotifRef.id,
            'notificationId': hostNotifRef.id,
            'receiverId': hostId,
            'recipientId': hostId,
            'recipientRole': 'host',
            'senderId': renterId,
            'renterId': renterId,
            'renterName': renterName,
            'title': 'Khách đã xác nhận thay đổi thông tin 🎉',
            'message':
                'Khách thuê $renterName đã xác nhận đồng ý ngày nhận phòng mới ${dateStr.isNotEmpty ? "($dateStr)" : ""}. Đơn đặt phòng ${bookingId.isNotEmpty ? bookingId : ""} đã sẵn sàng chờ nhận phòng.',
            'notificationType': 'deposit',
            'type': 'deposit',
            'status': 'approved',
            'bookingId': bookingId,
            if (roomId.isNotEmpty) 'roomId': roomId,
            if (roomCode.isNotEmpty) 'roomCode': roomCode,
            if (roomTitle.isNotEmpty) 'roomTitle': roomTitle,
            'amount': depositAmount,
            'oldCheckInDate': ?oldDateTs,
            'newCheckInDate': ?newCheckInDate,
            if (newCheckInDate != null || oldDateTs != null)
              'checkInDate': (newCheckInDate ?? oldDateTs)!,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(hostNotifRef, {
            'id': hostNotifRef.id,
            'notificationId': hostNotifRef.id,
            'receiverId': hostId,
            'recipientId': hostId,
            'recipientRole': 'host',
            'senderId': renterId,
            'renterId': renterId,
            'renterName': renterName,
            'title': 'Khách thuê từ chối thay đổi ngày dọn vào',
            'message':
                'Khách thuê $renterName đã từ chối yêu cầu đổi lịch dọn vào hoặc đổi phòng. Lịch dọn vào ban đầu vẫn được giữ nguyên.',
            'notificationType': 'deposit',
            'type': 'deposit',
            'status': 'approved',
            'bookingId': bookingId,
            if (roomId.isNotEmpty) 'roomId': roomId,
            if (roomCode.isNotEmpty) 'roomCode': roomCode,
            if (roomTitle.isNotEmpty) 'roomTitle': roomTitle,
            'amount': depositAmount,
            'checkInDate': ?oldDateTs,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Tắt loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: accept ? const Color(0xFF027A48) : const Color(0xFFD92D20),
            content: Text(
              accept
                  ? 'Bạn đã xác nhận thay đổi thông tin thành công!'
                  : 'Bạn đã từ chối yêu cầu đổi lịch dọn vào.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: Text('Có lỗi xảy ra: $e'),
          ),
        );
      }
    }
  }

  /// Hộp thoại xác nhận thay đổi thông tin (Confirm Dialog) khi khách nhấn "Xác nhận thay đổi thông tin"
  Future<void> _showConfirmAdjustmentDialog({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
  }) async {
    final roomCode = (data['roomCode'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['newRoomTitle'] ?? '').toString();
    final oldRoomTitle = (data['oldRoomTitle'] ?? '').toString();
    final reason = (data['adjustmentReason'] ?? '').toString();
    final hostName = (data['hostName'] ?? data['tenChuNha'] ?? 'Chủ trọ').toString();

    final oldDateTs = (data['oldCheckInDate'] ?? data['checkInDate']) as Timestamp?;
    final oldDateStr = oldDateTs != null
        ? DateFormat('dd/MM/yyyy').format(oldDateTs.toDate())
        : '';

    final newDateTs = data['newCheckInDate'] as Timestamp?;
    final newDateStr = newDateTs != null
        ? DateFormat('dd/MM/yyyy').format(newDateTs.toDate())
        : '';

    final isRoomChanged = oldRoomTitle.isNotEmpty &&
        roomTitle.isNotEmpty &&
        oldRoomTitle != roomTitle;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFF175CD3),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Xác nhận thay đổi thông tin',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Chủ trọ $hostName đề xuất điều chỉnh thông tin đơn cọc giữ phòng của bạn:',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475467),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                            children: [
                              const TextSpan(text: 'Phòng: '),
                              if (isRoomChanged) ...[
                                TextSpan(
                                  text: '$oldRoomTitle ',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const TextSpan(text: '➔ '),
                                TextSpan(
                                  text: roomTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                                ),
                              ] else ...[
                                TextSpan(
                                  text: roomCode.isNotEmpty ? 'Phòng $roomCode - $roomTitle' : roomTitle,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF155EEF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                            children: [
                              const TextSpan(text: 'Lịch dọn vào: '),
                              if (oldDateStr.isNotEmpty) ...[
                                TextSpan(
                                  text: '$oldDateStr ',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const TextSpan(text: '➔ '),
                              ],
                              TextSpan(
                                text: newDateStr.isNotEmpty ? newDateStr : 'Ngày mới',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF155EEF),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lý do: $reason',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA6F4C5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF027A48)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sau khi xác nhận, thông tin đơn đặt phòng sẽ được tự động cập nhật.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF027A48),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475467),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Xem lại / Hủy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Xác nhận thay đổi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _respondToBookingAdjustment(
        context: context,
        doc: doc,
        data: data,
        accept: true,
      );
    }
  }

  /// Hộp thoại xác nhận từ chối thay đổi thông tin
  Future<void> _showRejectAdjustmentDialog({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
  }) async {
    final oldDateTs = (data['oldCheckInDate'] ?? data['checkInDate']) as Timestamp?;
    final oldDateStr = oldDateTs != null
        ? DateFormat('dd/MM/yyyy').format(oldDateTs.toDate())
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Từ chối thay đổi thông tin?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
        ),
        content: Text(
          oldDateStr.isNotEmpty
              ? 'Bạn có chắc chắn muốn từ chối yêu cầu đổi lịch dọn vào từ chủ trọ không?\n\nLịch dọn vào ban đầu ($oldDateStr) vẫn sẽ được giữ nguyên.'
              : 'Bạn có chắc chắn muốn từ chối yêu cầu đổi lịch dọn vào từ chủ trọ không?\n\nLịch dọn vào ban đầu vẫn sẽ được giữ nguyên.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475467), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại', style: TextStyle(color: Color(0xFF667085))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Từ chối thay đổi'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _respondToBookingAdjustment(
        context: context,
        doc: doc,
        data: data,
        accept: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(userNotificationsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Thông báo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          notifsAsync.maybeWhen(
            data: (docs) {
              final unreadCount = docs.where((d) => d.data()['isRead'] != true).length;
              if (unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllAsRead(docs),
                child: const Text('Đọc tất cả', style: TextStyle(fontSize: 13, color: AppColors.primary)),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi tải thông báo: $err')),
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_off_outlined, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Các lời mời ở ghép và thông báo phòng sẽ hiển thị tại đây.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _buildNotificationCard(context, doc, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) {
    final type = data['notificationType'] ?? data['type'] ?? '';
    final isRead = data['isRead'] == true || data['daDoc'] == true;
    final title = data['title'] ?? data['tieuDe'] ?? 'Thông báo';
    final rawMsg = data['message'] ?? data['body'] ?? data['noiDung'] ?? '';
    final message = rawMsg.toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final timeStr = createdAt != null ? DateFormat('HH:mm - dd/MM/yyyy').format(createdAt) : '';

    if (type == 'roommate_invitation') {
      return _buildRoommateInviteCard(context, doc, data, isRead, timeStr);
    }

    if (type == 'booking_adjustment' ||
        type == 'change_move_in_date' ||
        type == 'booking_date_change' ||
        data['newCheckInDate'] != null) {
      return _buildBookingAdjustmentCard(context, doc, data, isRead, timeStr);
    }


    final visual = _resolveVisualConfig(
      rawType: type,
      title: title,
      message: message,
      status: (data['status'] ?? '').toString(),
    );


    // Thẻ thông báo phân loại chi tiết theo màu sắc và icon trực quan
    return InkWell(
      onTap: () => _handleNotificationTap(context, doc, data),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isRead ? Colors.white : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isRead ? const Color(0xFFE2E8F0) : visual.iconColor.withValues(alpha: 0.35)),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isRead ? const Color(0x06000000) : visual.iconColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container Icon nổi bật, bo góc mềm, có shadow nhẹ theo màu icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: visual.iconColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: visual.iconColor.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(visual.icon, color: visual.iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng chip loại thông báo + chấm / tag chưa đọc
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: visual.badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: visual.badgeColor.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          visual.categoryBadge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: visual.badgeColor,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Mới',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotificationVisualConfig _resolveVisualConfig({
    required String rawType,
    required String title,
    required String message,
    required String status,
  }) {
    final t = rawType.toLowerCase().trim();
    final s = status.toLowerCase().trim();
    final titleLower = title.toLowerCase();
    final msgLower = message.toLowerCase();

    // 1. Nhận phòng / Bàn giao chìa khóa
    if (t == 'checkin' ||
        t == 'check_in' ||
        t == 'nhan_phong' ||
        titleLower.contains('nhận phòng') ||
        titleLower.contains('bàn giao') ||
        msgLower.contains('nhận phòng') ||
        msgLower.contains('bàn giao phòng')) {
      return const _NotificationVisualConfig(
        icon: Icons.vpn_key_rounded,
        iconColor: Color(0xFF0D9488), // Teal
        backgroundColor: Color(0xFFCCFBF1),
        categoryBadge: 'Nhận phòng',
        badgeBg: Color(0xFFE6FFFA),
        badgeColor: Color(0xFF0F766E),
      );
    }

    // 2. Hủy đơn / Từ chối / Hoàn tiền
    if (t == 'cancellation_invoice' ||
        t == 'refund' ||
        t == 'cancelled' ||
        t == 'rejected' ||
        t == 'cancel' ||
        s == 'cancelled' ||
        s == 'rejected' ||
        titleLower.contains('hủy') ||
        titleLower.contains('từ chối') ||
        titleLower.contains('hoàn tiền') ||
        msgLower.contains('đã bị hủy') ||
        msgLower.contains('đã được hủy')) {
      return const _NotificationVisualConfig(
        icon: Icons.cancel_outlined,
        iconColor: Color(0xFFE11D48), // Rose red
        backgroundColor: Color(0xFFFFE4E6),
        categoryBadge: 'Đã hủy',
        badgeBg: Color(0xFFFFF1F2),
        badgeColor: Color(0xFFBE123C),
      );
    }

    // 3. Ở ghép được duyệt vào phòng
    if (t == 'roommate_approved' ||
        titleLower.contains('duyệt vào phòng') ||
        titleLower.contains('duyệt bạn cùng phòng') ||
        msgLower.contains('vào ở ghép cùng')) {
      return const _NotificationVisualConfig(
        icon: Icons.how_to_reg_rounded,
        iconColor: Color(0xFF7C3AED), // Purple
        backgroundColor: Color(0xFFF3E8FF),
        categoryBadge: 'Ở ghép',
        badgeBg: Color(0xFFFAF5FF),
        badgeColor: Color(0xFF6D28D9),
      );
    }

    // 4. Ở ghép bị từ chối
    if (t == 'roommate_rejected' ||
        titleLower.contains('từ chối yêu cầu vào ở ghép') ||
        titleLower.contains('yêu cầu ở ghép đã bị từ chối')) {
      return const _NotificationVisualConfig(
        icon: Icons.person_off_rounded,
        iconColor: Color(0xFFDC2626), // Red
        backgroundColor: Color(0xFFFEE2E2),
        categoryBadge: 'Ở ghép',
        badgeBg: Color(0xFFFEF2F2),
        badgeColor: Color(0xFFB91C1C),
      );
    }

    // 5. Thanh toán / Đặt cọc thành công
    if (t == 'payment' ||
        t == 'deposit' ||
        t == 'deposit_paid' ||
        t == 'payment_completed' ||
        titleLower.contains('thanh toán') ||
        titleLower.contains('tiền cọc') ||
        titleLower.contains('chuyển khoản')) {
      return const _NotificationVisualConfig(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: Color(0xFF2563EB), // Blue
        backgroundColor: Color(0xFFDBEAFE),
        categoryBadge: 'Thanh toán',
        badgeBg: Color(0xFFEFF6FF),
        badgeColor: Color(0xFF1D4ED8),
      );
    }

    // 6. Đơn thuê phòng đã được duyệt
    if (t == 'booking_approved' ||
        (t == 'booking' && (titleLower.contains('duyệt') || s == 'approved')) ||
        titleLower.contains('đã được duyệt')) {
      return const _NotificationVisualConfig(
        icon: Icons.task_alt_rounded,
        iconColor: Color(0xFF16A34A), // Green
        backgroundColor: Color(0xFFDCFCE7),
        categoryBadge: 'Đã duyệt',
        badgeBg: Color(0xFFF0FDF4),
        badgeColor: Color(0xFF15803D),
      );
    }

    // 7. Đổi lịch dọn vào / Thay đổi lịch hẹn
    if (t == 'booking_adjustment' ||
        t == 'change_move_in_date' ||
        t == 'booking_date_change' ||
        titleLower.contains('đổi lịch') ||
        msgLower.contains('đổi lịch')) {
      return const _NotificationVisualConfig(
        icon: Icons.edit_calendar_rounded,
        iconColor: Color(0xFFD97706), // Amber
        backgroundColor: Color(0xFFFEF3C7),
        categoryBadge: 'Đổi lịch',
        badgeBg: Color(0xFFFFFBEB),
        badgeColor: Color(0xFFB45309),
      );
    }

    // 8. Tin nhắn mới
    if (t == 'chat_message' || t == 'chat' || titleLower.contains('tin nhắn')) {
      return const _NotificationVisualConfig(
        icon: Icons.chat_bubble_rounded,
        iconColor: Color(0xFF0284C7), // Sky blue
        backgroundColor: Color(0xFFE0F2FE),
        categoryBadge: 'Tin nhắn',
        badgeBg: Color(0xFFF0F9FF),
        badgeColor: Color(0xFF0369A1),
      );
    }

    // 9. Cảnh báo vi phạm / Trừ điểm uy tín
    if (t == 'warning' ||
        t == 'penalty' ||
        titleLower.contains('cảnh báo') ||
        titleLower.contains('vi phạm') ||
        titleLower.contains('trừ điểm')) {
      return const _NotificationVisualConfig(
        icon: Icons.warning_amber_rounded,
        iconColor: Color(0xFFDC2626), // Danger
        backgroundColor: Color(0xFFFEE2E2),
        categoryBadge: 'Cảnh báo',
        badgeBg: Color(0xFFFEF2F2),
        badgeColor: Color(0xFFB91C1C),
      );
    }

    // 10. Điểm uy tín được cộng thêm
    if (t == 'bonus' ||
        titleLower.contains('cộng thêm') ||
        titleLower.contains('điểm uy tín')) {
      return const _NotificationVisualConfig(
        icon: Icons.military_tech_rounded,
        iconColor: Color(0xFFCA8A04), // Gold
        backgroundColor: Color(0xFFFEF9C3),
        categoryBadge: '+ Uy tín',
        badgeBg: Color(0xFFFEFCE8),
        badgeColor: Color(0xFFA16207),
      );
    }

    // 11. Báo cáo sự cố phòng
    if (t == 'issue' || t == 'maintenance' || titleLower.contains('sự cố')) {
      return const _NotificationVisualConfig(
        icon: Icons.handyman_rounded,
        iconColor: Color(0xFFC2410C), // Deep orange
        backgroundColor: Color(0xFFFFEDD5),
        categoryBadge: 'Sự cố',
        badgeBg: Color(0xFFFFF7ED),
        badgeColor: Color(0xFF9A3412),
      );
    }

    // 12. Quản trị viên / Ban Quản Trị / Hệ thống
    if (t == 'system_admin' ||
        t == 'admin' ||
        t == 'system' ||
        titleLower.contains('admin') ||
        titleLower.contains('ban quản trị')) {
      return const _NotificationVisualConfig(
        icon: Icons.admin_panel_settings_rounded,
        iconColor: Color(0xFF4F46E5), // Indigo
        backgroundColor: Color(0xFFEEF2FF),
        categoryBadge: 'Hệ thống',
        badgeBg: Color(0xFFF5F3FF),
        badgeColor: Color(0xFF4338CA),
      );
    }

    // 13. Đang chờ xử lý
    if (t == 'pendingaction' || t == 'pending' || titleLower.contains('chờ')) {
      return const _NotificationVisualConfig(
        icon: Icons.hourglass_top_rounded,
        iconColor: Color(0xFFD97706), // Amber
        backgroundColor: Color(0xFFFEF3C7),
        categoryBadge: 'Chờ xử lý',
        badgeBg: Color(0xFFFFFBEB),
        badgeColor: Color(0xFFB45309),
      );
    }

    // 14. Đặt phòng chung
    if (t == 'booking') {
      return const _NotificationVisualConfig(
        icon: Icons.home_work_rounded,
        iconColor: Color(0xFF2563EB),
        backgroundColor: Color(0xFFDBEAFE),
        categoryBadge: 'Đặt phòng',
        badgeBg: Color(0xFFEFF6FF),
        badgeColor: Color(0xFF1D4ED8),
      );
    }

    // 15. Mặc định
    return const _NotificationVisualConfig(
      icon: Icons.notifications_active_rounded,
      iconColor: AppColors.primary,
      backgroundColor: Color(0xFFE0F2FE),
      categoryBadge: 'Thông báo',
      badgeBg: Color(0xFFF0F9FF),
      badgeColor: AppColors.primary,
    );
  }

  Widget _buildRoommateInviteCard(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isRead,
    String timeStr,
  ) {
    final status = data['status']?.toString() ?? 'pending';
    final senderName = data['senderName']?.toString() ?? 'Một bạn thuê';
    final senderId = data['senderId']?.toString() ?? '';
    final roomTitle = data['roomTitle']?.toString() ?? 'Phòng trọ HomeShare';
    final roomCode = data['roomCode']?.toString() ?? 'P001';
    final price = data['pricePerPerson'] ?? 1800000;
    final priceFormatted = NumberFormat('#,###', 'vi_VN').format(price);

    return InkWell(
      onTap: () => _handleNotificationTap(context, doc, data),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'accepted'
              ? AppColors.primary
              : (status == 'rejected' ? (const Color(0xFFE2E8F0)) : const Color(0xFFF97316)),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handshake_rounded, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LỜI MỜI VÀO Ở GHÉP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Mới',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.4),
              children: [
                TextSpan(
                  text: senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const TextSpan(text: ' đã gửi lời mời bạn cùng ở ghép tại:'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 18, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$roomTitle (Mã: $roomCode)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chi phí dự kiến: $priceFormatted đ/tháng/người',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          if ((data['note']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (data['note']?.toString() ?? '').trim(),
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (status == 'accepted')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA6F4C5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chủ trọ đã duyệt • Đã vào phòng thành công',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                    ),
                  ),
                  if (senderId.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openChatWithSender(
                        context: context,
                        senderId: senderId,
                        senderName: senderName,
                      ),
                      child: const Text('Nhắn tin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            )
          else if (status == 'waiting_host_approval' || status == 'accepted_waiting_host')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF0C7).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEDF89)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB54708), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Đã đồng ý • Đang chờ chủ trọ xác nhận duyệt vào phòng',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB54708)),
                    ),
                  ),
                  if (senderId.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openChatWithSender(
                        context: context,
                        senderId: senderId,
                        senderName: senderName,
                      ),
                      child: const Text('Nhắn tin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB54708))),
                    ),
                ],
              ),
            )
          else if (status == 'rejected' || status == 'host_rejected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    status == 'host_rejected' ? 'Chủ trọ đã từ chối yêu cầu ở ghép' : 'Đã từ chối lời mời ở ghép',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else if (status == 'revoked')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.remove_circle_outline, color: Color(0xFF64748B), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Người gửi đã thu hồi lời mời ở ghép',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _rejectRoommateInvitation(context: context, doc: doc),
                    child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _acceptRoommateInvitation(context: context, doc: doc, data: data),
                    child: const Text('Chấp nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                if (senderId.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chat_outlined, color: AppColors.primary),
                    tooltip: 'Nhắn tin với người gửi',
                    onPressed: () => _openChatWithSender(
                      context: context,
                      senderId: senderId,
                      senderName: senderName,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildBookingAdjustmentCard(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isRead,
    String timeStr,
  ) {
    final status = (data['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted' || status == 'approved';
    final isRejected = status == 'rejected';

    final title = (data['title'] ?? 'Chủ trọ yêu cầu đổi lịch dọn vào').toString();
    final message = (data['message'] ?? '').toString();
    final roomCode = (data['roomCode'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['newRoomTitle'] ?? '').toString();
    final oldRoomTitle = (data['oldRoomTitle'] ?? '').toString();
    final reason = (data['adjustmentReason'] ?? '').toString();

    final oldDateTs = (data['oldCheckInDate'] ?? data['checkInDate']) as Timestamp?;
    final oldDateStr = oldDateTs != null
        ? DateFormat('dd/MM/yyyy').format(oldDateTs.toDate())
        : '';

    final newDateTs = data['newCheckInDate'] as Timestamp?;
    final newDateStr = newDateTs != null
        ? DateFormat('dd/MM/yyyy').format(newDateTs.toDate())
        : '';

    final isRoomChanged = oldRoomTitle.isNotEmpty &&
        roomTitle.isNotEmpty &&
        oldRoomTitle != roomTitle;

    return InkWell(
      onTap: () {
        if (isPending) {
          _showConfirmAdjustmentDialog(context: context, doc: doc, data: data);
        } else {
          _handleNotificationTap(context, doc, data);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isRead ? Colors.white : const Color(0xFFF0FDF4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? const Color(0xFFFDB022)
                : (isRead
                    ? (const Color(0xFFE2E8F0))
                    : AppColors.primary.withValues(alpha: 0.3)),
            width: isPending ? 1.5 : (isRead ? 1 : 1.5),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF0C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.edit_calendar_rounded,
                    color: Color(0xFFB54708),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF0C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFEDF89)),
                              ),
                              child: const Text(
                                'Chờ xác nhận',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB54708),
                                ),
                              ),
                            )
                          else if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Khối chi tiết lịch dọn vào mới
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roomCode.isNotEmpty || roomTitle.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                              children: [
                                const TextSpan(text: 'Phòng: '),
                                if (isRoomChanged) ...[
                                  TextSpan(
                                    text: '$oldRoomTitle ',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const TextSpan(text: '➔ '),
                                  TextSpan(
                                    text: roomTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                                  ),
                                ] else ...[
                                  TextSpan(
                                    text: roomCode.isNotEmpty ? 'Phòng $roomCode • $roomTitle' : roomTitle,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (newDateStr.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: Color(0xFF1E60F2),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Lịch dọn vào mới: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (oldDateStr.isNotEmpty) ...[
                          Text(
                            '$oldDateStr ',
                            style: const TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const Text('➔ ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                        Text(
                          newDateStr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E60F2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (reason.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Lý do: $reason',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (message.isNotEmpty) ...[
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Nút Xác nhận thay đổi thông tin / Từ chối hoặc Trạng thái đã xử lý
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => _showRejectAdjustmentDialog(
                        context: context,
                        doc: doc,
                        data: data,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD92D20),
                        side: const BorderSide(color: Color(0xFFFDA29B)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Từ chối',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showConfirmAdjustmentDialog(
                        context: context,
                        doc: doc,
                        data: data,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text(
                        'Xác nhận thay đổi thông tin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isAccepted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA6F4C5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF027A48),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Bạn đã xác nhận thay đổi thông tin thành công',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF027A48),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isRejected) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECDCA)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel_rounded,
                      size: 14,
                      color: Color(0xFFD92D20),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Bạn đã từ chối đổi lịch dọn vào',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD92D20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
