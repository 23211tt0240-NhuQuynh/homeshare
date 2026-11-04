import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/chat_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';

/// Provider stream danh sách thông báo của User (Renter)
final userNotificationsStreamProvider =
    StreamProvider.autoDispose<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final currentUserId = ref.watch(authStateProvider).value?.uid ?? '';
  if (currentUserId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where(
        Filter.or(
          Filter('receiverId', isEqualTo: currentUserId),
          Filter('recipientId', isEqualTo: currentUserId),
          Filter('userId', isEqualTo: currentUserId),
          Filter('nguoiNhanId', isEqualTo: currentUserId),
        ),
      )
      .snapshots()
      .map((snapshot) {
    // Chỉ lấy thông báo của user (người thuê / ở ghép), loại trừ thông báo của chủ trọ và cảnh báo vi phạm
    final docs = snapshot.docs.where((doc) {
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
    return docs;
  });
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
        batch.update(doc.reference, {'isRead': true, 'daDoc': true});
      }
    }
    await batch.commit();
  }

  Future<void> _markAsRead(DocumentReference docRef) async {
    try {
      await docRef.update({'isRead': true, 'daDoc': true});
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

      // 1. Tìm hostId của phòng (với các tầng fallback bảo đảm 100% tìm thấy)
      String hostId = data['hostId']?.toString() ?? '';
      if (hostId.isEmpty && roomId.isNotEmpty) {
        try {
          final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
          if (roomDoc.exists) {
            hostId = roomDoc.data()?['hostId'] ?? roomDoc.data()?['chuNhaId'] ?? '';
          }
        } catch (_) {}
      }
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
        'isRead': true,
        'daDoc': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
      await doc.reference.update({
        'status': 'rejected',
        'isRead': true,
        'daDoc': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
        'isRead': true,
        'daDoc': true,
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Cập nhật booking gốc
      if (bookingId.isNotEmpty) {
        final bRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
        final bookingUpdates = <String, dynamic>{
          'status': 'daCoc',
          'statusId': 'deposited',
          'adjustmentStatus': accept ? 'accepted' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (accept) {
          if (newCheckInDate != null) {
            bookingUpdates['checkInDate'] = newCheckInDate;
          }
          final newRoomId = data['roomId']?.toString();
          if (newRoomId != null && newRoomId.isNotEmpty) {
            bookingUpdates['roomId'] = newRoomId;
          }
          final newRoomTitle = data['roomTitle']?.toString();
          if (newRoomTitle != null && newRoomTitle.isNotEmpty) {
            bookingUpdates['roomTitle'] = newRoomTitle;
          }
        }
        batch.set(bRef, bookingUpdates, SetOptions(merge: true));
      }

      // 3. Cập nhật thông báo của chủ trọ
      if (hostNotifId.isNotEmpty) {
        final hRef = FirebaseFirestore.instance.collection('notifications').doc(hostNotifId);
        final hostUpdates = <String, dynamic>{
          'status': accept ? 'approved' : 'rejected',
          'statusId': accept ? 'deposited' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (accept && newCheckInDate != null) {
          hostUpdates['checkInDate'] = newCheckInDate;
        }
        batch.set(hRef, hostUpdates, SetOptions(merge: true));
      }

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Tắt loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: accept ? const Color(0xFF027A48) : const Color(0xFFD92D20),
            content: Text(
              accept
                  ? 'Bạn đã đồng ý đổi lịch dọn vào thành công!'
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

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(userNotificationsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          notifsAsync.maybeWhen(
            data: (docs) {
              final unreadCount = docs.where((d) => d.data()['isRead'] != true).length;
              if (unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllAsRead(docs),
                child: Text('Đọc tất cả', style: TextStyle(fontSize: 13, color: AppColors.primary)),
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
                    child: Icon(Icons.notifications_off_outlined, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Các lời mời ở ghép và thông báo phòng sẽ hiển thị tại đây.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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


    IconData iconData = Icons.notifications_rounded;
    Color iconColor = AppColors.primary;
    Color iconBg = AppColors.primary.withValues(alpha: 0.12);

    if (type == 'booking' || type == 'booking_approved') {
      iconData = Icons.task_alt_rounded;
      iconColor = const Color(0xFF16A34A);
      iconBg = const Color(0xFFDCFCE7);
    } else if (type == 'cancellation_invoice' || type == 'refund') {
      iconData = Icons.receipt_long_rounded;
      iconColor = const Color(0xFF2563EB);
      iconBg = AppColors.border;
    } else if (type == 'pendingAction') {
      iconData = Icons.hourglass_top_rounded;
      iconColor = const Color(0xFFD97706);
      iconBg = AppColors.warningContainer;
    }

    // Thẻ thông báo thông thường (đặt phòng, thanh toán, hệ thống...)
    return InkWell(
      onTap: () => _markAsRead(doc.reference),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppColors.surface : AppColors.successContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconBg,
              child: Icon(iconData, color: iconColor, size: 20),
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
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(timeStr, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'accepted'
              ? AppColors.primary
              : (status == 'rejected' ? AppColors.border : const Color(0xFFF97316)),
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
                      Text(timeStr, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.dangerContainer,
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const TextSpan(text: ' đã gửi lời mời bạn cùng ở ghép tại:'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.meeting_room_outlined, size: 18, color: AppColors.textMuted),
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
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          if ((data['note']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (data['note']?.toString() ?? '').trim(),
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted),
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
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    status == 'host_rejected' ? 'Chủ trọ đã từ chối yêu cầu ở ghép' : 'Đã từ chối lời mời ở ghép',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
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
                    icon: Icon(Icons.chat_outlined, color: AppColors.primary),
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
    final roomTitle = (data['roomTitle'] ?? '').toString();
    final reason = (data['adjustmentReason'] ?? '').toString();

    final newDateTs = data['newCheckInDate'] as Timestamp?;
    final newDateStr = newDateTs != null
        ? DateFormat('dd/MM/yyyy').format(newDateTs.toDate())
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? AppColors.surface : AppColors.successContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFDB022)
              : (isRead
                  ? AppColors.border
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
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
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
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (roomCode.isNotEmpty || roomTitle.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          roomCode.isNotEmpty
                              ? 'Phòng $roomCode • $roomTitle'
                              : roomTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      Text(
                        'Ngày dọn vào đề xuất: ',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
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
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Lý do: $reason',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (message.isNotEmpty) ...[
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nút Đồng ý / Từ chối hoặc Trạng thái đã xử lý
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToBookingAdjustment(
                      context: context,
                      doc: doc,
                      data: data,
                      accept: false,
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
                  child: ElevatedButton(
                    onPressed: () => _respondToBookingAdjustment(
                      context: context,
                      doc: doc,
                      data: data,
                      accept: true,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Đồng ý',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
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
                    'Bạn đã đồng ý đổi lịch dọn vào',
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
    );
  }
}
