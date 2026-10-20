<<<<<<< HEAD
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../data/models/room_model.dart';
import '../widgets/admin_page_backdrop.dart';
import '../widgets/admin_branded_title.dart';
import '../services/post_review_service.dart';

class AdminPostReviewDetailScreen extends StatefulWidget {
  final RoomModel room;
  final String? docId;
  final String postPurpose;
=======
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/room_model.dart';

class AdminPostReviewDetailScreen extends StatefulWidget {
  final RoomModel room;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  final VoidCallback? onApproved;
  final VoidCallback? onRejected;

  const AdminPostReviewDetailScreen({
    super.key,
    required this.room,
<<<<<<< HEAD
    this.docId,
    this.postPurpose = '',
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    this.onApproved,
    this.onRejected,
  });

  @override
<<<<<<< HEAD
  State<AdminPostReviewDetailScreen> createState() =>
      _AdminPostReviewDetailScreenState();
}

class _AdminPostReviewDetailScreenState
    extends State<AdminPostReviewDetailScreen> {
  int _currentImageIndex = 0;

  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
  }

  Widget _buildRoomImage(String url) {
    const fallback = Center(
      child: Icon(Icons.apartment_rounded, size: 64, color: Color(0xFF98A2B3)),
    );
    if (url.startsWith('data:image/') && url.contains('base64,')) {
      try {
        final bytes = base64Decode(url.substring(url.indexOf('base64,') + 7));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    final isFirebaseStorageUrl =
        url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com');
    return Image.network(
      url,
      fit: BoxFit.cover,
      // Firebase Storage URLs are cross-origin in Flutter Web. Prefer an HTML
      // image element so CORS does not prevent the admin preview from loading.
      webHtmlElementStrategy: isFirebaseStorageUrl
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Không tải được ảnh chi tiết bài đăng ($url): $error');
        return fallback;
      },
    );
  }
=======
  State<AdminPostReviewDetailScreen> createState() => _AdminPostReviewDetailScreenState();
}

class _AdminPostReviewDetailScreenState extends State<AdminPostReviewDetailScreen> {
  int _currentImageIndex = 0;
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

