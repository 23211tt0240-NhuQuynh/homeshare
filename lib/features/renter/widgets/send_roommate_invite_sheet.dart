import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/chat_service.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/chat_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../chat/services/roommate_invitation_eligibility_service.dart';
import '../screens/create_roommate_post_screen.dart';
import 'room_full_dialog.dart';

/// BottomSheet chọn người dùng để gửi tin nhắn / lời mời ở ghép cho phòng đang thuê
class SendRoommateInviteSheet extends ConsumerStatefulWidget {
  final BookingRequestModel booking;

  const SendRoommateInviteSheet({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, {required BookingRequestModel booking}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendRoommateInviteSheet(booking: booking),
    );
  }

  @override
  ConsumerState<SendRoommateInviteSheet> createState() =>
      _SendRoommateInviteSheetState();
}

class _SendRoommateInviteSheetState
    extends ConsumerState<SendRoommateInviteSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final NumberFormat _currencyFormatter = NumberFormat('#,###', 'vi_VN');
  RoomCapacityCheckResult? _capacityResult;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadCapacity();
  }

  Future<void> _loadCapacity() async {
    try {
      final auth = ref.read(authStateProvider);
      final uid = auth.value?.uid ?? '';
      final service = RoommateInvitationEligibilityService();
      final res = await service.checkRoomCapacity(
        widget.booking.roomId,
        senderId: uid,
      );
      if (mounted) {
        setState(() {
          _capacityResult = res;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final currentUserId = currentUser?.uid ?? '';
    final currentUserName = userProfile?.displayName.isNotEmpty == true
        ? userProfile!.displayName
        : (currentUser?.displayName ?? 'Người thuê');
    final currentUserAvatar = userProfile?.avatarUrl ?? '';

    final b = widget.booking;
    final sharePrice = b.roomPrice > 0 ? (b.roomPrice / 2).round() : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle Bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF155EEF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.group_add_rounded,
                    color: Color(0xFF155EEF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gửi tin ở ghép',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chọn bạn cùng phòng để gửi tin nhắn & lời mời vào ở ghép:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card thông tin phòng được chọn
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Đang ở',
                          style: TextStyle(
                            color: Color(0xFF027A48),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (_capacityResult != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _capacityResult!.isFull
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _capacityResult!.isFull
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFA6F4C5),
                            ),
                          ),
                          child: Text(
                            _capacityResult!.isFull
                                ? 'Đã đủ (${_capacityResult!.currentOccupants}/${_capacityResult!.capacity})'
                                : 'Còn chỗ (${_capacityResult!.currentOccupants}/${_capacityResult!.capacity})',
                            style: TextStyle(
                              color: _capacityResult!.isFull
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF027A48),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        sharePrice > 0
                            ? '~${_currencyFormatter.format(sharePrice)} đ/người'
                            : '${_currencyFormatter.format(b.roomPrice)} đ/tháng',
                        style: const TextStyle(
                          color: Color(0xFF155EEF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  if (b.roomAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      b.roomAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Nút mở Đăng bài lên cộng đồng
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateRoommatePostScreen(
                            initialBooking: b,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.post_add_rounded,
                            size: 15,
                            color: isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF155EEF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hoặc đăng tin tìm ở ghép công khai lên cộng đồng',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF155EEF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF155EEF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ô tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên bạn cùng phòng hoặc SĐT...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Danh sách người dùng
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi tải danh sách: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final eligibleUsers = docs.where((doc) {
                  final data = doc.data();
                  final uid = doc.id;
                  if (uid == currentUserId) return false;

                  final role = (data['role'] ?? data['vaiTro'] ?? 'renter')
                      .toString()
                      .toLowerCase();
                  // Chỉ lấy người dùng/người tìm phòng, loại bỏ chủ trọ & admin
                  if (role == 'host' || role == 'admin' || role == 'chutro') {
                    return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    final name = (data['displayName'] ??
                            data['hoTen'] ??
                            data['name'] ??
                            '')
                        .toString()
                        .toLowerCase();
                    final phone = (data['phoneNumber'] ??
                            data['soDienThoai'] ??
                            data['phone'] ??
                            '')
                        .toString()
                        .toLowerCase();
                    if (!name.contains(_searchQuery) &&
                        !phone.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (eligibleUsers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Không tìm thấy bạn cùng phòng phù hợp với từ khóa.'
                                : 'Chưa có người dùng nào khác trong hệ thống.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: eligibleUsers.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = eligibleUsers[index];
                    final data = doc.data();
                    final targetUid = doc.id;
                    final targetName = (data['displayName'] ??
                            data['hoTen'] ??
                            data['name'] ??
                            'Người tìm phòng')
                        .toString();
                    final targetAvatar = (data['photoURL'] ??
                            data['avatar'] ??
                            data['avatarUrl'] ??
                            '')
                        .toString();
                    final targetPhone = (data['phoneNumber'] ??
                            data['soDienThoai'] ??
                            data['phone'] ??
                            '')
                        .toString();
                    final targetGender = (data['gender'] ??
                            data['gioiTinh'] ??
                            '')
                        .toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          backgroundImage: targetAvatar.isNotEmpty
                              ? NetworkImage(targetAvatar)
                              : null,
                          child: targetAvatar.isEmpty
                              ? Text(
                                  targetName.isNotEmpty
                                      ? targetName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                targetName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (targetGender.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  targetGender,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            targetPhone.isNotEmpty
                                ? 'SĐT: $targetPhone • Tìm phòng / ở ghép'
                                : 'Người dùng tìm phòng tại HomeShare',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _confirmAndSendInvite(
                            targetUid: targetUid,
                            targetName: targetName,
                            targetAvatar: targetAvatar,
                            targetPhone: targetPhone,
                            currentUserId: currentUserId,
                            currentUserName: currentUserName,
                            currentUserAvatar: currentUserAvatar,
                          ),
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text(
                            'Gửi tin',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF155EEF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _confirmAndSendInvite({
    required String targetUid,
    required String targetName,
    required String targetAvatar,
    required String targetPhone,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
  }) async {
    final b = widget.booking;

    // Kiểm tra sức chứa phòng: nếu đã đủ người thì tuyệt đối không được gửi
    final service = RoommateInvitationEligibilityService();
    final capResult = await service.checkRoomCapacity(
      b.roomId,
      senderId: currentUserId,
    );
    if (capResult.isFull) {
      if (!mounted) return;
      await RoomFullDialog.show(
        context,
        capacity: capResult.capacity,
        currentOccupants: capResult.currentOccupants,
        roomTitle: b.roomTitle,
      );
      return; // Dừng ngay lập tức! Tuyệt đối không gửi tin nhắn và không ghi nhận vào chuông thông báo
    }

    final sharePrice = b.roomPrice > 0 ? (b.roomPrice / 2).round() : 0;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: Color(0xFF155EEF)),
            SizedBox(width: 8),
            Text(
              'Gửi tin mời ở ghép',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có muốn gửi lời mời ở ghép tới $targetName?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phòng: ${b.roomTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sharePrice > 0
                        ? 'Chi phí dự kiến: ${_currencyFormatter.format(sharePrice)} đ/tháng/người'
                        : 'Giá phòng: ${_currencyFormatter.format(b.roomPrice)} đ/tháng',
                    style: const TextStyle(
                      color: Color(0xFF155EEF),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tin nhắn và thông tin phòng sẽ được gửi qua cuộc trò chuyện, kèm thông báo chuông tới bạn này.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi Ngay'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final chatService = ref.read(chatServiceProvider);
      final roomCode = b.roomCode.isNotEmpty ? b.roomCode : b.roomId;

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final message = ChatMessageModel(
        id: messageId,
        senderId: currentUserId,
        senderName: currentUserName,
        receiverId: targetUid,
        text: 'Lời mời cùng ở ghép phòng tại HomeShare',
        messageType: 'roommate_invitation',
        attachmentUrl: '',
        extraData: {
          'status': 'pending',
          'roomId': b.roomId,
          'roomCode': roomCode,
          'roomTitle': b.roomTitle,
          'hostId': b.hostId,
          'pricePerPerson': sharePrice,
          'senderName': currentUserName,
          'senderId': currentUserId,
          'receiverName': targetName,
          'receiverId': targetUid,
          'roomAddress': b.roomAddress,
        },
        timestamp: DateTime.now(),
        status: 'sent',
      );

      // 1. Gửi tin nhắn rich card roommate_invitation
      await chatService.sendMessage(
        message,
        receiverName: targetName,
        receiverAvatar: targetAvatar,
        receiverPhone: targetPhone,
      );

      // 2. Gửi thông báo chuông tới người nhận
      final notifId = await chatService.notifyUserRoommateInvitation(
        receiverId: targetUid,
        senderId: currentUserId,
        senderName: currentUserName,
        roomId: b.roomId,
        roomCode: roomCode,
        roomTitle: b.roomTitle,
        pricePerPerson: sharePrice.toDouble(),
        hostId: b.hostId,
        messageId: messageId,
      );

      if (notifId.isNotEmpty) {
        await chatService.updateMessageExtraData(
          senderId: currentUserId,
          receiverId: targetUid,
          messageId: messageId,
          extraData: {'notificationId': notifId},
        );
      }

      if (!mounted) return;

      Navigator.pop(context); // Đóng BottomSheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã gửi lời mời ở ghép tới $targetName!'),
          backgroundColor: AppColors.success,
        ),
      );

      // 3. Mở cuộc trò chuyện trực tiếp với người nhận
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            receiverId: targetUid,
            receiverName: targetName,
            receiverAvatar: targetAvatar,
            receiverPhone: targetPhone,
            isLandlord: false, // Cuộc trò chuyện giữa 2 người thuê
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi lời mời: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
