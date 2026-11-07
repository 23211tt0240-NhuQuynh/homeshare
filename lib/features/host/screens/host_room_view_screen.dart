import '../data/host_property.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/user_provider.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/host_post_model.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../providers/host_management_provider.dart';
import 'host_room_edit_screen.dart';

/// Màn hình xem chi tiết phòng dành riêng cho Role Chủ trọ (Host).
/// - Xem thông số, tiện ích, chi phí dịch vụ của phòng gắn kèm bài đăng.
/// - Nếu là phòng của mình: Hiển thị "Phòng của bạn" & nút Chỉnh sửa.
/// - Nếu là phòng của đối tác (chủ trọ khác): Hiển thị nút "Nhắn tin trao đổi" & "Gọi điện".
/// - Tuyệt đối KHÔNG có nút Đặt phòng, KHÔNG có nút Báo cáo chủ trọ của Renter.
class HostRoomViewScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final HostPostModel? post;

  const HostRoomViewScreen({
    super.key,
    required this.room,
    this.post,
  });

  /// Làm sạch định dạng URL ảnh phòng
  static String cleanImageUrl(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      final u = (raw['url'] ??
              raw['duongDan'] ??
              raw['image'] ??
              raw['imageUrl'] ??
              raw['link'] ??
              raw['photo'] ??
              raw['path'] ??
              '')
          .toString()
          .trim();
      return cleanImageUrl(u);
    }
    var s = raw.toString().trim();
    if (s.isEmpty) return '';

    if (s.startsWith('data:image') ||
        s.startsWith('blob:') ||
        s.startsWith('base64,')) {
      return s;
    }

    final httpMatch = RegExp(r"""https?://[^\s",'}\]]+""").firstMatch(s);
    if (httpMatch != null) {
      return httpMatch.group(0)!;
    }

    if ((s.startsWith("'") && s.endsWith("'")) ||
        (s.startsWith('"') && s.endsWith('"'))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  @override
  ConsumerState<HostRoomViewScreen> createState() => _HostRoomViewScreenState();
}

class _HostRoomViewScreenState extends ConsumerState<HostRoomViewScreen> {
  late final PageController _pageController;
  int _currentImageIndex = 0;
  List<String> _extraImages = const [];
  List<String> _extraAmenities = const [];
  bool _checkedFallbacks = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadExtraInfo();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExtraInfo() async {
    if (_checkedFallbacks) return;
    _checkedFallbacks = true;
    try {
      final repo = ref.read(hostRepositoryProvider);
      final imgs = await repo.getRoomImagesFromAnhPhong(widget.room.id);
      final ams =
          await repo.getRoomAmenitiesFromTienIchPhong(widget.room.id);
      if (mounted && (imgs.isNotEmpty || ams.isNotEmpty)) {
        setState(() {
          if (imgs.isNotEmpty) _extraImages = imgs;
          if (ams.isNotEmpty) _extraAmenities = ams;
        });
      }
    } catch (_) {}
  }

  String _formatCurrency(num value) {
    return NumberFormat.decimalPattern('vi').format(value);
  }

