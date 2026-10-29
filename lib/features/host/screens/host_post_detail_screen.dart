import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/host_post_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../renter/screens/report_host_screen.dart';
import '../../renter/screens/room_detail_screen.dart';
import '../data/host_post_repository.dart';
import 'host_create_post_screen.dart';

/// Màn hình Chi tiết bài đăng dành riêng cho Role Chủ trọ (Host).
/// Lấy dữ liệu trực tiếp từ collection 'posts' trong Firestore.
/// Giao diện chuẩn hoá tương tự chi tiết phòng của user, loại bỏ hoàn toàn tim & bình luận.
class HostPostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final HostPostModel? post;
  final bool isOwnPost;

  const HostPostDetailScreen({
    super.key,
    required this.postId,
    this.post,
    this.isOwnPost = false,
  });

  @override
  ConsumerState<HostPostDetailScreen> createState() => _HostPostDetailScreenState();
}

class _HostPostDetailScreenState extends ConsumerState<HostPostDetailScreen> {
  int _currentImageIndex = 0;
  HostPostModel? _currentPost;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _listenToPost();
  }

  void _listenToPost() {
    if (widget.postId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final db = FirebaseFirestore.instance;
    final currentUserId = ref.read(currentUserProvider)?.uid ?? '';

    db.collection(FirestoreCollections.posts).doc(widget.postId).snapshots().listen((doc) async {
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        var post = HostPostModel.fromFirestore(doc, currentUserId: currentUserId);
        post = await _enrichPostData(post);
        if (mounted) {
          setState(() {
            _currentPost = post;
            _isLoading = false;
          });
        }
      } else {
        // Fallback sang collection 'bai_dang_cho_thue' nếu còn tài liệu cũ
        try {
          final fbDoc = await db.collection(FirestoreCollections.baiDangChoThue).doc(widget.postId).get();
          if (mounted && fbDoc.exists && fbDoc.data() != null) {
            var post = HostPostModel.fromFirestore(fbDoc, currentUserId: currentUserId);
            post = await _enrichPostData(post);
            if (mounted) {
              setState(() {
                _currentPost = post;
                _isLoading = false;
              });
            }
            return;
          }
        } catch (_) {}

        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }, onError: (err) {
      debugPrint('[HostPostDetailScreen] Lỗi snapshot posts: $err');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<HostPostModel> _enrichPostData(HostPostModel post) async {
    try {
      final repo = ref.read(hostPostRepositoryProvider);
      var enriched = post;
      RoomModel? room;

      if (post.phongId.isNotEmpty) {
        room = await repo.getRoom(post.phongId);
        if (room != null) {
          enriched = enriched.withRoom(room);
        }
      }

      final hostIdToFetch = post.chuNhaId.isNotEmpty
          ? post.chuNhaId
          : (room?.hostId ?? '');
      if (hostIdToFetch.isNotEmpty) {
        final host = await repo.getHostProfile(hostIdToFetch);
        if (host != null) {
          enriched = enriched.withHost(host);
        }
      }

      final propId = room?.propertyId ?? '';
      if (propId.isNotEmpty) {
        final prop = await repo.getProperty(propId);
        if (prop != null) {
          enriched = enriched.copyWith(
            propertyName: prop.name,
            address: enriched.address.isNotEmpty ? enriched.address : prop.address,
            city: enriched.city.isNotEmpty ? enriched.city : prop.city,
            district: enriched.district.isNotEmpty ? enriched.district : prop.district,
          );
        }
      }

      if (post.diaDiemId.isNotEmpty && (enriched.city.isEmpty || enriched.district.isEmpty)) {
        final loc = await repo.getLocation(post.diaDiemId);
        if (loc != null) {
          enriched = enriched.withLocation(
            resolvedCity: loc['city'],
            resolvedDistrict: loc['district'],
          );
        }
      }

      return enriched;
    } catch (e) {
      debugPrint('[HostPostDetailScreen] Lỗi enrich bài đăng: $e');
      return post;
    }
  }

  List<String> get _cleanedImages {
    final post = _currentPost;
    if (post == null) return const [];

    final rawImages = post.images.isNotEmpty
        ? post.images
        : (post.joinedRoom?.images ?? const <String>[]);

    final list = <String>[];
    for (final raw in rawImages) {
      final cleaned = RoomDetailScreen.cleanImageUrl(raw);
      if (cleaned.isNotEmpty &&
          (cleaned.startsWith('http://') ||
              cleaned.startsWith('https://') ||
              cleaned.startsWith('blob:') ||
              cleaned.startsWith('data:') ||
              cleaned.startsWith('base64,'))) {
        list.add(cleaned);
      }
    }
    return list;
  }

  Widget _buildPostImage(String rawUrl) {
    final clean = RoomDetailScreen.cleanImageUrl(rawUrl);
    if (clean.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
      );
    }

    // 1. Base64 Data URI hoặc chuỗi Base64
    if (clean.startsWith('data:image') || clean.startsWith('base64,')) {
      try {
        final commaIdx = clean.indexOf(',');
        final base64Str = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
          ),
        );
      } catch (e) {
        debugPrint('[HostPostDetailScreen] Lỗi decode Base64: $e');
        return Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
        );
      }
    }

    // 2. Network Image (HTTP / HTTPS / Blob)
    return Image.network(
      clean,
      fit: BoxFit.cover,
      width: double.infinity,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[HostPostDetailScreen] Lỗi Image.network: $clean - $error');
        return Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
        );
      },
    );
  }

  void _onChatPressed() {
    final post = _currentPost;
    if (post == null) return;

    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để trao đổi với chủ trọ')),
      );
      return;
    }

    ref.read(hostPostRepositoryProvider).openChatWithHost(
      context,
      post,
      currentUserId: currentUser.uid,
      currentUserName: profile?.displayName,
    );
  }

  void _onCallHostPressed() {
    final post = _currentPost;
    if (post == null) return;

    final phone = post.soDienThoaiLienHe.isNotEmpty
        ? post.soDienThoaiLienHe
        : (post.joinedRoom?.hostPhone ?? 'Chưa cập nhật');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Số điện thoại liên hệ'),
        content: Text(
          'Liên hệ trực tiếp với chủ trọ ${post.authorName.isNotEmpty ? post.authorName : 'HomeShare'}:\n\n'
          '📞 $phone',
          style: const TextStyle(fontSize: 16, height: 1.4),
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

  void _onReportPressed() {
    final post = _currentPost;
    if (post == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportHostScreen.fromRoom(post.toRoomModel()),
      ),
    );
  }

  void _openHostProfile() {
    final post = _currentPost;
    if (post == null) return;

    final hostId = post.chuNhaId.isNotEmpty
        ? post.chuNhaId
        : (post.joinedRoom?.hostId ?? '');

    if (hostId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostProfileScreen(userId: hostId),
      ),
    );
  }

  String _formatCurrency(double price) {
    if (price <= 0) return 'Thoả thuận';
    final formatter = NumberFormat.decimalPattern('vi');
    return '${formatter.format(price.toInt())} đ/tháng';
  }

  String _formatDeposit(double deposit) {
    if (deposit <= 0) return 'Không yêu cầu cọc';
    final formatter = NumberFormat.decimalPattern('vi');
    return '${formatter.format(deposit.toInt())} đ';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';
    final post = _currentPost;

    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết bài đăng'),
          elevation: 0,
        ),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text(
                  'Không tìm thấy bài đăng hoặc bài đăng đã bị gỡ.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
        ),
      );
    }

    final isOwnPost = widget.isOwnPost ||
        (post.chuNhaId.isNotEmpty && post.chuNhaId == currentUserId);

    final images = _cleanedImages;
    final priceStr = _formatCurrency(post.giaThue);
    final depositStr = _formatDeposit(post.tienCoc);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. App Bar với Image Slider (ĐÃ XÓA NÚT TIM)
              SliverAppBar(
                expandedHeight: 280.0,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.primary,
                leading: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // XÓA HOÀN TOÀN BIỂU TƯỢNG TIM Ở ACTIONS
                actions: const [],
                flexibleSpace: FlexibleSpaceBar(
                  background: images.isNotEmpty
                      ? Stack(
                          children: [
                            PageView.builder(
                              itemCount: images.length,
                              onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                              itemBuilder: (context, index) {
                                return _buildPostImage(images[index]);
                              },
                            ),
                            // Chỉ số ảnh 1/n
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${_currentImageIndex + 1}/${images.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.apartment, size: 80, color: Colors.grey),
                        ),
                ),
              ),

              // 2. Nội dung chi tiết bài đăng
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trạng thái bài đăng
                      if (post.isRejected) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Bài đăng bị từ chối duyệt',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.rejectReason.isNotEmpty
                                    ? 'Lý do: ${post.rejectReason}'
                                    : 'Lý do: Thông tin bài đăng chưa đạt yêu cầu kiểm duyệt.',
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!post.isActive) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE4E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDA29B)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.visibility_off_rounded, color: Color(0xFFD92D20), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bài viết này hiện đang tạm ẩn hoặc đã kết thúc hợp tác.',
                                  style: TextStyle(
                                    color: Color(0xFFD92D20),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Tiêu đề bài đăng & Đánh giá
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.tieuDe.isNotEmpty ? post.tieuDe : 'Bài đăng phòng trọ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFE082)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, size: 14, color: Color(0xFFFFA000)),
                                SizedBox(width: 4),
                                Text(
                                  '5.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB78103),
                                  ),
                                ),
                                Text(
                                  ' (0)',
                                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Địa chỉ
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.address.isNotEmpty
                                  ? post.address
                                  : [post.district, post.city].where((s) => s.isNotEmpty).join(', '),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Bảng Giá thuê & Tiền đặt cọc
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Giá thuê phòng', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  priceStr,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            Container(height: 32, width: 1, color: const Color(0xFFE5E7EB)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tiền đặt cọc', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  depositStr,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Thông số phòng (Diện tích, Loại phòng, Trạng thái)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSpecItem(
                              Icons.square_foot,
                              '${post.roomArea > 0 ? post.roomArea.toInt() : (post.joinedRoom?.area.toInt() ?? 25)} m²',
                              'Diện tích',
                            ),
                            _buildSpecDivider(),
                            _buildSpecItem(
                              Icons.home_work_outlined,
                              post.roomType.isNotEmpty ? post.roomType : 'Phòng trọ',
                              'Loại phòng',
                            ),
                            _buildSpecDivider(),
                            _buildSpecItem(
                              post.isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                              post.isActive ? 'Còn phòng' : 'Hết phòng',
                              'Tình trạng',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Thông tin chủ nhà
                      const Text(
                        'Thông tin chủ trọ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _openHostProfile,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primaryContainer,
                                  child: Text(
                                    post.authorName.isNotEmpty
                                        ? post.authorName.trim().split(' ').last.substring(0, 1).toUpperCase()
                                        : 'CT',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 18,
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
                                            post.authorName.isNotEmpty ? post.authorName : 'Chủ trọ HomeShare',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Chủ nhà đã xác minh • Nhấn để xem hồ sơ',
                                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.phone_in_talk, color: AppColors.primary),
                                  tooltip: 'Gọi điện chủ trọ',
                                  onPressed: _onCallHostPressed,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tiện ích phòng trọ
                      if (post.amenities.isNotEmpty || (post.joinedRoom?.amenities.isNotEmpty == true)) ...[
                        const Text(
                          'Tiện ích phòng trọ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (post.amenities.isNotEmpty ? post.amenities : post.joinedRoom!.amenities).map((amenity) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    amenity,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Mô tả chi tiết (KHÔNG CÓ KHU VỰC BÌNH LUẬN)
                      const Text(
                        'Mô tả chi tiết',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          post.moTa.isNotEmpty ? post.moTa : 'Chưa có mô tả chi tiết.',
                          style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),

      // 3. Bottom Action Bar (ĐÃ XÓA TIM VÀ BÌNH LUẬN)
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: isOwnPost
              ? (post.isRejected
                  ? SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HostCreatePostScreen(
                                postToEdit: post,
                                isResubmitting: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text(
                          'Chỉnh sửa & Gửi duyệt lại',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    )
                  : Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Color(0xFF1E40AF), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Bài đăng của bạn',
                            style: TextStyle(
                              color: Color(0xFF1E40AF),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ))
              : Row(
                  children: [
                    // Nút Báo cáo
                    OutlinedButton.icon(
                      onPressed: _onReportPressed,
                      icon: const Icon(Icons.flag_outlined, color: Color(0xFFDC2626), size: 16),
                      label: const Text(
                        'Báo cáo',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(78, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút Nhắn tin trao đổi
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _onChatPressed,
                        icon: const Icon(Icons.chat_bubble_outline, size: 17),
                        label: const Text(
                          'Nhắn tin trao đổi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildSpecItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildSpecDivider() {
    return Container(height: 24, width: 1, color: const Color(0xFFE5E7EB));
  }
}
