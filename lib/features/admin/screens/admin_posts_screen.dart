import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/admin/services/post_review_service.dart';
import '../../../data/models/room_model.dart';
import 'admin_post_review_detail_screen.dart';
import '../widgets/admin_branded_title.dart';

class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  String _filter = 'all'; // 'all', 'pending', 'active', 'rejected'
  final Map<String, Future<Map<String, dynamic>?>> _hostProfiles = {};

  Future<Map<String, dynamic>?> _hostProfile(String hostId) {
    return _hostProfiles.putIfAbsent(hostId, () async {
      if (hostId.isEmpty) return null;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(hostId)
          .get();
      return snapshot.data();
    });
  }

  // Định dạng tiền tệ an toàn trên Flutter Web
  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
  }

  double _num(dynamic v) => v is num ? v.toDouble() : 0.0;

  List<String> _postImages(Map<String, dynamic> data) {
    final raw = data['images'] ??
        data['roomImages'] ??
        data['anhPhong'] ??
        data['imageUrls'] ??
        data['photos'] ??
        data['photoUrls'] ??
        data['danhSachAnh'] ??
        data['hinhAnh'] ??
        data['anhList'] ??
        data['imageUrl'] ??
        data['photoUrl'] ??
        data['thumbnailUrl'] ??
        data['coverImage'] ??
        data['image'];

    String? imageUrl(dynamic item) {
      if (item is String) {
        var value = item.trim();
        if (value.startsWith('{') && value.endsWith('}')) {
          final match = RegExp(
            r'''(?:duongDan|url|image|imageUrl|downloadURL):\s*["']?([^,"'}]+)''',
          ).firstMatch(value);
          if (match != null) value = match.group(1)!.trim();
        }
        return value.isEmpty ? null : value;
      }
      if (item is Map) {
        final value = item['url'] ??
            item['duongDan'] ??
            item['image'] ??
            item['imageUrl'] ??
            item['downloadURL'] ??
            item['downloadUrl'] ??
            item['storageUrl'] ??
            item['duong_dan'];
        return value is String && value.trim().isNotEmpty ? value.trim() : null;
      }
      return null;
    }

    final items = raw is List ? raw : [raw];
    return items.map(imageUrl).whereType<String>().toSet().toList();
  }

  // Chuyển DocumentSnapshot (collection posts) thành RoomModel
  // Schema posts: rentalPrice, depositAmount, roomId, hostId, images, amenities...
  RoomModel _docToRoomModel(
    DocumentSnapshot doc, {
    Map<String, dynamic>? hostProfile,
  }) {
    {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final images = _postImages(data);

      final rentalPrice = _num(data['rentalPrice'] ?? data['price']);
      final deposit = _num(data['depositAmount'] ?? data['deposit']);

      return RoomModel(
        id: doc.id,
        roomCode: (data['roomCode'] ?? data['maPhong'] ?? data['roomId'] ?? '').toString(),
        title: (data['title'] ?? 'Bài đăng phòng trọ').toString(),
        description: (data['description'] ?? 'Chưa có mô tả.').toString(),
        price: rentalPrice,
        deposit: deposit > 0 ? deposit : rentalPrice,
        address: (data['address'] ?? 'Đang cập nhật địa chỉ').toString(),
        district: (data['district'] ?? '').toString(),
        city: (data['city'] ?? '').toString(),
        area: _num(data['area']),
        roomType: (data['roomType'] ?? 'Phòng trọ').toString(),
        amenities: List<String>.from(data['amenities'] ?? []),
        images: images,
        hostId: (data['hostId'] ??
                data['landlordId'] ??
                data['userId'] ??
                data['ownerId'] ??
                '')
            .toString(),
        hostName: (data['hostName'] ??
                data['landlordName'] ??
                hostProfile?['displayName'] ??
                hostProfile?['hoTen'] ??
                hostProfile?['fullName'] ??
                'Chủ trọ')
            .toString(),
        hostPhone: (data['hostPhone'] ??
                data['phone'] ??
                hostProfile?['phoneNumber'] ??
                hostProfile?['soDienThoai'] ??
                'Đang cập nhật')
            .toString(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }
  }

  Future<void> _openDetailPreview(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final hostId = (data['hostId'] ?? data['landlordId'] ?? data['userId'] ?? '')
        .toString();
    Map<String, dynamic>? hostProfile;
    try {
      hostProfile = await _hostProfile(hostId);
    } catch (_) {
      // Keep post-level contact fields if the user profile is unavailable.
    }
    if (!mounted) return;
    final posts = _docToRoomModel(doc, hostProfile: hostProfile);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPostReviewDetailScreen(
          room: posts,
          docId: doc.id,
          onApproved: () async {
            try {
              await PostReviewService.approve(doc.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF12B76A),
                    content: Text('Đã phê duyệt bài đăng thành công!'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi duyệt bài: $e')),
                );
              }
            }
          },
          onRejected: () async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFFD92D20),
                  content: Text('Đã từ chối bài đăng thành công!'),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // Duyệt bài đăng trực tiếp (cập nhật posts + thông báo chủ trọ + audit log)
  Future<void> _approvePost(String docId) async {
    try {
      await PostReviewService.approve(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF12B76A),
            content: Text('Đã duyệt bài đăng!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi duyệt bài: $e')),
        );
      }
    }
  }

  // Hạ bài / Gỡ bài (cập nhật posts + thông báo chủ trọ + audit log)
  Future<void> _rejectPost(String docId) async {
    try {
      await PostReviewService.reject(
        docId,
        reason: 'Admin đã gỡ bài đăng khỏi hệ thống',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD92D20),
            content: Text('Đã hạ bài đăng khỏi hệ thống!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gỡ bài: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: const AdminBrandedTitle(
          title: 'Quản lý bài đăng',
          subtitle: 'Duyệt & kiểm duyệt tin phòng trọ',
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thanh Lọc Trạng Thái (Tất cả, Chờ duyệt, Đã duyệt, Từ chối)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _buildFilterPill('Tất cả', 'all', const Color(0xFF398FC0)),
                const SizedBox(width: 8),
                _buildFilterPill('Chờ duyệt', 'pending', const Color(0xFF398FC0)),
                const SizedBox(width: 8),
                _buildFilterPill('Đã duyệt', 'active', const Color(0xFF398FC0)),
                const SizedBox(width: 8),
                _buildFilterPill('Từ chối', 'rejected', const Color(0xFF398FC0)),
              ],
            ),
          ),

          // 2. Danh Sách Bài Đăng Realtime từ Firebase
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                try {
                  return FirebaseFirestore.instance.collection('posts').snapshots();
                } catch (_) {
                  return const Stream<QuerySnapshot>.empty();
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                // Lọc danh sách theo Tab đang chọn (Đã chuẩn hóa status)
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  
                  // Lấy status và ép chữ thường
                  String status = data['status']?.toString().toLowerCase() ?? 'pending';

                  // Nếu status không thuộc nhóm Đã duyệt hoặc Từ chối -> Bắt buộc ép về Chờ duyệt
                  if (status != 'active' && status != 'approved' && status != 'danghien' &&
                      status != 'rejected' && status != 'tuchoi') {
                    status = 'pending';
                  }

                  if (_filter == 'all') return true;
                  if (_filter == 'pending') {
                    return status == 'pending' || status == 'choduyet';
                  }
                  if (_filter == 'active') {
                    return status == 'active' || status == 'approved' || status == 'danghien';
                  }
                  if (_filter == 'rejected') {
                    return status == 'rejected' || status == 'tuchoi';
                  }
                  return true;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thanh đếm số lượng kết quả
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Text(
                        'Tìm thấy ${filteredDocs.length} kết quả',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),

                    // Danh sách card
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.apartment_rounded, size: 48, color: Color(0xFFD0D5DD)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Không có bài đăng nào trong danh mục này',
                                    style: TextStyle(color: Color(0xFF667085)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: filteredDocs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                return _buildPostCard(doc);
                              },
                            ),
                    ),
                  ],
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFEAF4FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFD8EAF5),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF536B82),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final id = doc.id;
    final title = data['title'] ?? 'Bài đăng chưa có tên';
    final price = _num(data['rentalPrice'] ?? data['price']);
    final hostId = (data['hostId'] ?? data['landlordId'] ?? data['userId'] ?? '')
        .toString();
    final hostName = data['hostName'] ?? data['landlordName'];
    final phone = data['hostPhone'] ?? data['phone'] ?? '';
    final rejectReason = data['rejectReason'] as String?;

    // Lấy ảnh hiển thị
    final images = _postImages(data);
    final imageUrl = images.isEmpty ? null : images.first;

    // Chuẩn hóa status cho từng thẻ bài
    String status = data['status']?.toString().toLowerCase() ?? 'pending';
    
    // Nếu status không thuộc nhóm Đã duyệt hoặc Từ chối -> Bắt buộc ép về Chờ duyệt
    if (status != 'active' && status != 'approved' && status != 'danghien' &&
        status != 'rejected' && status != 'tuchoi') {
      status = 'pending'; 
    }

    final isPending = status == 'pending' || status == 'choduyet';
    final isActive = status == 'active' || status == 'approved' || status == 'danghien';
    final isRejected = status == 'rejected' || status == 'tuchoi';

    return InkWell(
      onTap: () => _openDetailPreview(doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending ? const Color(0xFFB9DDF1) : const Color(0xFFDCEAF3),
            width: isPending ? 1.4 : 1.0,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                  width: 84,
                  height: 84,
                  color: const Color(0xFFE6F1F8),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                                imageUrl.contains('firebasestorage.googleapis.com') ||
                                        imageUrl.contains('storage.googleapis.com')
                                    ? WebHtmlElementStrategy.prefer
                                    : WebHtmlElementStrategy.fallback,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.apartment_rounded, color: Color(0xFF98A2B3)),
                          )
                        : const Icon(Icons.apartment_rounded, color: Color(0xFF98A2B3)),
                  ),
                ),
                const SizedBox(width: 12),

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
                                'Đã duyệt',
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
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _hostProfile(hostId),
                            builder: (context, snapshot) {
                              final profile = snapshot.data;
                              final name = (hostName ??
                                      profile?['displayName'] ??
                                      profile?['hoTen'] ??
                                      profile?['fullName'] ??
                                      'Chủ trọ')
                                  .toString();
                              return Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF667085),
                                ),
                              );
                            },
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('• $phone', style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMoney(price),
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
                      onPressed: () => _approvePost(id),
                      style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF398FC0),
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
                      onPressed: () => _openDetailPreview(doc),
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
                      onPressed: () => _openDetailPreview(doc),
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
                      onPressed: () => _rejectPost(id),
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