  void _onChatPressed() {
    final userProfile = ref.read(userProfileProvider).value;
    final currentUid = userProfile?.uid ?? '';
    final currentName = userProfile?.displayName ?? userProfile?.hoTen ?? 'Chủ trọ';

    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để trao đổi với chủ trọ'),
        ),
      );
      return;
    }

    final targetHostId = widget.room.hostId.isNotEmpty
        ? widget.room.hostId
        : (widget.post?.chuNhaId ?? '');

    if (currentUid == targetHostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng thuộc quyền sở hữu của bạn')),
      );
      return;
    }

    final targetHostName = widget.room.hostName.isNotEmpty
        ? widget.room.hostName
        : (widget.post?.authorName ?? 'Chủ trọ');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: targetHostId,
          receiverName: targetHostName,
          currentUserId: currentUid,
          currentUserName: currentName,
          pinnedRoom: widget.room,
        ),
      ),
    );
  }

  void _onCallHost() {
    final phone = widget.room.hostPhone.isNotEmpty
        ? widget.room.hostPhone
        : (widget.post?.soDienThoaiLienHe ?? 'Chưa cập nhật');

    final name = widget.room.hostName.isNotEmpty
        ? widget.room.hostName
        : (widget.post?.authorName ?? 'Chủ nhà');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone_in_talk, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Số điện thoại chủ trọ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liên hệ trực tiếp với chủ trọ $name:',
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (phone != 'Chưa cập nhật')
                    IconButton(
                      tooltip: 'Sao chép',
                      icon: const Icon(Icons.copy, size: 20, color: Color(0xFF2563EB)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép số điện thoại!')),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
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

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF2563EB)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceFeeItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String amount,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final post = widget.post;

    // Danh sách ảnh
    final allImages = <String>[];
    for (final img in [...room.images, ..._extraImages]) {
      final clean = HostRoomViewScreen.cleanImageUrl(img);
      if (clean.isNotEmpty && !allImages.contains(clean)) {
        allImages.add(clean);
      }
    }

    // Tiện ích
    final allAmenities = <String>{
      ...room.amenities,
      ..._extraAmenities,
      if (post != null) ...post.amenities,
    }.toList();

    // Xác định quyền sở hữu
    final userProfile = ref.watch(userProfileProvider).value;
    final currentUid = userProfile?.uid ?? '';
    final isMyRoom = currentUid.isNotEmpty &&
        (currentUid == room.hostId ||
            currentUid == room.chuNhaId ||
            (post != null &&
                (currentUid == post.hostId || currentUid == post.chuNhaId)));

    final roomTitle = room.title.isNotEmpty
        ? room.title
        : (room.roomCode.isNotEmpty
            ? 'Phòng ${room.roomCode}'
            : (post?.title.isNotEmpty == true ? post!.title : 'Phòng trọ'));

    final hostName = room.hostName.isNotEmpty
        ? room.hostName
        : (post?.authorName.isNotEmpty == true ? post!.authorName : 'Chủ trọ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thông tin phòng trọ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. CAROUSEL HÌNH ẢNH PHÒNG
            Stack(
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: allImages.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: allImages.length,
                          onPageChanged: (i) {
                            setState(() => _currentImageIndex = i);
                          },
                          itemBuilder: (ctx, index) {
                            final url = allImages[index];
                            return Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(
                              Icons.meeting_room_outlined,
                              size: 64,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                ),

                // Indicator số ảnh
                if (allImages.length > 1)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${allImages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                // Huy hiệu trạng thái phòng
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: room.isOccupied
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          room.isOccupied
                              ? Icons.person_rounded
                              : Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          room.isOccupied ? 'Đang có người ở' : 'Phòng còn trống',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // NỘI DUNG CHÍNH
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên phòng & Giá thuê
                  Text(
                    roomTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (room.address.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room.address,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // Khối Giá & Cọc
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GIÁ THUÊ PHÒNG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${_formatCurrency(room.price)} đ',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                                const Text(
                                  ' /tháng',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (room.deposit > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'TIỀN CỌC',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  '${_formatCurrency(room.deposit)} đ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. BA THẺ THỐNG KÊ (DIỆN TÍCH / LOẠI PHÒNG / TÌNH TRẠNG)
                  Row(
                    children: [
                      _buildStatBox(
                        icon: Icons.straighten_rounded,
                        value: '${room.area > 0 ? room.area.toInt() : 25} m²',
                        label: 'Diện tích',
                      ),
                      const SizedBox(width: 10),
                      _buildStatBox(
                        icon: Icons.apartment_rounded,
                        value: room.roomType.isNotEmpty
                            ? room.roomType
                            : 'Phòng trọ',
                        label: 'Loại phòng',
                      ),
                      const SizedBox(width: 10),
                      _buildStatBox(
                        icon: Icons.check_circle_outline_rounded,
                        value: room.isOccupied ? 'Đang ở' : 'Còn phòng',
                        label: 'Tình trạng',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. CHI PHÍ DỊCH VỤ HÀNG THÁNG
                  const Text(
                    'Chi phí dịch vụ hàng tháng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        _buildServiceFeeItem(
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFD97706),
                          iconBg: const Color(0xFFFEF3C7),
                          amount:
                              '${room.electricityRate != null && room.electricityRate! > 0 ? _formatCurrency(room.electricityRate!) : '2.500'} đ/kWh',
                          label: 'Tiền điện',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE2E8F0),
                        ),
                        _buildServiceFeeItem(
                          icon: Icons.water_drop_rounded,
                          iconColor: const Color(0xFF0284C7),
                          iconBg: const Color(0xFFE0F2FE),
                          amount:
                              '${room.waterRate != null && room.waterRate! > 0 ? _formatCurrency(room.waterRate!) : '80.000'} đ/m³',
                          label: 'Tiền nước',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE2E8F0),
                        ),
                        _buildServiceFeeItem(
                          icon: Icons.wifi_rounded,
                          iconColor: const Color(0xFF059669),
                          iconBg: const Color(0xFFD1FAE5),
                          amount:
                              '${room.serviceFee != null && room.serviceFee! > 0 ? _formatCurrency(room.serviceFee!) : '22.000'} đ/tháng',
                          label: 'Dịch vụ / Wifi',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. THÔNG TIN CHỦ TRỌ
                  const Text(
                    'Thông tin chủ trọ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Text(
                            hostName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E40AF),
                            ),
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
                                    hostName,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 15,
                                    color: Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Chủ nhà đã xác minh • Đối tác hệ thống',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Gọi điện thoại',
                          onPressed: _onCallHost,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.phone_rounded,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. TIỆN ÍCH PHÒNG TRỌ
                  if (allAmenities.isNotEmpty) ...[
                    const Text(
                      'Tiện ích phòng trọ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allAmenities.map(_buildAmenityChip).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6. MÔ TẢ CHI TIẾT
                  const Text(
                    'Mô tả chi tiết',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      room.description.isNotEmpty
                          ? room.description
                          : (post?.description.isNotEmpty == true
                              ? post!.description
                              : 'Chưa có mô tả chi tiết cho phòng này.'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),

      // THANH BOTTOM BAR DÀNH RIÊNG CHO ROLE CHỦ TRỌ
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: isMyRoom
              ? Row(
                  children: [
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
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Phòng của bạn',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (room.propertyId.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          final houses = ref.read(hostPropertiesProvider).value ?? [];
                          final prop = houses.firstWhere(
                            (p) => p.id == room.propertyId,
                            orElse: () => HostProperty(
                              id: room.propertyId,
                              hostId: currentUid,
                              name: 'Nhà trọ',
                              address: room.address,
                              city: room.city.isNotEmpty ? room.city : 'TP. Hồ Chí Minh',
                              ward: '',
                              plannedRooms: 1,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HostRoomEditScreen(
                                property: prop,
                                room: room,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: Colors.white),
                        label: const Text(
                          'Chỉnh sửa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    // Nút Gọi điện
                    OutlinedButton.icon(
                      onPressed: _onCallHost,
                      icon: const Icon(
                        Icons.phone_outlined,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                      label: const Text(
                        'Gọi điện',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Nút Nhắn tin trao đổi hợp tác
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _onChatPressed,
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Nhắn tin trao đổi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
