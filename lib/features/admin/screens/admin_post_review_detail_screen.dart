import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/room_model.dart';

class AdminPostReviewDetailScreen extends StatefulWidget {
  final RoomModel room;
  final VoidCallback? onApproved;
  final VoidCallback? onRejected;

  const AdminPostReviewDetailScreen({
    super.key,
    required this.room,
    this.onApproved,
    this.onRejected,
  });

  @override
  State<AdminPostReviewDetailScreen> createState() => _AdminPostReviewDetailScreenState();
}

class _AdminPostReviewDetailScreenState extends State<AdminPostReviewDetailScreen> {
  int _currentImageIndex = 0;
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  void _showRejectBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RejectBottomSheet(
        room: widget.room,
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
    final images = room.images.isNotEmpty
        ? room.images
        : [
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80',
          ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
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
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEAECF0))),
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
                  onPressed: () {
                    if (widget.onApproved != null) {
                      widget.onApproved!();
                    }
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Gọi Chủ Trọ', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF155EEF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475467)),
          const SizedBox(width: 4),
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
        ],
      ),
    );
  }
}

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

  @override
  State<_RejectBottomSheet> createState() => _RejectBottomSheetState();
}

class _RejectBottomSheetState extends State<_RejectBottomSheet> {
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
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: isSelected ? const Color(0xFFD92D20) : const Color(0xFF98A2B3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFD92D20) : const Color(0xFF344054),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
