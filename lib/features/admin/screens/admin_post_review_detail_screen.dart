import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/models/room_model.dart';

class AdminPostReviewDetailScreen extends StatefulWidget {
  final RoomModel room;
  final String? docId;
  final VoidCallback? onApproved;
  final VoidCallback? onRejected;

  const AdminPostReviewDetailScreen({
    super.key,
    required this.room,
    this.docId,
    this.onApproved,
    this.onRejected,
  });

  @override
  State<AdminPostReviewDetailScreen> createState() => _AdminPostReviewDetailScreenState();
}

class _AdminPostReviewDetailScreenState extends State<AdminPostReviewDetailScreen> {
  int _currentImageIndex = 0;

  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
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
    final images = room.images.isNotEmpty
        ? room.images
        : [
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
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
          'XEM TRỰC TIẾP BÀI ĐĂNG',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Banner slider ảnh phòng
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
                    child: Text(
                      '#${room.id.substring(0, room.id.length.clamp(0, 6)).toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                        child: Text(
                          'Cọc ${_formatMoney(room.deposit)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF027A48)),
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
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF667085)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.address,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _buildPropChip(Icons.square_foot_rounded, '${room.area.toInt()} m²'),
                      const SizedBox(width: 8),
                      _buildPropChip(Icons.apartment_rounded, room.roomType),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Profile Chủ Trọ
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
                            room.hostName.isNotEmpty ? room.hostName[0].toUpperCase() : 'C',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
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
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
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
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
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
              Expanded(
                child: OutlinedButton(
                  onPressed: _showRejectBottomSheet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFDA29B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Từ chối / Hạ bài',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD92D20)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Phê duyệt bài', style: TextStyle(fontWeight: FontWeight.bold)),
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
  final TextEditingController _noteCtrl = TextEditingController(
    text: 'Hình ảnh bài đăng chưa rõ ràng hoặc thông tin giá thuê chưa khớp.',
  );

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
                          'TỪ CHỐI BÀI ĐĂNG',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                          ),
                        ),
                        Text(
                          'Chủ trọ: ${widget.room.hostName}',
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
              'LỜI NHẮN CHI TIẾT GỬI CHỦ TRỌ',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475467)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  // Cập nhật Firestore
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.docId)
                      .update({
                    'status': 'rejected',
                    'rejectReason': _noteCtrl.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  widget.onConfirmed();
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Lỗi cập nhật: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'XÁC NHẬN TỪ CHỐI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}