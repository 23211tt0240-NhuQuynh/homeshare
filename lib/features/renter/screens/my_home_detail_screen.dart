import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/host_review_policy.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/checkout_record_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';
import '../../profile/widgets/host_review_sheet.dart';
import '../widgets/report_room_issue_bottom_sheet.dart';
import '../widgets/send_roommate_invite_sheet.dart';
import 'my_homes_screen.dart';
import 'room_detail_screen.dart';

/// Màn hình Chi tiết phòng đang thuê / Lịch sử phòng đã ở
/// Hiển thị thông tin toàn diện: Hợp đồng, tài chính, tiện ích, điện nước, chủ trọ, cư dân cùng phòng
class MyHomeDetailScreen extends ConsumerStatefulWidget {
  final BookingRequestModel? booking;
  final PastRentalHomeItem? pastItem;

  const MyHomeDetailScreen({
    super.key,
    this.booking,
    this.pastItem,
  }) : assert(booking != null || pastItem != null, 'Phải cung cấp booking hoặc pastItem');

  @override
  ConsumerState<MyHomeDetailScreen> createState() => _MyHomeDetailScreenState();
}

class _MyHomeDetailScreenState extends ConsumerState<MyHomeDetailScreen> {
  final NumberFormat _currencyFmt = NumberFormat('#,###', 'vi_VN');
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  bool _isLoadingRoom = true;
  RoomModel? _room;
  List<ResidentModel> _residents = [];

  bool get isPast => widget.pastItem != null;

  String get roomId => widget.booking?.roomId ?? widget.pastItem?.roomId ?? '';
  String get roomTitle => widget.booking?.roomTitle ?? widget.pastItem?.roomTitle ?? 'Phòng trọ';
  String get roomAddress => widget.booking?.roomAddress ?? widget.pastItem?.roomAddress ?? 'Địa chỉ đang cập nhật';
  double get roomPrice => widget.booking?.roomPrice ?? widget.pastItem?.roomPrice ?? 0.0;
  double get deposit => widget.booking?.deposit ?? widget.pastItem?.depositAmount ?? 0.0;
  String get hostName => widget.booking?.hostName ?? widget.pastItem?.hostName ?? 'Chủ nhà';
  String get hostPhone => widget.pastItem?.hostPhone ?? _room?.hostPhone ?? '';
  DateTime get moveInDate => widget.booking?.moveInDate ?? widget.pastItem?.moveInDate ?? DateTime.now();
  DateTime? get moveOutDate => widget.booking?.moveOutDate ?? widget.pastItem?.moveOutDate;
  String get bookingCode => widget.booking?.id ?? widget.pastItem?.id ?? '';
  String get roomCode => widget.booking?.roomCode ?? _room?.roomCode ?? '';
  String get note => widget.booking?.note ?? widget.pastItem?.note ?? '';

