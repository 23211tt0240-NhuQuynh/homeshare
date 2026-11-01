import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/admin/services/post_review_service.dart';
import '../../../data/models/room_model.dart';
import 'admin_post_review_detail_screen.dart';
import '../widgets/admin_branded_title.dart';
import '../widgets/admin_theme_toggle.dart';
import '../theme/admin_colors.dart';

class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  String _filter = 'all'; // 'all', 'pending', 'active', 'rejected'
  DateTimeRange? _dateRange;
  final Map<String, Future<Map<String, dynamic>?>> _hostProfiles = {};

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AdminColors.accent,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

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
    final raw =
        data['images'] ??
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
        final value =
            item['url'] ??
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
        roomCode: (data['roomCode'] ?? data['maPhong'] ?? data['roomId'] ?? '')
            .toString(),
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
        hostId:
            (data['hostId'] ??
                    data['landlordId'] ??
                    data['userId'] ??
                    data['ownerId'] ??
                    '')
                .toString(),
        hostName:
            (data['hostName'] ??
                    data['landlordName'] ??
                    hostProfile?['displayName'] ??
                    hostProfile?['hoTen'] ??
                    hostProfile?['fullName'] ??
                    'Chủ trọ')
                .toString(),
        hostPhone:
            (data['hostPhone'] ??
                    data['phone'] ??
                    hostProfile?['phoneNumber'] ??
                    hostProfile?['soDienThoai'] ??
                    'Đang cập nhật')
                .toString(),
        status: (data['status'] ?? data['trangThai'] ?? 'pending').toString(),
        isAvailable: data['isAvailable'] == true ||
            ((data['status'] ?? data['trangThai']) != 'rejected' &&
             (data['status'] ?? data['trangThai']) != 'hidden' &&
             (data['status'] ?? data['trangThai']) != 'tuchoi' &&
             (data['status'] ?? data['trangThai']) != 'daan'),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }
  }

  Future<void> _openDetailPreview(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final hostId =
        (data['hostId'] ?? data['landlordId'] ?? data['userId'] ?? '')
            .toString();
    Map<String, dynamic>? hostProfile;
    try {
      hostProfile = await _hostProfile(hostId);
    } catch (_) {
      // Keep post-level contact fields if the user profile is unavailable.
    }
    if (!mounted) return;
    final posts = _docToRoomModel(doc, hostProfile: hostProfile);
    final status =
        (data['status'] ?? data['trangThai'] ?? '').toString().toLowerCase();
    final isRejected = status == 'rejected' || status == 'tuchoi';
    final canReviewAgain = !isRejected || data['hostResubmittedAt'] != null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPostReviewDetailScreen(
          room: posts,
          docId: doc.id,
          canApprove: canReviewAgain,
          onApproved: () async {
            try {
              await PostReviewService.approve(doc.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AdminColors.success,
                    content: Text('Đã phê duyệt bài đăng thành công!'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không thể duyệt bài. Vui lòng thử lại.'),
                  ),
                );
              }
            }
          },
          onRejected: () async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AdminColors.danger,
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
          SnackBar(
            backgroundColor: AdminColors.success,
            content: Text('Đã duyệt bài đăng! Dashboard đã cập nhật sang trạng thái Đã duyệt.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể duyệt bài. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  // Hạ bài / Ẩn bài (cập nhật posts + thông báo chủ trọ + audit log)
  Future<void> _rejectPost(String docId) async {
    try {
      await PostReviewService.reject(
        docId,
        reason: 'Admin đã ẩn bài đăng khỏi hệ thống',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminColors.danger,
            content: Text('Đã ẩn bài đăng! Dashboard đã cập nhật sang trạng thái Đã ẩn.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể ẩn bài. Vui lòng thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.paper,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: const AdminBrandedTitle(
          title: 'Quản lý bài đăng',
          subtitle: 'Duyệt & kiểm duyệt tin phòng trọ',
        ),
        centerTitle: false,
        actions: const [AdminThemeToggle()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thanh Lọc Trạng Thái (Tất cả, Chờ duyệt, Đã duyệt, Từ chối)
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _buildFilterPill('Tất cả', 'all', AdminColors.accent),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'Chờ duyệt',
                      'pending',
                      AdminColors.accent,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill('Đã duyệt', 'active', AdminColors.accent),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      'Từ chối',
                      'rejected',
                      AdminColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.mutedStrong,
                          side: BorderSide(color: AdminColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _chooseDateRange,
                        icon: const Icon(Icons.calendar_month_outlined, size: 17),
                        label: Text(
                          _dateRange == null
                              ? 'Ngày đăng: Tất cả ngày'
                              : '${_dateRange!.start.day.toString().padLeft(2, '0')}/${_dateRange!.start.month.toString().padLeft(2, '0')}/${_dateRange!.start.year} – ${_dateRange!.end.day.toString().padLeft(2, '0')}/${_dateRange!.end.month.toString().padLeft(2, '0')}/${_dateRange!.end.year}',
                        ),
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Bỏ lọc ngày',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _dateRange = null),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 2. Danh Sách Bài Đăng Realtime từ Firebase
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                try {
                  return FirebaseFirestore.instance
                      .collection('posts')
                      .snapshots();
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
                  if (doc.id.toLowerCase().startsWith('sample')) return false;
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final hostId = (data['hostId'] ?? data['landlordId'] ?? '').toString().toLowerCase();
                  if (hostId == 'host_chu_ba_101' ||
                      hostId == 'host_minh_gv' ||
                      hostId == 'host_linhtrung_99' ||
                      hostId == 'host_saigon_luxury' ||
                      hostId.startsWith('host_sample')) {
                    return false;
                  }

                  final created = data['createdAt'] is Timestamp
                      ? (data['createdAt'] as Timestamp).toDate()
                      : null;
                  if (_dateRange != null &&
                      (created == null ||
                          created.isBefore(
                            DateTime(
                              _dateRange!.start.year,
                              _dateRange!.start.month,
                              _dateRange!.start.day,
                            ),
                          ) ||
                          created.isAfter(
                            DateTime(
                              _dateRange!.end.year,
                              _dateRange!.end.month,
                              _dateRange!.end.day,
                              23,
                              59,
                              59,
                            ),
                          ))) {
                    return false;
                  }

                  // Lấy status và ép chữ thường
                  String status =
                      data['status']?.toString().toLowerCase() ?? 'pending';

                  // Nếu status không thuộc nhóm Đã duyệt hoặc Từ chối -> Bắt buộc ép về Chờ duyệt
                  if (status != 'active' &&
                      status != 'approved' &&
                      status != 'danghien' &&
                      status != 'rejected' &&
                      status != 'tuchoi') {
                    status = 'pending';
                  }

                  if (_filter == 'all') return true;
                  if (_filter == 'pending') {
                    return status == 'pending' || status == 'choduyet';
                  }
                  if (_filter == 'active') {
                    return status == 'active' ||
                        status == 'approved' ||
                        status == 'danghien';
                  }
                  if (_filter == 'rejected') {
                    return status == 'rejected' || status == 'tuchoi';
                  }
                  return true;
                }).toList();

                DateTime postDate(DocumentSnapshot doc) {
                  final value =
                      (doc.data() as Map<String, dynamic>?)?['createdAt'];
                  return value is Timestamp
                      ? value.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0);
                }

                filteredDocs.sort((a, b) {
                  final da = a.data() as Map<String, dynamic>? ?? {};
                  final db = b.data() as Map<String, dynamic>? ?? {};
                  final handledA = [
                    'active',
                    'approved',
                    'danghien',
                    'rejected',
                    'tuchoi',
                  ].contains((da['status'] ?? '').toString().toLowerCase());
                  final handledB = [
                    'active',
                    'approved',
                    'danghien',
                    'rejected',
                    'tuchoi',
                  ].contains((db['status'] ?? '').toString().toLowerCase());
                  if (_filter == 'all' && handledA != handledB) {
                    return handledA ? 1 : -1;
                  }
                  return postDate(b).compareTo(postDate(a));
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thanh đếm số lượng kết quả
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Text(
                        'Tìm thấy ${filteredDocs.length} kết quả',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.muted,
                        ),
                      ),
                    ),

                    // Danh sách card
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.apartment_rounded,
                                    size: 48,
                                    color: AdminColors.border,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Không có bài đăng nào trong danh mục này',
                                    style: TextStyle(color: AdminColors.muted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: filteredDocs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
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
            color: isSelected ? color : AdminColors.chipIdle,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : AdminColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AdminColors.chipIdleLabel,
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
    final hostId =
        (data['hostId'] ?? data['landlordId'] ?? data['userId'] ?? '')
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
    if (status != 'active' &&
        status != 'approved' &&
        status != 'danghien' &&
        status != 'rejected' &&
        status != 'tuchoi') {
      status = 'pending';
    }

    final isPending = status == 'pending' || status == 'choduyet';
    final isActive =
        status == 'active' || status == 'approved' || status == 'danghien';
    final isRejected = status == 'rejected' || status == 'tuchoi';
    final canReviewAgain = isRejected && data['hostResubmittedAt'] != null;

    return InkWell(
      onTap: () => _openDetailPreview(doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending ? AdminColors.accent : AdminColors.border,
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
                    color: AdminColors.accentSoft,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                                imageUrl.contains(
                                      'firebasestorage.googleapis.com',
                                    ) ||
                                    imageUrl.contains('storage.googleapis.com')
                                ? WebHtmlElementStrategy.prefer
                                : WebHtmlElementStrategy.fallback,
                            errorBuilder: (ctx, err, stack) => Icon(
                              Icons.apartment_rounded,
                              color: AdminColors.muted,
                            ),
                          )
                        : Icon(
                            Icons.apartment_rounded,
                            color: AdminColors.muted,
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
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.warningContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '• Chờ duyệt',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.warningInk,
                                ),
                              ),
                            )
                          else if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.successContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Đã duyệt',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.successInk,
                                ),
                              ),
                            )
                          else if (isRejected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.dangerContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '• Từ chối',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.danger,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: AdminColors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 13,
                            color: AdminColors.muted,
                          ),
                          const SizedBox(width: 4),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _hostProfile(hostId),
                            builder: (context, snapshot) {
                              final profile = snapshot.data;
                              final name =
                                  (hostName ??
                                          profile?['displayName'] ??
                                          profile?['hoTen'] ??
                                          profile?['fullName'] ??
                                          'Chủ trọ')
                                      .toString();
                              return Text(
                                name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AdminColors.mutedStrong,
                                ),
                              );
                            },
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $phone',
                              style: TextStyle(
                                fontSize: 11,
                                color: AdminColors.mutedStrong,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMoney(price),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AdminColors.accentText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isPending) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: AdminColors.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approvePost(id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '✓ Duyệt bài đăng',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDetailPreview(doc),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFFFDA29B)),
                        foregroundColor: AdminColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '✕ Từ chối',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                      label: Text(
                        'Xem Trực Tiếp',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectPost(id),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        size: 14,
                        color: AdminColors.danger,
                      ),
                      label: Text(
                        'Hạ Tin / Gỡ Bài',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.danger,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFFFDA29B)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isRejected) ...[
              if (rejectReason != null && rejectReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminColors.dangerContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: AdminColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rejectReason,
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canReviewAgain ? () => _approvePost(id) : null,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(
                    canReviewAgain
                        ? 'Duyệt lại / Hiện bài'
                        : 'Chờ chủ trọ chỉnh sửa bài',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canReviewAgain
                        ? AdminColors.success
                        : AdminColors.disabledFill,
                    foregroundColor: canReviewAgain
                        ? Colors.white
                        : AdminColors.mutedStrong,
                    disabledBackgroundColor: AdminColors.disabledFill,
                    disabledForegroundColor: AdminColors.mutedStrong,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
