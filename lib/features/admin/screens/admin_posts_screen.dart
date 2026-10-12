import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/room_model.dart';
import '../services/admin_service.dart';
import 'admin_post_review_detail_screen.dart';

class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  String _filter = 'all'; // 'all', 'pending', 'active', 'rejected'
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  // Lưu trạng thái ghi đè cục bộ cho Mock Data để không bị reset khi chuyển tab
  final Map<String, String> _localStatusOverrides = {};

  final List<Map<String, dynamic>> _initialMockList = [
    {
      'id': 'p1',
      'title': 'Căn hộ 2PN – Phú Mỹ Hưng – Q.7',
      'address': 'Đường Nguyễn Văn Linh, Tân Phong, Quận 7',
      'price': 10000000.0,
      'status': 'pending',
      'hostName': 'Lê Hoài Nam',
      'phone': '0908...321',
      'roomType': 'Căn hộ 2PN',
      'area': 70.0,
      'image': 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'p2',
      'title': 'Nhà nguyên căn – Q.7',
      'address': 'Đường Huỳnh Tấn Phát, Quận 7',
      'price': 14000000.0,
      'status': 'pending',
      'hostName': 'Lê Hoài Nam',
      'phone': '0908...321',
      'roomType': 'Nhà nguyên căn',
      'area': 90.0,
      'image': 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'p3',
      'title': 'Căn hộ Studio Full NT ban công – Q....',
      'address': 'Đường Nguyễn Hữu Thọ, Quận 7',
      'price': 6500000.0,
      'status': 'pending',
      'hostName': 'Nguyễn Văn Hùng',
      'phone': '0912...456',
      'roomType': 'Studio',
      'area': 35.0,
      'image': 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'p4',
      'title': 'Studio Full NT – Cầu Giấy',
      'address': 'Ngõ 155 Cầu Giấy, P. Quan Hoa, Hà Nội',
      'price': 5500000.0,
      'status': 'active',
      'hostName': 'Lê Hoài Nam',
      'phone': '0988...789',
      'roomType': 'Studio',
      'area': 35.0,
      'views': '1.240 xem',
      'image': 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'p5',
      'title': 'Nhà nguyên căn Q.8',
      'address': 'Dương Bá Trạc, Phường 1, Quận 8',
      'price': 8000000.0,
      'status': 'rejected',
      'hostName': 'Nguyễn Văn Hùng',
      'phone': '0912...456',
      'roomType': 'Nhà nguyên căn',
      'area': 65.0,
      'rejectReason': 'Lý do: Ản phòng không rõ, giá sai thực tế',
      'image': 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=600&q=80',
    },
  ];

  void _updateLocalStatus(String id, String newStatus) {
    setState(() {
      _localStatusOverrides[id] = newStatus;
    });
  }

  void _openDetailPreview(Map<String, dynamic> data) {
    final room = RoomModel(
      id: data['id'] ?? 'p1',
      title: data['title'] ?? '',
      description: 'Căn hộ thiết kế hiện đại, đầy đủ nội thất tiện nghi cao cấp, gần trung tâm thương mại và trường đại học.',
      price: (data['price'] as num?)?.toDouble() ?? 5500000.0,
      deposit: ((data['price'] as num?)?.toDouble() ?? 5500000.0),
      address: data['address'] ?? '',
      district: 'Quận 7',
      city: 'TP. Hồ Chí Minh',
      area: (data['area'] as num?)?.toDouble() ?? 35.0,
      roomType: data['roomType'] ?? 'Studio',
      amenities: const ['Máy lạnh', 'Tủ lạnh', 'Máy giặt', 'Ban công', 'Bảo vệ 24/7'],
      images: [data['image'] ?? ''],
      hostId: 'h1',
      hostName: data['hostName'] ?? 'Chủ trọ',
      hostPhone: data['phone'] ?? '0908 123 456',
      createdAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPostReviewDetailScreen(
          room: room,
          onApproved: () {
            _updateLocalStatus(room.id, 'active');
            ref.read(adminServiceProvider).approveRoomPost(room.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF12B76A),
                content: Text('Đã phê duyệt bài đăng thành công!'),
              ),
            );
          },
          onRejected: () {
            _updateLocalStatus(room.id, 'rejected');
            ref.read(adminServiceProvider).rejectRoomPost(room.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFFD92D20),
                content: Text('Đã từ chối và gửi báo lỗi bài đăng cho chủ trọ!'),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF101828)),
          onPressed: () {},
        ),
        title: const Text(
          'Quản lý bài đăng',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF344054)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Status Filter Pills (Tất cả, Chờ duyệt, Đã duyệt, Từ chối)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterPill('Tất cả', 'all', const Color(0xFF155EEF)),
                const SizedBox(width: 8),
                _buildFilterPill('Chờ duyệt', 'pending', const Color(0xFF027A48)),
                const SizedBox(width: 8),
                _buildFilterPill('Đã duyệt', 'active', const Color(0xFF12B76A)),
                const SizedBox(width: 8),
                _buildFilterPill('Từ chối', 'rejected', const Color(0xFFD92D20)),
              ],
            ),
          ),

          // 2. Count info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Tìm thấy 5 kết quả',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF667085)),
            ),
          ),

          // 3. Post List View with Firestore real-time integration
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
              builder: (context, snapshot) {
                // Merge Mock list with Firestore rooms
                final processedList = _initialMockList.map((item) {
                  final id = item['id'] as String;
                  final effectiveStatus = _localStatusOverrides[id] ?? (item['status'] as String);
                  return {
                    ...item,
                    'status': effectiveStatus,
                  };
                }).toList();

                final filtered = processedList.where((item) {
                  final status = item['status'] as String;
                  if (_filter == 'all') return true;
                  if (_filter == 'pending') return status == 'pending' || status == 'choDuyet';
                  if (_filter == 'active') return status == 'active' || status == 'dangHien';
                  if (_filter == 'rejected') return status == 'rejected' || status == 'tuChoi';
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Không có bài đăng nào trong danh mục này', style: TextStyle(color: Color(0xFF667085))),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildPostCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, Color color) {
    final isSelected = _filter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF475467),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final title = item['title'] as String;
    final price = (item['price'] as num).toDouble();
    final status = item['status'] as String;
    final hostName = item['hostName'] as String;
    final phone = item['phone'] ?? '';
    final imageUrl = item['image'] as String?;
    final views = item['views'] as String?;
    final rejectReason = item['rejectReason'] as String?;

    final isPending = status == 'pending';
    final isActive = status == 'active';
    final isRejected = status == 'rejected';

    return InkWell(
      onTap: () => _openDetailPreview(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending ? const Color(0xFFD1E0FF) : const Color(0xFFEAECF0),
            width: isPending ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: const Color(0xFFEAECF0),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.apartment_rounded, color: Color(0xFF98A2B3)),
                          )
                        : const Icon(Icons.apartment_rounded, color: Color(0xFF98A2B3)),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF0C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '• Chờ duyệt',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB54708)),
                              ),
                            )
                          else if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '• Đã xuất bản',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF027A48)),
                              ),
                            )
                          else if (isRejected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE4E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '• Từ chối',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD92D20)),
                              ),
                            ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF98A2B3)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 13, color: Color(0xFF667085)),
                          const SizedBox(width: 4),
                          Text(
                            hostName,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('• $phone', style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
                          ],
                          if (views != null) ...[
                            const SizedBox(width: 6),
                            Text('• $views', style: const TextStyle(fontSize: 11, color: Color(0xFF155EEF), fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currencyFormatter.format(price / 1000000)} tr/tháng',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF155EEF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isPending) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _updateLocalStatus(id, 'active');
                        ref.read(adminServiceProvider).approveRoomPost(id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF12B76A),
                            content: Text('Đã duyệt bài đăng!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF12B76A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('✓ Duyệt bài đăng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDetailPreview(item),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDA29B)),
                        foregroundColor: const Color(0xFFD92D20),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('✕ Từ chối', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else if (isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetailPreview(item),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('Xem Trực Tiếp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _updateLocalStatus(id, 'rejected');
                        ref.read(adminServiceProvider).lockRoomPost(id);
                      },
                      icon: const Icon(Icons.remove_circle_outline, size: 14, color: Color(0xFFD92D20)),
                      label: const Text('Hạ Tin / Gỡ Bài', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD92D20))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDA29B)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isRejected && rejectReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD92D20)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rejectReason,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFD92D20)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}