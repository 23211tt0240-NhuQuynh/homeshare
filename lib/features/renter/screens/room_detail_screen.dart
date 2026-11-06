import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/room_service.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../../core/utils/host_post_report_policy.dart';
import '../../../core/utils/host_report_policy.dart';
import '../widgets/report_host_post_dialog.dart';
import 'report_host_screen.dart';
import 'room_booking_detail_screen.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final bool isHostView;

  const RoomDetailScreen({
    super.key,
    required this.room,
    this.isHostView = false,
  });

  /// Làm sạch định dạng URL ảnh, loại bỏ triệt để lỗi crash hình ảnh khi Firestore trả về
  /// chuỗi {url: ...} hoặc dấu ngoặc kép thừa
  static String cleanImageUrl(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      final u = (raw['url'] ??
              raw['duongDan'] ??
              raw['image'] ??
              raw['imageUrl'] ??
              raw['link'] ??
              '')
          .toString()
          .trim();
      return cleanImageUrl(u);
    }
    var s = raw.toString().trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith("'") && s.endsWith("'") && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('{') && s.endsWith('}')) {
      final match = RegExp(
        r'(?:duongDan|url|image|imageUrl|link):\s*([^,}]+)',
      ).firstMatch(s);
      if (match != null) {
        s = match.group(1)!.trim().replaceAll('"', '').replaceAll("'", "");
      }
    }
    return s;
  }

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

  List<String> get _cleanedImages {
    final list = <String>[];
    for (final raw in _room.images) {
      final cleaned = RoomDetailScreen.cleanImageUrl(raw);
      if (cleaned.isNotEmpty &&
          (cleaned.startsWith('http://') ||
              cleaned.startsWith('https://') ||
              cleaned.startsWith('blob:') ||
              cleaned.startsWith('data:'))) {
        list.add(cleaned);
      }
    }
    return list;
  }

  Future<void> _onQuickBookingPressed() async {
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

    // Kiểm tra trạng thái phòng trên host_rooms trước khi chuyển màn hình
    if (_room.id.isNotEmpty) {
      try {
        final hostRoomSnap = await FirebaseFirestore.instance.collection('host_rooms').doc(_room.id).get();
        if (hostRoomSnap.exists) {
          final rData = hostRoomSnap.data() ?? {};
          final rStatus = (rData['status'] ?? '').toString().toLowerCase();
          if (rStatus == 'pending_confirmation') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Phòng này vừa có khách chuyển khoản cọc và đang chờ xác nhận. Vui lòng chọn phòng khác!'),
                  backgroundColor: Color(0xFFB54708),
                ),
              );
            }
            return;
          }

          final isHolding = rData['isHolding'] == true;
          final holdingExpiresAt = (rData['holdingExpiresAt'] as Timestamp?)?.toDate();
          final holdingRenterId = (rData['holdingRenterId'] ?? '').toString();
          if (isHolding && holdingExpiresAt != null && holdingExpiresAt.isAfter(DateTime.now())) {
            if (holdingRenterId.isNotEmpty && holdingRenterId != user.uid) {
              final diffMinutes = holdingExpiresAt.difference(DateTime.now()).inMinutes + 1;
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: Color(0xFFB54708)),
                        SizedBox(width: 8),
                        Text('Phòng đang được giữ chỗ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    content: Text(
                      'Phòng này hiện đang có khách quét mã QR chuyển khoản giữ chỗ (còn khoảng $diffMinutes phút).\n\nNếu khách không hoàn tất thanh toán trong thời gian trên, hệ thống sẽ tự động mở lại phòng để bạn đặt!',
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Đã hiểu'),
                      ),
                    ],
                  ),
                );
              }
              return;
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomBookingDetailScreen(room: _room),
        ),
      );
    }
  }

  void _onReportHostPressed() {
    final reporterId = ref.read(currentUserProvider)?.uid ?? '';
    if (reporterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để báo cáo.')),
      );
      return;
    }
    if (!HostReportPolicy.canReport(
      reporterId: reporterId,
      hostId: _room.hostId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không thể tự báo cáo chính mình.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportHostScreen.fromRoom(_room),
      ),
    );
  }

  Future<void> _onReportPostPressed() async {
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
        const SnackBar(content: Text('Bạn không thể tự báo cáo bài đăng của chính mình.')),
      );
      return;
    }
    await showReportHostPostDialog(
      context,
      postId: _room.id,
      postTitle: _room.title,
      hostId: _room.hostId,
      hostName: _room.hostName,
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
    final isInventoryRoom = _room.isPending || _room.isUnposted;

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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? const Color(0xFFEF4444) : AppColors.textDark,
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
                                  backgroundColor: added ? AppColors.primary : const Color(0xFF334155),
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
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textDark, size: 20),
                    tooltip: 'Tùy chọn',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'report_post') {
                        _onReportPostPressed();
                      } else if (value == 'report_host') {
                        _onReportHostPressed();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report_post',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, size: 18, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text('Báo cáo bài viết này', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'report_host',
                        child: Row(
                          children: [
                            Icon(Icons.person_off_outlined, size: 18, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text('Báo cáo chủ trọ này', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _cleanedImages.isNotEmpty
                      ? PageView.builder(
                          itemCount: _cleanedImages.length,
                          onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                          itemBuilder: (context, index) {
                            return Semantics(
                              image: true,
                              label: 'Ảnh phòng trọ ${index + 1} trên ${_cleanedImages.length}',
                              child: Image.network(
                                _cleanedImages[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.apartment, size: 80, color: Colors.grey),
                        ),
                  // Indicator đếm số ảnh
                  if (_cleanedImages.isNotEmpty)
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
                          '${_currentImageIndex + 1}/${_cleanedImages.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // Badge nhận diện Hồ sơ thông tin phòng nếu chưa đăng hoặc đang chờ duyệt
                  if (isInventoryRoom)
                    Positioned(
                      top: 48,
                      left: 64,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _room.isPending ? const Color(0xFFD97706) : const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _room.isPending ? Icons.pending_actions_rounded : Icons.inventory_2_outlined,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _room.isPending ? 'BÀI ĐĂNG CHỜ DUYỆT • HỒ SƠ PHÒNG' : 'KHO PHÒNG • HỒ SƠ PHÒNG',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Nội dung chi tiết: Phân tách rõ ràng giữa Hồ sơ phòng trọ và Bài đăng
          SliverToBoxAdapter(
            child: isInventoryRoom
                ? _buildRoomInventoryDetailView(currencyFormatter, priceStr, depositStr)
                : _buildPublishedPostDetailView(currencyFormatter, priceStr, depositStr),
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

      // 3. Bottom Action Bar: Nút bấm phù hợp với loại hình (Hồ sơ phòng vs Bài đăng)
      bottomSheet: isInventoryRoom
          ? _buildRoomInventoryBottomBar()
          : _buildPublishedPostBottomBar(),
    );
  }

  /// GIAO DIỆN 1: BÀI ĐĂNG CHO THUÊ (PUBLISHED POST VIEW)
  /// Hiển thị phong cách thương mại, tiếp thị phòng, nút Đặt phòng nhanh
  Widget _buildPublishedPostDetailView(
    NumberFormat currencyFormatter,
    String priceStr,
    String depositStr,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner if Hidden/Rejected
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
          ],

          // Title
          Text(
            _room.title,
            style: const TextStyle(
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
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _room.address,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price & Deposit Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                    const Text('Giá thuê phòng', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      priceStr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Container(height: 32, width: 1, color: const Color(0xFFE5E7EB)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tiền đặt cọc', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      depositStr,
                      style: const TextStyle(
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
              color: Colors.white,
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
                  _room.isRentedOrOccupied ? Icons.person_off_rounded : Icons.check_circle_outline,
                  _room.isRentedOrOccupied ? 'Đã có người ở' : 'Còn trống',
                  'Tình trạng',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chi phí điện, nước & dịch vụ
          const Text(
            'Chi phí dịch vụ hàng tháng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUtilityItem(
                  Icons.bolt_rounded,
                  const Color(0xFFF59E0B),
                  _room.electricityRate != null && _room.electricityRate! > 0
                      ? '${currencyFormatter.format(_room.electricityRate)} đ/kWh'
                      : 'Giá nhà nước',
                  'Tiền điện',
                ),
                _buildSpecDivider(),
                _buildUtilityItem(
                  Icons.water_drop_rounded,
                  const Color(0xFF0284C7),
                  _room.waterRate != null && _room.waterRate! > 0
                      ? '${currencyFormatter.format(_room.waterRate)} đ/m³'
                      : 'Quy định / Miễn phí',
                  'Tiền nước',
                ),
                _buildSpecDivider(),
                _buildUtilityItem(
                  Icons.wifi_rounded,
                  const Color(0xFF10B981),
                  _room.serviceFee != null && _room.serviceFee! > 0
                      ? '${currencyFormatter.format(_room.serviceFee)} đ/tháng'
                      : 'Miễn phí',
                  'Dịch vụ / Wifi',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Thông tin chủ nhà
          const Text('Thông tin chủ trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
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
                              const Icon(Icons.verified, size: 14, color: AppColors.primary),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Chủ nhà đã xác minh • Nhấn để xem hồ sơ',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk, color: AppColors.primary),
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
          const Text('Tiện ích phòng trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _room.amenities.map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _getAmenityLabel(amenity),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Mô tả chi tiết
          const Text('Mô tả chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _room.description,
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// GIAO DIỆN 2: HỒ SƠ THÔNG TIN PHÒNG TRỌ (ROOM INVENTORY & SPECIFICATION VIEW)
  /// Dành riêng cho phòng trong kho quản lý hoặc bài đăng đang chờ duyệt.
  /// Bố cục dạng Bảng thông số kỹ thuật (Blueprint Sheet), biểu phí niêm yết, danh mục bàn giao.
  Widget _buildRoomInventoryDetailView(
    NumberFormat currencyFormatter,
    String priceStr,
    String depositStr,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Alert Banner phân biệt rõ ràng
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _room.isPending ? const Color(0xFFFEF0C7) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _room.isPending ? const Color(0xFFFEDF89) : const Color(0xFFFFD6A4),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _room.isPending ? Icons.pending_actions_rounded : Icons.inventory_2_outlined,
                  color: _room.isPending ? const Color(0xFFB54708) : const Color(0xFFC2410C),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _room.isPending
                            ? 'THÔNG TIN PHÒNG TRỌ (BÀI ĐĂNG CHỜ DUYỆT)'
                            : 'THÔNG TIN PHÒNG TRỌ (KHO PHÒNG CHỦ TRỌ)',
                        style: TextStyle(
                          color: _room.isPending ? const Color(0xFF93370D) : const Color(0xFF9A3412),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _room.isPending
                            ? 'Bài viết quảng cáo của phòng này đang được Quản trị viên xét duyệt. Bố cục bên dưới là hồ sơ thông số kỹ thuật của phòng để bạn tham khảo trước khi liên hệ chủ trọ.'
                            : 'Phòng này được lưu trữ trong kho phòng của chủ trọ và chưa tạo bài đăng công khai. Bạn có thể xem thông số kỹ thuật và liên hệ trực tiếp chủ trọ để hỏi thuê.',
                        style: TextStyle(
                          color: _room.isPending ? const Color(0xFF78350F) : const Color(0xFF7C2D12),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Header Tên & Mã phòng kỹ thuật
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Text(
                  'HỒ SƠ PHÒNG TRỌ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475467),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _room.isRentedOrOccupied ? const Color(0xFFFEF3F2) : const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _room.isRentedOrOccupied ? const Color(0xFFFECDCA) : const Color(0xFFA6F4C5),
                  ),
                ),
                child: Text(
                  _room.isRentedOrOccupied ? '🔴 Đã có người ở' : '🟢 Phòng còn trống',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _room.isRentedOrOccupied ? const Color(0xFFB42318) : const Color(0xFF027A48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            'Phòng ${_room.roomCode.isNotEmpty ? _room.roomCode : _room.maPhong}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              height: 1.25,
            ),
          ),
          if (_room.title.isNotEmpty &&
              _room.title.trim().toUpperCase() != _room.maPhong &&
              _room.title.trim().toUpperCase() != _room.roomCode.toUpperCase()) ...[
            const SizedBox(height: 4),
            Text(
              'Dự thảo bài viết: "${_room.title}"',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Địa chỉ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _room.address,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. BẢNG HỒ SƠ THÔNG SỐ KỸ THUẬT (Specification Blueprint Card)
          _buildInventorySectionTitle(Icons.fact_check_outlined, 'Bảng thông số kỹ thuật phòng'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildBlueprintRow('Mã định danh phòng', _room.maPhong.isNotEmpty ? _room.maPhong : _room.id, isHighlight: true),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow('Mã nhà trọ / Cơ sở', _room.propertyId.isNotEmpty ? _room.propertyId : 'Nhà trọ riêng'),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow('Vị trí tầng', _room.floor > 0 ? 'Tầng ${_room.floor}' : 'Tầng trệt'),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow('Diện tích sử dụng', '${_room.area} m²'),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow('Loại hình phòng', _room.roomType.isNotEmpty ? _room.roomType : 'Phòng trọ'),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow('Sức chứa tối đa', '${_room.capacity > 0 ? _room.capacity : 2} người'),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow(
                  'Tình trạng hiện tại',
                  _room.isRentedOrOccupied ? 'Đã có người ở' : 'Còn trống',
                  valueColor: _room.isRentedOrOccupied ? const Color(0xFFB42318) : const Color(0xFF027A48),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. BIỂU PHÍ ĐỊNH MỨC NIÊM YẾT (Official Rate Card)
          _buildInventorySectionTitle(Icons.receipt_long_outlined, 'Biểu phí định mức niêm yết'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giá thuê phòng niêm yết', style: TextStyle(fontSize: 13, color: Color(0xFF475467))),
                    Text(
                      priceStr,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiền đặt cọc quy định ${_room.depositPercentage != null ? "(${_room.depositPercentage}%)" : ""}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
                    ),
                    Text(
                      depositStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow(
                  'Đơn giá tiền điện',
                  _room.electricityRate != null && _room.electricityRate! > 0
                      ? '${currencyFormatter.format(_room.electricityRate)} đ/kWh'
                      : 'Theo giá nhà nước',
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow(
                  'Đơn giá tiền nước',
                  _room.waterRate != null && _room.waterRate! > 0
                      ? '${currencyFormatter.format(_room.waterRate)} đ/m³'
                      : 'Theo đồng hồ / Quy định',
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                _buildBlueprintRow(
                  'Phí dịch vụ / Wifi',
                  _room.serviceFee != null && _room.serviceFee! > 0
                      ? '${currencyFormatter.format(_room.serviceFee)} đ/tháng'
                      : 'Miễn phí',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. DANH MỤC TRANG THIẾT BỊ BÀN GIAO (Checklist)
          _buildInventorySectionTitle(Icons.checklist_rounded, 'Danh mục trang thiết bị bàn giao'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _room.amenities.isEmpty
                ? const Text('Chưa có danh mục trang thiết bị cụ thể.', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _room.amenities.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_box_outlined, size: 15, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text(
                              _getAmenityLabel(item),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // 6. GHI CHÚ BÀN GIAO & NỘI QUY PHÒNG
          _buildInventorySectionTitle(Icons.description_outlined, 'Ghi chú & Nội quy phòng'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _room.description.trim().isNotEmpty
                  ? _room.description
                  : 'Chưa có ghi chú chi tiết từ chủ trọ.',
              style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 20),

          // 7. THÔNG TIN CHỦ QUẢN LÝ PHÒNG
          _buildInventorySectionTitle(Icons.person_pin_circle_outlined, 'Chủ trọ phụ trách phòng'),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
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
                      backgroundColor: const Color(0xFFFEF0C7),
                      child: Text(
                        _room.hostName.isNotEmpty ? _room.hostName[0] : 'H',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB54708), fontSize: 18),
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
                              const Icon(Icons.verified, size: 14, color: AppColors.primary),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Chủ quản lý kho phòng • Nhấn để xem hồ sơ',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk, color: AppColors.primary),
                      tooltip: 'Gọi điện chủ trọ',
                      onPressed: _onCallHostPressed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueprintRow(String label, String value, {bool isHighlight = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (isHighlight ? AppColors.primary : AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFD97706)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  /// BOTTOM BAR CHO BÀI ĐĂNG THƯƠNG MẠI: Nhắn tin + Đặt phòng nhanh
  Widget _buildPublishedPostBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
            // 1. Nút Nhắn tin
            Semantics(
              label: 'Nhắn tin với chủ nhà',
              button: true,
              excludeSemantics: true,
              child: OutlinedButton.icon(
                onPressed: _onChatPressed,
                icon: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 18),
                label: const Text(
                  'Nhắn tin',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Nút Đặt phòng nhanh (Ẩn nếu là Chủ trọ xem bài của chính mình)
            if (!widget.isHostView)
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
              )
            else
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF1E60F2)),
                      SizedBox(width: 8),
                      Text(
                        'Bài đăng của bạn',
                        style: TextStyle(
                          color: Color(0xFF1E60F2),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// BOTTOM BAR CHO HỒ SƠ THÔNG TIN PHÒNG TRỌ (CHƯA ĐĂNG BÀI / CHỜ DUYỆT)
  /// Thay nút đặt phòng bằng 2 nút: Gọi điện hỏi phòng + Nhắn tin hỏi phòng
  Widget _buildRoomInventoryBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: _room.isPending ? const Color(0xFFB54708) : const Color(0xFFC2410C),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _room.isPending
                          ? 'Bài đăng đang chờ duyệt. Liên hệ chủ trọ để hỏi thêm thông tin phòng.'
                          : 'Phòng trong kho lưu trữ. Liên hệ trực tiếp chủ trọ để hỏi thuê.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _room.isPending ? const Color(0xFFB54708) : const Color(0xFFC2410C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // 1. Nút Nhắn tin hỏi phòng
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _onChatPressed,
                    icon: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 18),
                    label: const Text(
                      'Nhắn tin hỏi phòng',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 2. Nút Gọi điện hỏi phòng
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onCallHostPressed,
                    icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 18),
                    label: const Text(
                      'Gọi hỏi phòng',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        backgroundColor: Colors.white,
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSpecDivider() {
    return Container(
      height: 28,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildUtilityItem(
    IconData icon,
    Color iconColor,
    String value,
    String label,
  ) {
    return Expanded(
      child: MergeSemantics(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
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