  void _showRejectBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RejectBottomSheet(
        room: widget.room,
<<<<<<< HEAD
        docId: widget.docId ?? widget.room.id,
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        onConfirmed: () {
          Navigator.pop(ctx);
          if (widget.onRejected != null) {
            widget.onRejected!();
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
<<<<<<< HEAD
    final images = room.images;
=======
    final images = room.images.isNotEmpty
        ? room.images
        : [
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80',
          ];
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
<<<<<<< HEAD
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF101828),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const AdminBrandedTitle(title: 'Xem bài đăng'),
        centerTitle: false,
      ),
      body: AdminPageBackdrop(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Banner slider ảnh phòng
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                    height: 250,
                    child: images.isEmpty
                        ? Container(
                            color: const Color(0xFFDCEAF5),
                            child: const Center(
                              child: Icon(
                                Icons.apartment_rounded,
                                size: 64,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          )
                        : PageView.builder(
                            itemCount: images.length,
                            onPageChanged: (i) =>
                                setState(() => _currentImageIndex = i),
                            itemBuilder: (context, index) {
                              return Container(
                                color: const Color(0xFFDCEAF5),
                                child: _buildRoomImage(images[index]),
                              );
                            },
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${room.id.substring(0, room.id.length.clamp(0, 6)).toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        final isCurrent = i == _currentImageIndex;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isCurrent ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              // 2. Chi tiết phòng
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatMoney(room.price),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF398FC0),
                          ),
                        ),
                        const Text(
                          '/tháng',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Cọc ${_formatMoney(room.deposit)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF027A48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF667085),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room.address,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        _buildPropChip(
                          Icons.square_foot_rounded,
                          '${room.area.toInt()} m²',
                        ),
                        const SizedBox(width: 8),
                        _buildPropChip(Icons.apartment_rounded, room.roomType),
                      ],
                    ),
                    if (widget.postPurpose.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6FC),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              size: 16,
                              color: Color(0xFF398FC0),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                widget.postPurpose,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A5F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (room.amenities.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: room.amenities.map((amenity) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              amenity,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Profile Chủ Trọ
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCEAF5)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFCDEBFA),
                            child: Text(
                              room.hostName.isNotEmpty
                                  ? room.hostName[0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF398FC0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.hostName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SĐT: ${room.hostPhone}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mô tả chi tiết
                    const Text(
                      'Mô tả phòng trọ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      room.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475467),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
=======
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF101828)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Xem Trực Tiếp Bài Đăng',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF101828),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF344054)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image carousel banner with dot indicators
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemBuilder: (context, index) {
                      return Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFEAECF0),
                          child: const Center(
                            child: Icon(Icons.apartment_rounded, size: 64, color: Color(0xFF98A2B3)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '#NC1204',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (i) {
                      final isCurrent = i == _currentImageIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrent ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),

            // 2. Room Metrics Counter Bar (1.240 xem, 83 lưu, 10 cuộc gọi, 10/100 Điểm)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _MetricItem(icon: Icons.visibility_outlined, label: '1.240 Xem'),
                  _MetricItem(icon: Icons.favorite_border_rounded, label: '83 Lưu'),
                  _MetricItem(icon: Icons.phone_outlined, label: '10 Cuộc gọi'),
                  _MetricItem(icon: Icons.verified_outlined, label: '10/100 Điểm', isHighlight: true),
                ],
              ),
            ),

            // 3. Main Info Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${currencyFormatter.format(room.price)} đ',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF155EEF),
                        ),
                      ),
                      const Text(
                        '/tháng',
                        style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Cọc 1 tháng',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF027A48)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.title.isNotEmpty ? room.title : 'Studio Full NT Ban Công – Cầu Giấy',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF667085)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.address.isNotEmpty ? room.address : 'Ngõ 155 Cầu Giấy, P. Quan Hoa, Q. Cầu Giấy, Hà Nội',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Room property chips: 35 m2, 1PN, 1WC, Đang mở
                  Row(
                    children: [
                      _buildPropChip(Icons.square_foot_rounded, '${room.area.toInt()} m²'),
                      const SizedBox(width: 8),
                      _buildPropChip(Icons.bed_outlined, '1 PN'),
                      const SizedBox(width: 8),
                      _buildPropChip(Icons.bathtub_outlined, '1 WC'),
                      const SizedBox(width: 8),
                      _buildPropChip(Icons.check_circle_outline, 'Đang mở'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Host Profile Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFD1E0FF),
                          child: Text(
                            room.hostName.isNotEmpty ? room.hostName[0].toUpperCase() : 'L',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.hostName.isNotEmpty ? room.hostName : 'Lê Hoài Nam',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Đã xác thực CCCD • Đăng 03 phòng',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Trang Chủ Trọ',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amenities list
                  const Text(
                    'Tiện ích phòng trọ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildAmenityChip('Cửa sổ', Icons.window_outlined),
                      _buildAmenityChip('Nóng lạnh', Icons.water_drop_outlined),
                      _buildAmenityChip('Máy giặt', Icons.local_laundry_service_outlined),
                      _buildAmenityChip('Khóa vân tay', Icons.fingerprint_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
<<<<<<< HEAD
          border: const Border(top: BorderSide(color: Color(0xFFDCEAF5))),
=======
          border: const Border(top: BorderSide(color: Color(0xFFEAECF0))),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
<<<<<<< HEAD
              Expanded(
                child: OutlinedButton(
                  onPressed: _showRejectBottomSheet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFDA29B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Từ chối / Hạ bài',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
=======
              OutlinedButton(
                onPressed: _showRejectBottomSheet,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  side: const BorderSide(color: Color(0xFFFDA29B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Hạ bài đăng',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD92D20)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang kích hoạt gói VIP cho bài đăng...')),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Ghim VIP', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  onPressed: () {
                    if (widget.onApproved != null) {
                      widget.onApproved!();
                    }
                    Navigator.pop(context);
                  },
<<<<<<< HEAD
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12B76A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Phê duyệt bài',
                    style: TextStyle(fontWeight: FontWeight.bold),
=======
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Gọi Chủ Trọ', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF155EEF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
<<<<<<< HEAD
        color: const Color(0xFFEAF4FA),
=======
        color: const Color(0xFFF2F4F7),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475467)),
          const SizedBox(width: 4),
<<<<<<< HEAD
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
=======
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF344054))),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF155EEF)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF344054))),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        ],
      ),
    );
  }
}