  @override
  void initState() {
    super.initState();
    _loadRoomAndResidents();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomAndResidents() async {
    if (roomId.isEmpty) {
      if (mounted) setState(() => _isLoadingRoom = false);
      return;
    }

    try {
      final db = FirebaseFirestore.instance;

      // 1. Tải thông tin phòng từ `rooms` hoặc `host_rooms`
      RoomModel? loadedRoom;
      final roomDoc = await db.collection('rooms').doc(roomId).get();
      if (roomDoc.exists) {
        loadedRoom = RoomModel.fromFirestore(roomDoc);
      } else {
        final hostDoc = await db.collection('host_rooms').doc(roomId).get();
        if (hostDoc.exists) {
          loadedRoom = RoomModel.fromFirestore(hostDoc);
        }
      }

      // 2. Tải danh sách cư dân cùng phòng (residents)
      final residentSnap = await db
          .collection(FirestoreCollections.residents)
          .where('roomId', isEqualTo: roomId)
          .get();

      final residentsList = residentSnap.docs
          .map((d) => ResidentModel.fromFirestore(d))
          .where((r) => isPast ? true : r.isActive)
          .toList();

      if (mounted) {
        setState(() {
          _room = loadedRoom;
          _residents = residentsList;
          _isLoadingRoom = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading room details: $e');
      if (mounted) {
        setState(() => _isLoadingRoom = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có số điện thoại liên hệ của chủ trọ.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gọi đến $cleanPhone')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label vào bộ nhớ tạm'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleReportIssue() async {
    final b = widget.booking;
    if (b != null) {
      await showReportRoomIssueBottomSheet(context, booking: b);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ phòng đang ở mới có thể gửi báo cáo sự cố.')),
      );
    }
  }

  void _handleRoommateInvite() {
    final b = widget.booking;
    if (b != null) {
      SendRoommateInviteSheet.show(context, booking: b);
    }
  }

  Future<void> _handleHostReview() async {
    final b = widget.booking;
    if (b == null) return;
    final ok = await showHostReviewSheet(
      context,
      hostId: b.hostId,
      hostName: b.hostName,
      bookingId: b.id,
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá chủ trọ!'),
          backgroundColor: Color(0xFF027A48),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFEAECF0);
    final textDark = isDark ? Colors.white : const Color(0xFF1D2939);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);

    final displayImages = _room?.images.isNotEmpty == true
        ? _room!.images
        : <String>[];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          isPast ? 'Lịch sử phòng đã ở' : 'Chi tiết phòng đang ở',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_room != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Xem bài đăng gốc',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomDetailScreen(room: _room!)),
                );
              },
            ),
        ],
      ),
      body: _isLoadingRoom
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CAROUSEL ẢNH PHÒNG
                  _buildImageCarousel(displayImages, isDark),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. HEADER: TIÊU ĐỀ, MÃ PHÒNG, TRẠNG THÁI
                        _buildHeaderSection(isDark, cardColor, borderColor, textDark, textMuted),

                        const SizedBox(height: 16),

                        // 3. THẺ TÀI CHÍNH & KỲ HỢP ĐỒNG (NỔI BẬT)
                        _buildFinanceAndContractCard(isDark, cardColor, borderColor, textDark, textMuted),

                        const SizedBox(height: 16),

                        // 4. BIỂU PHÍ DỊCH VỤ (ĐIỆN, NƯỚC, PHÍ CHUNG)
                        _buildUtilitiesCard(isDark, cardColor, borderColor, textDark, textMuted),

                        const SizedBox(height: 16),

                        // 5. TIỆN NGHI & ĐẶC ĐIỂM PHÒNG
                        _buildAmenitiesSection(isDark, cardColor, borderColor, textDark, textMuted),

                        const SizedBox(height: 16),

                        // 6. THÔNG TIN CHỦ TRỌ & LIÊN HỆ
                        _buildHostContactCard(isDark, cardColor, borderColor, textDark, textMuted),

                        // 7. CƯ DÂN CÙNG PHÒNG (NẾU CÓ)
                        if (_residents.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildResidentsSection(isDark, cardColor, borderColor, textDark, textMuted),
                        ],

                        // 8. BIÊN BẢN TRẢ PHÒNG (NẾU CÓ)
                        if (isPast && widget.pastItem?.hasCheckoutRecord == true && widget.pastItem?.checkoutRecord != null) ...[
                          const SizedBox(height: 16),
                          _buildCheckoutSummaryCard(widget.pastItem!.checkoutRecord!, isDark, cardColor, borderColor, textDark, textMuted),
                        ],

                        // 9. NỘI QUY / MÔ TẢ PHÒNG
                        if (_room?.description.isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          _buildDescriptionSection(isDark, cardColor, borderColor, textDark, textMuted),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      // THANH THAO TÁC CỐ ĐỊNH Ở DƯỚI (BOTTOM BAR)
      bottomSheet: _buildBottomActions(isDark, cardColor, borderColor),
    );
  }

  // 1. CAROUSEL ẢNH
  Widget _buildImageCarousel(List<String> images, bool isDark) {
    if (images.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment_rounded, size: 64, color: isDark ? Colors.white38 : Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'HomeShare Smart Rental',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              );
            },
          ),
        ),
        // Badge đếm ảnh
        Positioned(
          bottom: 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. HEADER SECTION
  Widget _buildHeaderSection(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge trạng thái
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPast ? const Color(0xFFF2F4F7) : const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPast ? const Color(0xFFD0D5DD) : const Color(0xFFA6F4C5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPast ? Icons.task_alt_rounded : Icons.check_circle_rounded,
                      size: 14,
                      color: isPast ? const Color(0xFF475467) : const Color(0xFF12B76A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPast ? 'Đã hoàn tất kỳ ở' : 'Đang sinh sống',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPast ? const Color(0xFF344054) : const Color(0xFF027A48),
                      ),
                    ),
                  ],
                ),
              ),
              if (roomCode.isNotEmpty)
                GestureDetector(
                  onTap: () => _copyToClipboard(roomCode, 'Mã phòng'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Mã: $roomCode',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_rounded, size: 12, color: textMuted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            roomTitle,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textDark,
              height: 1.3,
            ),
          ),
          if (note == 'Ở ghép') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFB2DDFF)),
              ),
              child: const Text(
                'Hình thức: Ở ghép',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF175CD3),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFD92D20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  roomAddress,
                  style: TextStyle(fontSize: 13.5, color: textMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. THẺ TÀI CHÍNH & HỢP ĐỒNG
  Widget _buildFinanceAndContractCard(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF155EEF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF155EEF)),
              ),
              const SizedBox(width: 8),
              Text(
                'Thông tin hợp đồng & Chi phí',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: 'Tiền thuê phòng',
                  value: '${_currencyFmt.format(roomPrice)} đ/tháng',
                  valueColor: const Color(0xFF155EEF),
                  isBold: true,
                  textMuted: textMuted,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: isPast ? 'Tiền cọc ban đầu' : 'Tiền cọc giữ chỗ',
                  value: '${_currencyFmt.format(deposit)} đ',
                  valueColor: const Color(0xFF027A48),
                  isBold: true,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: 'Ngày bắt đầu ở',
                  value: DateFormat('dd/MM/yyyy').format(moveInDate),
                  textMuted: textMuted,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: isPast ? 'Ngày trả phòng' : 'Thời hạn hợp đồng',
                  value: isPast
                      ? (moveOutDate != null ? DateFormat('dd/MM/yyyy').format(moveOutDate!) : 'Đã kết thúc')
                      : (widget.booking?.rentalMonths != null ? '${widget.booking!.rentalMonths} tháng' : 'Lâu dài'),
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          if (bookingCode.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mã hợp đồng / Booking:', style: TextStyle(fontSize: 12, color: textMuted)),
                GestureDetector(
                  onTap: () => _copyToClipboard(bookingCode, 'Mã booking'),
                  child: Row(
                    children: [
                      Text(
                        bookingCode.length > 18 ? '#${bookingCode.substring(0, 16)}...' : '#$bookingCode',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 12, color: textMuted),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 4. BIỂU PHÍ DỊCH VỤ
  Widget _buildUtilitiesCard(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    final elec = _room?.electricityRate;
    final water = _room?.waterRate;
    final service = _room?.serviceFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF79009).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFF79009)),
              ),
              const SizedBox(width: 8),
              Text(
                'Biểu phí điện nước & Dịch vụ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUtilityChip(
                  icon: Icons.electric_bolt_rounded,
                  iconColor: const Color(0xFFF79009),
                  label: 'Tiền điện',
                  price: elec != null && elec > 0 ? '${_currencyFmt.format(elec)} đ/kWh' : 'Theo giá nhà nước',
                  isDark: isDark,
                  textDark: textDark,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildUtilityChip(
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF0BA5EC),
                  label: 'Tiền nước',
                  price: water != null && water > 0 ? '${_currencyFmt.format(water)} đ/khối' : 'Theo quy định',
                  isDark: isDark,
                  textDark: textDark,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          if (service != null && service > 0) ...[
            const SizedBox(height: 10),
            _buildUtilityChip(
              icon: Icons.wifi_rounded,
              iconColor: const Color(0xFF12B76A),
              label: 'Phí dịch vụ & Quản lý chung (Wifi, Rác, Gửi xe)',
              price: '${_currencyFmt.format(service)} đ/tháng',
              isDark: isDark,
              textDark: textDark,
              textMuted: textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUtilityChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String price,
    required bool isDark,
    required Color textDark,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
          ),
        ],
      ),
    );
  }

  // 5. TIỆN NGHI
  Widget _buildAmenitiesSection(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    final amenities = _room?.amenities ?? [];
    final area = _room?.area;
    final floor = _room?.floor;
    final roomType = _room?.roomType;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF027A48).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_box_outlined, size: 18, color: Color(0xFF027A48)),
              ),
              const SizedBox(width: 8),
              Text(
                'Đặc điểm phòng & Tiện ích',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Thông số vật lý
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricBadge(Icons.square_foot_rounded, area != null ? '$area m²' : 'Tiêu chuẩn', 'Diện tích', textDark, textMuted),
              _buildMetricBadge(Icons.stairs_rounded, floor != null && floor > 0 ? 'Tầng $floor' : 'Tầng trệt', 'Vị trí', textDark, textMuted),
              _buildMetricBadge(Icons.home_outlined, roomType?.isNotEmpty == true ? roomType! : 'Phòng trọ', 'Loại phòng', textDark, textMuted),
            ],
          ),
          if (amenities.isNotEmpty) ...[
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenities.map((amenity) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, size: 14, color: Color(0xFF027A48)),
                      const SizedBox(width: 5),
                      Text(
                        amenity,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textDark),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBadge(IconData icon, String value, String title, Color textDark, Color textMuted) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        Text(title, style: TextStyle(fontSize: 11, color: textMuted)),
      ],
    );
  }

  // 6. THÔNG TIN CHỦ TRỌ
  Widget _buildHostContactCard(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_circle_rounded, size: 18, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 8),
              Text(
                'Chủ nhà quản lý',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF027A48).withValues(alpha: 0.15),
                child: Text(
                  hostName.isNotEmpty ? hostName[0].toUpperCase() : 'C',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF027A48), fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hostName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hostPhone.isNotEmpty ? hostPhone : 'Chủ trọ trên HomeShare',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    ),
                  ],
                ),
              ),
              if (hostPhone.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(hostPhone),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Gọi ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF027A48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 7. CƯ DÂN CÙNG PHÒNG
  Widget _buildResidentsSection(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF155EEF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF155EEF)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bạn cùng phòng / Cư dân (${_residents.length})',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _residents.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, i) {
              final r = _residents[i];
              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF155EEF).withValues(alpha: 0.12),
                    child: Text(
                      r.fullName.isNotEmpty ? r.fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.fullName.isNotEmpty ? r.fullName : 'Cư dân',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textDark),
                        ),
                        Text(
                          'Dọn vào: ${DateFormat('dd/MM/yyyy').format(r.moveInDate)}',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: r.formId == 'chinh' ? const Color(0xFFECFDF3) : const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.formId == 'chinh' ? 'Người thuê chính' : 'Ở ghép',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: r.formId == 'chinh' ? const Color(0xFF027A48) : const Color(0xFF175CD3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 8. BIÊN BẢN TRẢ PHÒNG SUMMARY
  Widget _buildCheckoutSummaryCard(
    CheckoutRecordModel record,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textDark,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 8),
              Text(
                'Biên bản thanh lý & Hoàn cọc',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: 'Tiền cọc nhận lại',
                  value: '${_currencyFmt.format(record.refundAmount)} đ',
                  valueColor: const Color(0xFF027A48),
                  isBold: true,
                  textMuted: textMuted,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: 'Thời gian bàn giao',
                  value: DateFormat('dd/MM/yyyy HH:mm').format(record.checkoutTime),
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Chỉ số bàn giao: Điện: ${record.finalElectricityMeter} kWh • Nước: ${record.finalWaterMeter} m³',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
        ],
      ),
    );
  }

  // 9. MÔ TẢ PHÒNG
  Widget _buildDescriptionSection(bool isDark, Color cardColor, Color borderColor, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mô tả phòng & Nội quy',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 8),
          Text(
            _room!.description,
            style: TextStyle(fontSize: 13, color: textDark, height: 1.45),
          ),
        ],
      ),
    );
  }

  // THANH CỐ ĐỊNH Ở DƯỚI (BOTTOM ACTIONS)
  Widget _buildBottomActions(bool isDark, Color cardColor, Color borderColor) {
    if (isPast) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_room != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomDetailScreen(room: _room!)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bài đăng phòng trọ hiện không khả dụng.')),
                );
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Xem lại thông tin & Thuê lại phòng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    final b = widget.booking;
    final canReview = b != null && HostReviewPolicy.isReviewableBooking(b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleReportIssue,
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: const Text('Báo sự cố'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD92D20),
                    side: const BorderSide(color: Color(0xFFFDA29B)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleRoommateInvite,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Tìm ở ghép'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF155EEF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (canReview) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleHostReview,
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: const Text('Đánh giá chủ trọ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF027A48),
                  side: const BorderSide(color: Color(0xFF027A48)),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
