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

  void _onReportPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportHostScreen.fromRoom(_room),
      ),
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
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _cleanedImages.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
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
                              '${_currentImageIndex + 1}/${_cleanedImages.length}',
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

                  // Title & Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _room.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Đánh giá ${_room.rating} sao trên ${_room.reviewCount} lượt đánh giá',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Color(0xFFFFA000)),
                              const SizedBox(width: 4),
                              Text(
                                '${_room.rating}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB78103)),
                              ),
                              Text(
                                ' (${_room.reviewCount})',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                          _room.isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                          _room.isAvailable ? 'Còn phòng' : 'Hết phòng',
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
              // 1. Nút Báo cáo chủ trọ
              Semantics(
                label: 'Báo cáo vi phạm chủ trọ',
                button: true,
                excludeSemantics: true,
                child: OutlinedButton.icon(
                  onPressed: _onReportPressed,
                  icon: const Icon(Icons.flag_outlined, color: Color(0xFFDC2626), size: 16),
                  label: const Text(
                    'Báo cáo chủ trọ',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
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
                  icon: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 17),
                  label: const Text(
                    'Nhắn tin',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(92, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    side: const BorderSide(color: AppColors.primary, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Nút Đặt phòng nhanh (Ẩn nếu là Chủ trọ xem bài của chính mình)
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