<<<<<<< HEAD
class _RejectBottomSheet extends StatefulWidget {
  final RoomModel room;
  final String docId;
  final VoidCallback onConfirmed;

  const _RejectBottomSheet({
    required this.room,
    required this.docId,
    required this.onConfirmed,
  });
=======
class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlight;

  const _MetricItem({required this.icon, required this.label, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: isHighlight ? const Color(0xFF155EEF) : const Color(0xFF667085)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? const Color(0xFF155EEF) : const Color(0xFF475467),
          ),
        ),
      ],
    );
  }
}

class _RejectBottomSheet extends StatefulWidget {
  final RoomModel room;
  final VoidCallback onConfirmed;

  const _RejectBottomSheet({required this.room, required this.onConfirmed});
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

  @override
  State<_RejectBottomSheet> createState() => _RejectBottomSheetState();
}

class _RejectBottomSheetState extends State<_RejectBottomSheet> {
<<<<<<< HEAD
  static const _violationOptions = [
    'Hình ảnh bị mờ / Chứa Logo của sàn khác',
    'Giá thuê bất thường / Khác với giá mô tả',
    'Sai địa chỉ / Tọa độ vị trí phòng trọ',
    'Nội dung chứa từ khóa cấm / Quảng cáo rác',
  ];
  final TextEditingController _noteCtrl = TextEditingController();
  final Set<String> _selectedViolations = {};
  String _penalty = 'reject_only';
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF475467),
      ),
    ),
  );

  Widget _violationTile(String label) {
    final selected = _selectedViolations.contains(label);
    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selectedViolations.remove(label);
        } else {
          _selectedViolations.add(label);
        }
      }),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF6FC) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF89CFF0) : const Color(0xFFDCEAF5),
          ),
          borderRadius: BorderRadius.circular(9),
