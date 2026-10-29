import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/room_service.dart';
import '../../../core/utils/host_post_report_policy.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../widgets/report_host_post_dialog.dart';
import 'room_booking_detail_screen.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final RoomModel room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  int _currentImageIndex = 0;
  late RoomModel _room;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  void _onQuickBookingPressed() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt phòng')),
      );
      return;
    }

    if (_room.isHiddenOrRejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài đăng này hiện đang bị ẩn hoặc từ chối duyệt, không thể đặt phòng.'),
          backgroundColor: Color(0xFFD92D20),
        ),
      );
      return;
    }

    if (_room.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài đăng này đang chờ admin phê duyệt, tạm thời chưa mở đặt phòng.'),
          backgroundColor: Color(0xFFB54708),
        ),
      );
      return;
    }

    if (user.uid == _room.hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng do chính bạn quản lý')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomBookingDetailScreen(room: _room),
      ),
    );
  }

  Future<void> _onReportPressed() async {
    final reporterId = ref.read(currentUserProvider)?.uid ?? '';
    if (reporterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để báo cáo.')),
      );
      return;
    }
    if (!HostPostReportPolicy.canReport(
      reporterId: reporterId,
      hostId: _room.hostId,
      postId: _room.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không thể báo cáo bài đăng của chính mình.')),
      );
      return;
    }
    await showReportHostPostDialog(
      context,
      postId: _room.id,
      postTitle: _room.title,
      hostId: _room.hostId,
      hostName: _room.hostName,
      roomId: _room.id,
    );
  }

  void _onChatPressed() {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin với chủ trọ')),
      );
      return;
    }

    if (currentUser.uid == _room.hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng do chính bạn quản lý')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: _room.hostId,
          receiverName: _room.hostName,
          receiverAvatar: _room.hostAvatar,
          receiverPhone: _room.hostPhone,
          isLandlord: true,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedRoom: _room,
        ),
      ),
    );
  }

  void _openHostProfile() {
    final hostId = _room.hostId.trim();
    if (hostId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostProfileScreen(userId: hostId),
      ),
    );
  }

  void _onCallHostPressed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Số điện thoại chủ nhà'),
        content: Text(
          'Liên hệ trực tiếp với chủ trọ ${_room.hostName}:\n\n'
          '📞 ${_room.hostPhone}',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(roomPostDetailProvider(widget.room.id));
    if (postAsync.hasError) {
      return _buildLoadError();
    }
    final livePost = postAsync.value;
    if (postAsync.hasValue && livePost == null) {
      return _buildMissingPost();
    }
    if (livePost != null) {
      _room = livePost;
    }

    final currencyFormatter = NumberFormat('#,###', 'vi_VN');
    final priceStr = '${currencyFormatter.format(_room.price)} đ/tháng';
    final depositStr = '${currencyFormatter.format(_room.deposit)} đ';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
          // 1. App Bar với Image Slider
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Semantics(
                label: 'Quay lại',
                button: true,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final isFav = ref.watch(favoritesProvider).favoriteRoomIds.contains(_room.id);
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Semantics(
                      label: isFav ? 'Bỏ lưu khỏi danh sách yêu thích' : 'Lưu vào danh sách yêu thích',
                      toggled: isFav,
                      button: true,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? Color(0xFFEF4444) : AppColors.textDark,
                            size: 20,
                          ),
                          tooltip: isFav ? 'Bỏ lưu yêu thích' : 'Lưu yêu thích',
                          onPressed: () async {
                            final added = await ref.read(favoritesProvider.notifier).toggleFavoriteRoom(_room);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(added
                                      ? 'Đã thêm phòng vào danh sách yêu thích ❤️'
                                      : 'Đã bỏ lưu phòng khỏi danh sách yêu thích'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: added ? AppColors.primary : Color(0xFF334155),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _room.images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: _room.images.length,
                          onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                          itemBuilder: (context, index) {
                            return Semantics(
                              image: true,
                              label: 'Ảnh phòng trọ ${index + 1} trên ${_room.images.length}',
                              child: Image.network(
                                _room.images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                        // Indicator
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${_room.images.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.apartment, size: 80, color: Colors.grey),
                    ),
            ),
          ),

          // 2. Nội dung chi tiết phòng trọ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner if Pending or Hidden/Rejected
                  if (_room.isHiddenOrRejected) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE4E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDA29B)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility_off_rounded, color: Color(0xFFD92D20), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bài viết này đã bị quản trị viên ẩn hoặc gỡ khỏi danh sách hiển thị.',
                              style: TextStyle(
                                color: Color(0xFFD92D20),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_room.isPending) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF0C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFEDF89)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: Color(0xFFB54708), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bài viết này đang chờ quản trị viên xét duyệt trước khi hiển thị công khai.',
                              style: TextStyle(
                                color: Color(0xFFB54708),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Text(
                    _room.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Address
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _room.address,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price & Deposit Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Giá thuê phòng', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              priceStr,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(height: 32, width: 1, color: AppColors.border),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tiền đặt cọc', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              depositStr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thông số phòng (Diện tích, Loại phòng, Trạng thái)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSpecItem(Icons.square_foot, '${_room.area} m²', 'Diện tích'),
                        _buildSpecDivider(),
                        _buildSpecItem(Icons.home_work_outlined, _room.roomType, 'Loại phòng'),
                        _buildSpecDivider(),
                        _buildSpecItem(
                          _room.isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                          _room.isAvailable ? 'Còn phòng' : 'Hết phòng',
                          'Tình trạng',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Thông tin chủ nhà
                  Text('Thông tin chủ trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _openHostProfile,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryContainer,
                              child: Text(
                                _room.hostName.isNotEmpty ? _room.hostName[0] : 'H',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _room.hostName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.verified, size: 14, color: AppColors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Chủ nhà đã xác minh • Nhấn để xem hồ sơ',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.phone_in_talk, color: AppColors.primary),
                              tooltip: 'Gọi điện chủ trọ',
                              onPressed: _onCallHostPressed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tiện ích phòng trọ
                  Text('Tiện ích phòng trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _room.amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _getAmenityLabel(amenity),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Mô tả chi tiết
                  Text('Mô tả chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _room.description,
                      style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
          if (postAsync.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),

      // 3. Bottom Action Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. Nút Báo cáo
              Semantics(
                label: 'Báo cáo bài đăng',
                button: true,
                excludeSemantics: true,
                child: OutlinedButton.icon(
                  onPressed: _onReportPressed,
                  icon: const Icon(Icons.flag_outlined, color: Color(0xFFDC2626), size: 16),
                  label: const Text(
                    'Báo cáo',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(78, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.45)),
                    backgroundColor: AppColors.dangerContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Nút Nhắn tin
              Semantics(
                label: 'Nhắn tin với chủ nhà',
                button: true,
                excludeSemantics: true,
                child: OutlinedButton.icon(
                  onPressed: _onChatPressed,
                  icon: Icon(Icons.chat_outlined, color: AppColors.primary, size: 17),
                  label: Text(
                    'Nhắn tin',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(92, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    side: BorderSide(color: AppColors.primary, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Nút Đặt phòng nhanh
              Expanded(
                child: Semantics(
                  label: _room.isHiddenOrRejected
                      ? 'Bài đăng đã bị ẩn'
                      : _room.isPending
                          ? 'Đang chờ duyệt'
                          : 'Đặt phòng nhanh',
                  button: true,
                  excludeSemantics: true,
                  child: ElevatedButton.icon(
                    onPressed: _onQuickBookingPressed,
                    icon: Icon(
                      _room.isHiddenOrRejected
                          ? Icons.visibility_off_outlined
                          : _room.isPending
                              ? Icons.schedule_outlined
                              : Icons.bolt,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _room.isHiddenOrRejected
                            ? 'Bài đăng đã bị ẩn'
                            : _room.isPending
                                ? 'Đang chờ duyệt'
                                : 'Đặt phòng nhanh',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        maxLines: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _room.isHiddenOrRejected
                          ? const Color(0xFF98A2B3)
                          : _room.isPending
                              ? const Color(0xFFF79009)
                              : AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingPost() {
    return _buildPostState(
      icon: Icons.article_outlined,
      title: 'Bài đăng không còn tồn tại',
      message: 'Bài đăng này có thể đã bị chủ trọ xóa hoặc ẩn khỏi Firebase.',
    );
  }

  Widget _buildLoadError() {
    return _buildPostState(
      icon: Icons.cloud_off_outlined,
      title: 'Không thể tải bài đăng',
      message: 'Vui lòng kiểm tra kết nối mạng rồi thử lại.',
      action: FilledButton.icon(
        onPressed: () => ref.invalidate(roomPostDetailProvider(widget.room.id)),
        icon: const Icon(Icons.refresh),
        label: const Text('Thử lại'),
      ),
    );
  }

  Widget _buildPostState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Chi tiết bài đăng'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (action != null) ...[const SizedBox(height: 20), action],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String value, String label) {
    return MergeSemantics(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSpecDivider() {
    return Container(
      height: 28,
      width: 1,
      color: AppColors.border,
    );
  }

  String _getAmenityLabel(String key) {
    switch (key) {
      case 'wifi':
        return 'Wifi tốc độ cao';
      case 'air_conditioner':
        return 'Máy lạnh Inverter';
      case 'fridge':
        return 'Tủ lạnh riêng';
      case 'washer':
        return 'Máy giặt';
      case 'balcony':
        return 'Ban công thoáng';
      case 'loft':
        return 'Gác lửng cao';
      case 'security':
        return 'Bảo vệ / Camera';
      case 'parking':
        return 'Bãi xe trong nhà';
      default:
        return key;
    }
  }
}
