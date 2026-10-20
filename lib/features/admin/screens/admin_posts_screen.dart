import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
<<<<<<< HEAD
import 'package:home_share/features/admin/services/post_review_service.dart';
import '../../../data/models/room_model.dart';
import 'admin_post_review_detail_screen.dart';
import '../widgets/admin_branded_title.dart';
=======
import 'package:intl/intl.dart';
import '../../../data/models/room_model.dart';
import '../services/admin_service.dart';
import 'admin_post_review_detail_screen.dart';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  String _filter = 'all'; // 'all', 'pending', 'active', 'rejected'
<<<<<<< HEAD
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
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

    Navigator.push(
      context,
      MaterialPageRoute(
<<<<<<< HEAD
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
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          },
        ),
      ),
    );
  }

<<<<<<< HEAD
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
=======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
<<<<<<< HEAD
        titleSpacing: 16,
        toolbarHeight: 72,
        title: const AdminBrandedTitle(
          title: 'Quản lý bài đăng',
          subtitle: 'Duyệt & kiểm duyệt tin phòng trọ',
        ),
        centerTitle: false,
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
<<<<<<< HEAD
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
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              ],
            ),
          ),

<<<<<<< HEAD
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
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFEAF4FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFD8EAF5),
            ),
=======
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(20),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
<<<<<<< HEAD
              color: isSelected ? Colors.white : const Color(0xFF536B82),
=======
              color: isSelected ? Colors.white : const Color(0xFF475467),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
            ),
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
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
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
<<<<<<< HEAD
            color: isPending ? const Color(0xFFB9DDF1) : const Color(0xFFDCEAF3),
            width: isPending ? 1.4 : 1.0,
=======
            color: isPending ? const Color(0xFFD1E0FF) : const Color(0xFFEAECF0),
            width: isPending ? 1.5 : 1.0,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                  width: 84,
                  height: 84,
                  color: const Color(0xFFE6F1F8),
=======
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: const Color(0xFFEAECF0),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
<<<<<<< HEAD
                            webHtmlElementStrategy:
                                imageUrl.contains('firebasestorage.googleapis.com') ||
                                        imageUrl.contains('storage.googleapis.com')
                                    ? WebHtmlElementStrategy.prefer
                                    : WebHtmlElementStrategy.fallback,
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.apartment_rounded, color: Color(0xFF98A2B3)),
                          )
                        : const Icon(Icons.apartment_rounded, color: Color(0xFF98A2B3)),
                  ),
                ),
                const SizedBox(width: 12),

<<<<<<< HEAD
=======
                // Info
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                                'Đã duyệt',
=======
                                '• Đã xuất bản',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
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
=======
                          Text(
                            hostName,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('• $phone', style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
                          ],
<<<<<<< HEAD
=======
                          if (views != null) ...[
                            const SizedBox(width: 6),
                            Text('• $views', style: const TextStyle(fontSize: 11, color: Color(0xFF155EEF), fontWeight: FontWeight.w600)),
                          ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
<<<<<<< HEAD
                        _formatMoney(price),
=======
                        '${currencyFormatter.format(price / 1000000)} tr/tháng',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                      onPressed: () => _approvePost(id),
                      style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF398FC0),
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                      onPressed: () => _openDetailPreview(doc),
=======
                      onPressed: () => _openDetailPreview(item),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                      onPressed: () => _openDetailPreview(doc),
=======
                      onPressed: () => _openDetailPreview(item),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                      onPressed: () => _rejectPost(id),
=======
                      onPressed: () {
                        _updateLocalStatus(id, 'rejected');
                        ref.read(adminServiceProvider).lockRoomPost(id);
                      },
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
}
=======
}
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
