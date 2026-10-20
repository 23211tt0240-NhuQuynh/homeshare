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
  final VoidCallback? onApproved;
  final VoidCallback? onRejected;

  const AdminPostReviewDetailScreen({
    super.key,
    required this.room,
    this.docId,
    this.postPurpose = '',
    this.onApproved,
    this.onRejected,
  });

  @override
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

  void _showRejectBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RejectBottomSheet(
        room: widget.room,
        docId: widget.docId ?? widget.room.id,
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
    final images = room.images;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
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
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFDCEAF5))),
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
                  onPressed: () {
                    if (widget.onApproved != null) {
                      widget.onApproved!();
                    }
                    Navigator.pop(context);
                  },
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
        color: const Color(0xFFEAF4FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475467)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectBottomSheet extends StatefulWidget {
  final RoomModel room;
  final String docId;
  final VoidCallback onConfirmed;

  const _RejectBottomSheet({
    required this.room,
    required this.docId,
    required this.onConfirmed,
  });

  @override
  State<_RejectBottomSheet> createState() => _RejectBottomSheetState();
}

class _RejectBottomSheetState extends State<_RejectBottomSheet> {
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
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank,
              size: 19,
              color: selected
                  ? const Color(0xFF398FC0)
                  : const Color(0xFFB6C7D5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF287AA8)
                      : const Color(0xFF475467),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}
