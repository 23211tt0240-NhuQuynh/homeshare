import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/host_post_model.dart';
import '../screens/host_post_detail_screen.dart';
import '../screens/host_room_view_screen.dart';

/// Thẻ hiển thị bài đăng của chủ trọ đối tác theo thiết kế Figma
class HostPostCard extends StatefulWidget {
  final HostPostModel post;
  final VoidCallback onChatPressed;
  final VoidCallback? onInterestPressed;
  final bool isOwnPost;

  const HostPostCard({
    super.key,
    required this.post,
    required this.onChatPressed,
    this.onInterestPressed,
    this.isOwnPost = false,
  });

  @override
  State<HostPostCard> createState() => _HostPostCardState();
}

class _HostPostCardState extends State<HostPostCard> {
  late final PageController _pageController;
  int _currentPage = 0;

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

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostPostDetailScreen(
          postId: widget.post.id,
          post: widget.post,
          isOwnPost: widget.isOwnPost,
        ),
      ),
    );
  }

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
    final post = widget.post;
    final isOwnPost = widget.isOwnPost;
    final onChatPressed = widget.onChatPressed;

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
      child: InkWell(
        onTap: () => _openDetail(context),
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
                          if (isOwnPost)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Bài của bạn',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E60F2),
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

          // 3. Ảnh bài đăng hoặc placeholder an toàn
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatCurrency(post.giaThue),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                    // Badge trạng thái phòng gắn liền
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (post.joinedRoom?.isOccupied == true)
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (post.joinedRoom?.isOccupied == true)
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF6EE7B7),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (post.joinedRoom?.isOccupied == true)
                                ? Icons.lock_outline
                                : Icons.check_circle_outline,
                            size: 12,
                            color: (post.joinedRoom?.isOccupied == true)
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF047857),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (post.joinedRoom?.isOccupied == true)
                                ? 'Phòng đang ở'
                                : 'Phòng còn trống',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: (post.joinedRoom?.isOccupied == true)
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // 5. Nút Nhắn tin & Chuyển sang phòng để đặt phòng
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: isOwnPost
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostRoomViewScreen(
                                  room: post.resolvedRoom,
                                  post: post,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.meeting_room_outlined, size: 16),
                          label: const Text('Xem phòng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primaryLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onChatPressed,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E60F2),
                            side: const BorderSide(color: Color(0xFF1E60F2)),
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.person_outline, size: 16),
                          label: const Text('Bài của bạn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onChatPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E60F2),
                          side: const BorderSide(color: Color(0xFF1E60F2)),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Nhắn tin', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostRoomViewScreen(
                                  room: post.resolvedRoom,
                                  post: post,
                                ),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: (post.joinedRoom?.isOccupied == true)
                                ? const Color(0xFF64748B)
                                : const Color(0xFF1E60F2),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: Icon(
                            (post.joinedRoom?.isOccupied == true)
                                ? Icons.lock_outline
                                : Icons.meeting_room_outlined,
                            size: 16,
                          ),
                          label: Text(
                            (post.joinedRoom?.isOccupied == true)
                                ? 'Xem phòng (Đang ở)'
                                : 'Xem thông tin phòng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAvatar() {
    final post = widget.post;
    final avatarUrl = post.authorAvatar.trim();
    final initials = post.authorName.isNotEmpty
        ? post.authorName.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'HS';

    if (avatarUrl.startsWith('http')) {
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

  String _cleanUrl(String raw) {
    var s = raw.trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith("'") && s.endsWith("'") && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('{') && s.endsWith('}')) {
      final match = RegExp(
        r'(?:duongDan|url|image|imageUrl|link):\s*([^,}]+)',
      ).firstMatch(s);
      if (match != null) {
        s = match.group(1)!.trim().replaceAll('"', '').replaceAll("'", "");
      }
    }
    return s;
  }

  Widget _buildSingleImage(String raw) {
    final clean = _cleanUrl(raw);
    if (clean.isEmpty) return _buildImagePlaceholder();

    if (clean.startsWith('data:image') ||
        clean.startsWith('base64,') ||
        (!clean.startsWith('http') && clean.length > 100)) {
      try {
        final commaIdx = clean.indexOf(',');
        final base64Str =
            commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(
          base64Str.trim().replaceAll(RegExp(r'\s+'), ''),
        );
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
        );
      } catch (_) {
        return _buildImagePlaceholder();
      }
    }

    return Image.network(
      clean,
      fit: BoxFit.cover,
      width: double.infinity,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
    );
  }

  Widget _buildPostImage() {
    final post = widget.post;
    final rawImages = post.images.isNotEmpty
        ? post.images
        : (post.joinedRoom?.images ?? const <String>[]);

    final validImages = rawImages
        .map(_cleanUrl)
        .where(
          (img) =>
              img.isNotEmpty &&
              (img.startsWith('http://') ||
                  img.startsWith('https://') ||
                  img.startsWith('data:image') ||
                  img.startsWith('blob:') ||
                  (!img.startsWith('http') && img.length > 100)),
        )
        .toList();

    if (validImages.isEmpty) {
      return _buildImagePlaceholder();
    }

    if (validImages.length == 1) {
      return Container(
        height: 190,
        width: double.infinity,
        color: const Color(0xFFF1F5F9),
        child: _buildSingleImage(validImages.first),
      );
    }

    return Container(
      height: 190,
      width: double.infinity,
      color: const Color(0xFFF1F5F9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              controller: _pageController,
              itemCount: validImages.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
              },
              itemBuilder: (context, index) {
                return _buildSingleImage(validImages[index]);
              },
            ),
          ),
          // Chỉ số trang 1/n
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
                '${_currentPage + 1}/${validImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Nút mũi tên lùi
          if (_currentPage > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
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
          // Nút mũi tên tiến
          if (_currentPage < validImages.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
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
          // Dots indicator
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(validImages.length, (i) {
                final isCurrent = i == _currentPage;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isCurrent ? 14 : 6,
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