=======
  final Set<int> _selectedErrors = {0, 1};
  final TextEditingController _noteCtrl = TextEditingController(
    text: 'Ảnh số 1 và số 3 có chứa Watermark của ứng dụng khác.\nMức giá 5.5 triệu nhưng mô tả ghi 5.1 triệu.\n➔ Vui lòng thay đổi ảnh và thống nhất lại giá thuê.',
  );
  int _penaltyType = 0; // 0: Cảnh cáo trừ điểm, 1: Khóa 3 ngày

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD92D20), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TỪ CHỐI & BÁO LỖI BÀI ĐĂNG',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                          ),
                        ),
                        Text(
                          'Mã bài: #${widget.room.id.substring(0, widget.room.id.length.clamp(0, 6))} • Chủ trọ: ${widget.room.hostName}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF667085)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              '1. CHỌN CÁC LỖI VI PHẠM (CÓ THỂ CHỌN NHIỀU)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475467)),
            ),
            const SizedBox(height: 8),

            _buildCheckboxOption(0, 'Hình ảnh mờ quyét / Chứa Logo của sàn khác'),
            _buildCheckboxOption(1, 'Giá thuê bất thường / Khác với giá mô tả'),
            _buildCheckboxOption(2, 'Sai địa chỉ / Tọa độ vị trí phòng trọ'),
            _buildCheckboxOption(3, 'Nội dung chứa từ khóa cấm / Quảng cáo rác'),

            const SizedBox(height: 14),
            const Text(
              '2. LỜI NHẮN CHI TIẾT GỬI CHỦ TRỌ (GỢI Ý SỬA BÀI)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475467)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              '3. HÌNH PHẠT BỔ SUNG (HỆ THỐNG TỰ ĐỘNG GHI LỖI)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475467)),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _penaltyType = 0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _penaltyType == 0 ? const Color(0xFFFEF0C7) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _penaltyType == 0 ? const Color(0xFFF79009) : const Color(0xFFEAECF0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _penaltyType == 0 ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: _penaltyType == 0 ? const Color(0xFFB54708) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Cảnh cáo trừ điểm\n(Trừ 5 điểm uy tín & thông báo)',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _penaltyType = 1),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _penaltyType == 1 ? const Color(0xFFFEE4E2) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _penaltyType == 1 ? const Color(0xFFD92D20) : const Color(0xFFEAECF0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _penaltyType == 1 ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 16,
                            color: _penaltyType == 1 ? const Color(0xFFD92D20) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Khóa đăng tin 3 ngày\n(Tạm ngưng quyền đăng bài)',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                widget.onConfirmed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'XÁC NHẬN TỪ CHỐI & GỬI THÔNG BÁO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy bỏ', style: TextStyle(color: Color(0xFF667085))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(int index, String label) {
    final isSelected = _selectedErrors.contains(index);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedErrors.remove(index);
          } else {
            _selectedErrors.add(index);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF3F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFDA29B) : const Color(0xFFEAECF0),
          ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        ),
        child: Row(
          children: [
            Icon(
<<<<<<< HEAD
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank,
              size: 19,
              color: selected
                  ? const Color(0xFF398FC0)
                  : const Color(0xFFB6C7D5),
=======
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: isSelected ? const Color(0xFFD92D20) : const Color(0xFF98A2B3),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
<<<<<<< HEAD
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF287AA8)
                      : const Color(0xFF475467),
=======
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFD92D20) : const Color(0xFF344054),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD

  Widget _penaltyOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _penalty == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _penalty = value),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF6FC) : Colors.white,
            border: Border.all(
              color: selected
                  ? const Color(0xFF398FC0)
                  : const Color(0xFFDCEAF5),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selected
                    ? const Color(0xFF398FC0)
                    : const Color(0xFFB6C7D5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6FC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFF398FC0),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TỪ CHỐI & BÁO LỖI BÀI ĐĂNG',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF101828),
                            ),
                          ),
                          Text(
                            'Mã bài: #${widget.docId.substring(0, widget.docId.length.clamp(0, 6)).toUpperCase()} • Chủ trọ: ${widget.room.hostName}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF667085),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Divider(height: 1),
              const SizedBox(height: 12),
              _sectionLabel('1. CHỌN CÁC LỖI VI PHẠM (CÓ THỂ CHỌN NHIỀU)'),
              ..._violationOptions.map(_violationTile),
              const SizedBox(height: 8),
              _sectionLabel('2. LỜI NHẮN CHI TIẾT GỬI CHỦ TRỌ (GỢI Ý SỬA BÀI)'),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText:
                      'Nêu rõ nội dung cần chỉnh sửa để chủ trọ biết cách khắc phục.',
                  counterStyle: const TextStyle(fontSize: 9),
                  contentPadding: const EdgeInsets.all(10),
                  filled: true,
                  fillColor: const Color(0xFFF4F9FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _sectionLabel('3. HÌNH PHẠT BỔ SUNG'),
              Row(
                children: [
                  _penaltyOption(
                    value: 'reject_only',
                    title: 'Chỉ từ chối bài',
                    subtitle: 'Không ghi lỗi',
                  ),
                  const SizedBox(width: 8),
                  _penaltyOption(
                    value: 'warning',
                    title: 'Cảnh cáo (+1 lỗi)',
                    subtitle: 'Trừ 1 điểm uy tín',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _submitting || _selectedViolations.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _submitting = true);
                        try {
                          final note = _noteCtrl.text.trim();
                          final reason = [
                            'Lỗi vi phạm: ${_selectedViolations.join(', ')}',
                            if (note.isNotEmpty) 'Góp ý: $note',
                            if (_penalty == 'warning')
                              'Hình thức xử lý: Cảnh cáo, trừ 1 điểm uy tín chủ trọ.',
                          ].join('\n');
                          // Cập nhật posts + gửi thông báo cho chủ trọ + audit log
                          await PostReviewService.reject(
                            widget.docId,
                            reason: reason,
                            penaltyType: _penalty,
                          );
                          widget.onConfirmed();
                        } catch (e) {
                          if (mounted) {
                            setState(() => _submitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Lỗi cập nhật: $e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF398FC0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _submitting
                      ? 'ĐANG GỬI...'
                      : '● XÁC NHẬN TỪ CHỐI & GỬI THÔNG BÁO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  backgroundColor: const Color(0xFFF1F6FA),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Hủy bỏ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
}
