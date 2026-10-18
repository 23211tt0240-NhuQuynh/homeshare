import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/host_post_model.dart';

/// Thẻ hiển thị bài đăng của chủ trọ đối tác theo thiết kế Figma
class HostPostCard extends StatelessWidget {
  final HostPostModel post;
  final VoidCallback onChatPressed;
  final VoidCallback? onInterestPressed;

  const HostPostCard({
    super.key,
    required this.post,
    required this.onChatPressed,
    this.onInterestPressed,
  });

  String _formatCurrency(double price) {
    if (price <= 0) return 'Thoả thuận';
    final formatter = NumberFormat.decimalPattern('vi');
    return '${formatter.format(price.toInt())} đ/tháng';
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
      return '$mins phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationText = [
      if (post.district.isNotEmpty) post.district,
      if (post.city.isNotEmpty) post.city,
    ].join(', ');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header chủ trọ: Avatar, Tên, Xác minh, VIP, Khu vực, Thời gian
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            post.authorName.isNotEmpty
                                ? post.authorName
                                : 'Chủ trọ HomeShare',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (post.isVerified)
                            const Tooltip(
                              message: 'Đã xác minh danh tính',
                              child: Icon(
                                Icons.verified,
                                color: Color(0xFF1E60F2),
                                size: 16,
                              ),
                            ),
                          if (post.isVip)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Đối tác uy tín',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (locationText.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                locationText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '•',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _formatTimeAgo(post.ngayDang),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Tiêu đề và nội dung bài đăng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.tieuDe.isNotEmpty)
                  Text(
                    post.tieuDe,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                if (post.moTa.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.moTa,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),

                // Mục đích hợp tác
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFBBF7D0),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        size: 15,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          post.mucDichHopTac.isNotEmpty
                              ? post.mucDichHopTac
                              : 'Kết nối chia sẻ khách thuê & Hợp tác quản lý',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tiện ích
                if (post.amenities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: post.amenities.take(5).map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
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
                    }).toList()
                      ..addAll(
                        post.amenities.length > 5
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${post.amenities.length - 5}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ]
                            : [],
                      ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Carousel ảnh bài đăng (hỗ trợ vuốt chuyển nhiều ảnh)
          _buildPostImage(),

          // 4. Thông tin phòng, xác thực cơ sở & Giá thuê
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.square_foot_outlined,
                            size: 14,
                            color: Color(0xFF1E60F2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.roomArea > 0
                                ? '${post.roomArea.toStringAsFixed(0)} m²'
                                : '25 m²',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E60F2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Cơ sở đã xác thực',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(post.giaThue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 5. Nút Nhắn tin trao đổi (Đã xoá phần bình luận và yêu thích)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onChatPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF155EEF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text(
                  'Nhắn tin trao đổi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = post.authorAvatar.trim();
    final initials = post.authorName.isNotEmpty
        ? post.authorName.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'HS';

    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE2E8F0),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _fallbackAvatar(initials),
          ),
        ),
      );
    }

    return _fallbackAvatar(initials);
  }

  Widget _fallbackAvatar(String initials) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFDBEAFE),
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF1E60F2),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  static String _cleanUrl(String raw) {
    var s = raw.trim();
    if (s.startsWith('{') && s.endsWith('}')) {
      final match =
          RegExp(r'(?:duongDan|url|image):\s*([^,}]+)').firstMatch(s);
      if (match != null) {
        s = match.group(1)!.trim().replaceAll('"', '').replaceAll("'", "");
      }
    }
    return s;
  }

  Widget _buildPostImage() {
    final rawImages = post.images.isNotEmpty
        ? post.images
        : (post.joinedRoom?.images ?? const <String>[]);

    final seen = <String>{};
    final validImages = <String>[];
    for (final raw in rawImages) {
      final cleaned = _cleanUrl(raw);
      if (cleaned.isNotEmpty &&
          (cleaned.startsWith('http://') || cleaned.startsWith('https://')) &&
          !seen.contains(cleaned)) {
        seen.add(cleaned);
        validImages.add(cleaned);
      }
    }

    return _PostImageCarousel(images: validImages);
  }
}

/// Widget Carousel hỗ trợ vuốt chuyển ảnh mượt mà cho bài đăng có nhiều ảnh
class _PostImageCarousel extends StatefulWidget {
  final List<String> images;

  const _PostImageCarousel({required this.images});

  @override
  State<_PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<_PostImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) {
      return _buildImagePlaceholder();
    }

    if (images.length == 1) {
      return Container(
        height: 190,
        width: double.infinity,
        color: const Color(0xFFF1F5F9),
        child: Image.network(
          images.first,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (ctx, err, stack) => _buildImagePlaceholder(),
        ),
      );
    }

    return Container(
      height: 190,
      width: double.infinity,
      color: const Color(0xFFF1F5F9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Vuốt ngang danh sách ảnh (hỗ trợ cảm ứng, chuột kéo, trackpad)
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (ctx, err, stack) => _buildImagePlaceholder(),
                );
              },
            ),
          ),

          // Lớp phủ gradient mờ ở đáy ảnh để hiển thị dots rõ nét
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Badge đếm ảnh ở góc trên bên phải: ví dụ "1/4"
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Chỉ báo chấm tròn (dots indicator) ở giữa đáy ảnh
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                final isSelected = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isSelected ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),

          // Nút mũi tên trái để click chuyển ảnh nhanh
          if (_currentIndex > 0)
            Positioned(
              left: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Nút mũi tên phải để click chuyển ảnh nhanh
          if (_currentIndex < images.length - 1)
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0xFFEFF6FF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apartment_outlined,
            size: 48,
            color: const Color(0xFF1E60F2).withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ảnh cơ sở liên kết',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E60F2),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Hệ thống kết nối chủ trọ HomeShare',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

