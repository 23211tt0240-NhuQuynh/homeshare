import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/host_post_model.dart';
import '../../renter/screens/room_detail_screen.dart';

/// Thẻ hiển thị bài đăng của chủ trọ đối tác theo thiết kế Figma
class HostPostCard extends StatelessWidget {
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

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(
          room: post.toRoomModel(),
          isHostView: isOwnPost,
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
    final locationText = [
      if (post.district.isNotEmpty) post.district,
      if (post.city.isNotEmpty) post.city,
    ].join(', ');

    return Card(
      elevation: 1,
      color: AppColors.surface,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 1. Header chủ trọ: Avatar, Tên, Xác minh, VIP, Khu vực, Thời gian
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                SizedBox(width: 12),
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (post.isVerified)
                            Tooltip(
                              message: 'Đã xác minh danh tính',
                              child: Icon(
                                Icons.verified,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                          if (post.isVip)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Đối tác uy tín',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                                ),
                              ),
                            ),
                          if (isOwnPost)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Bài của bạn',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Row(
                        children: [
                          if (locationText.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                locationText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            SizedBox(width: 6),
                          ],
                          Text(
                            _formatTimeAgo(post.ngayDang),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
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
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.tieuDe.isNotEmpty)
                  Text(
                    post.tieuDe,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                if (post.moTa.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Text(
                    post.moTa,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 10),

                // Mục đích hợp tác
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.handshake_outlined,
                        size: 15,
                        color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A)),
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          post.mucDichHopTac.isNotEmpty
                              ? post.mucDichHopTac
                              : 'Kết nối chia sẻ khách thuê & Hợp tác quản lý',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (AppColors.isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tiện ích
                if (post.amenities.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: post.amenities.take(5).map((amenity) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          amenity,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList()
                      ..addAll(
                        post.amenities.length > 5
                            ? [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${post.amenities.length - 5}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
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
          SizedBox(height: 12),

          // 3. Ảnh bài đăng hoặc placeholder an toàn
          _buildPostImage(),

          // 4. Thông tin phòng, xác thực cơ sở & Giá thuê
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.square_foot_outlined,
                            size: 14,
                            color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
                          ),
                          SizedBox(width: 4),
                          Text(
                            post.roomArea > 0
                                ? '${post.roomArea.toStringAsFixed(0)} m²'
                                : '25 m²',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Cơ sở đã xác thực',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _formatCurrency(post.giaThue),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 20, color: AppColors.surfaceVariant),

          // 5. Thao tác tương tác & Nút Nhắn tin trao đổi
          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                // Nút Quan tâm
                InkWell(
                  onTap: onInterestPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.isUserInterested
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 18,
                          color: post.isUserInterested
                              ? const Color(0xFFE11D48)
                              : AppColors.textMuted,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${post.interestedCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: post.isUserInterested
                                ? const Color(0xFFE11D48)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 4),

                // Lượt phản hồi
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 17,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${post.responseCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                Spacer(),

                // Nút Nhắn tin trao đổi / Bài của bạn
                Flexible(
                  child: isOwnPost
                      ? OutlinedButton.icon(
                          onPressed: onChatPressed,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
                            side: BorderSide(color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2))),
                            minimumSize: const Size(0, 36),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(Icons.person_outline, size: 15),
                          label: Text(
                            'Bài của bạn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: onChatPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: Icon(Icons.chat_bubble_outline, size: 15),
                          label: Text(
                            'Nhắn tin trao đổi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
    final avatarUrl = post.authorAvatar.trim();
    final initials = post.authorName.isNotEmpty
        ? post.authorName.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'HS';

    if (avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.border,
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
      backgroundColor: AppColors.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
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

  Widget _buildPostImage() {
    final rawImages = post.images.isNotEmpty
        ? post.images
        : (post.joinedRoom?.images ?? const <String>[]);

    final validImages = rawImages
        .map(_cleanUrl)
        .where(
          (img) =>
              img.isNotEmpty &&
              (img.startsWith('http://') || img.startsWith('https://')),
        )
        .toList();

    if (validImages.isNotEmpty) {
      final firstImage = validImages.first;
      return Container(
        height: 180,
        width: double.infinity,
        color: AppColors.surfaceVariant,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              firstImage,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (ctx, err, stack) => _buildImagePlaceholder(),
            ),
            if (validImages.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '1/${validImages.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: AppColors.primaryContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apartment_outlined,
            size: 48,
            color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)).withValues(alpha: 0.6),
          ),
          SizedBox(height: 8),
          Text(
            'Ảnh cơ sở liên kết',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1E60F2)),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Hệ thống kết nối chủ trọ HomeShare',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
