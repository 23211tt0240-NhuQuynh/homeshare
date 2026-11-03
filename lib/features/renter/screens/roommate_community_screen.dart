import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../profile/screens/role_aware_profile_screen.dart';
import 'create_roommate_post_screen.dart';
import 'roommate_room_detail_screen.dart';
import 'roommate_search_screen.dart';

/// Màn hình Tìm Ở Ghép chuẩn Figma 100% (Hình 1)
/// Tích hợp Bộ lọc Lifestyle & Ở ghép AI Match (Hình 2)
class RoommateCommunityScreen extends ConsumerStatefulWidget {
  const RoommateCommunityScreen({super.key});

  @override
  ConsumerState<RoommateCommunityScreen> createState() => _RoommateCommunityScreenState();
}

enum _RoommateSort { newest, hobby, priceLow }

class _RoommateCommunityScreenState extends ConsumerState<RoommateCommunityScreen> {
  _RoommateSort _sort = _RoommateSort.newest;

  RoommateFilterParams _currentFilters = const RoommateFilterParams(
    district: 'Tất cả',
    targetGender: 'Tất cả',
    hasRoom: true,
    occupation: 'Tất cả',
    minMatchRate: 0,
  );

  void _openRoommateSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoommateSearchScreen(
          initialProvince: 'TP. Hồ Chí Minh',
          initialHasRoom: _currentFilters.hasRoom != false,
        ),
      ),
    );
  }

  /// Format thời gian hiển thị tương đối
  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 59);
      return '$mins phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }

  /// Visual metadata cho các nhãn thói quen sinh hoạt
  Map<String, dynamic> _getHabitVisual(String habit) {
    final lower = habit.toLowerCase();
    if (lower.contains('thuốc')) {
      return {'icon': Icons.smoke_free_rounded, 'color': const Color(0xFFEF4444), 'bg': AppColors.dangerContainer};
    } else if (lower.contains('yên tĩnh')) {
      return {'icon': Icons.nightlight_round, 'color': const Color(0xFF3B82F6), 'bg': AppColors.primaryContainer};
    } else if (lower.contains('sạch sẽ')) {
      return {'icon': Icons.cleaning_services_rounded, 'color': const Color(0xFF10B981), 'bg': AppColors.successContainer};
    } else if (lower.contains('thân thiện') || lower.contains('vui vẻ')) {
      return {'icon': Icons.sentiment_satisfied_alt_rounded, 'color': const Color(0xFFF59E0B), 'bg': AppColors.warningContainer};
    } else if (lower.contains('giờ giấc')) {
      return {'icon': Icons.access_time_rounded, 'color': const Color(0xFF3B82F6), 'bg': AppColors.primaryContainer};
    } else if (lower.contains('xe máy')) {
      return {'icon': Icons.two_wheeler_rounded, 'color': const Color(0xFF0284C7), 'bg': AppColors.primaryContainer};
    } else if (lower.contains('thể thao')) {
      return {'icon': Icons.sports_soccer_rounded, 'color': const Color(0xFFD97706), 'bg': AppColors.warningContainer};
    } else if (lower.contains('ồn ào') || lower.contains('tụ tập')) {
      return {'icon': Icons.volume_off_rounded, 'color': const Color(0xFFEF4444), 'bg': AppColors.dangerContainer};
    } else if (lower.contains('chăm học')) {
      return {'icon': Icons.menu_book_rounded, 'color': const Color(0xFF3B82F6), 'bg': AppColors.primaryContainer};
    } else if (lower.contains('nấu ăn')) {
      return {'icon': Icons.restaurant_rounded, 'color': const Color(0xFF0284C7), 'bg': AppColors.primaryContainer};
    } else if (lower.contains('dậy sớm')) {
      return {'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFF59E0B), 'bg': AppColors.warningContainer};
    } else if (lower.contains('thú cưng') || lower.contains('pet')) {
      return {'icon': Icons.pets_rounded, 'color': const Color(0xFFF59E0B), 'bg': AppColors.warningContainer};
    } else if (lower.contains('dẫn bạn')) {
      return {'icon': Icons.people_alt_rounded, 'color': AppColors.primary, 'bg': AppColors.primaryContainer};
    }
    return {'icon': Icons.check_circle_outline, 'color': AppColors.textMuted, 'bg': AppColors.surfaceVariant};
  }

  Future<void> _onToggleBookmark(RoommatePostModel post) async {
    final added = await ref.read(favoritesProvider.notifier).toggleFavoritePost(post);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Đã lưu bài đăng vào mục yêu thích ❤️' : 'Đã bỏ lưu bài đăng khỏi yêu thích'),
        backgroundColor: added ? AppColors.primary : AppColors.textMuted,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _navigateToChat(RoommatePostModel post) {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi tin nhắn')),
      );
      return;
    }

    if (currentUser.uid == post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là bài đăng của chính bạn')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: post.authorId,
          receiverName: post.authorName,
          receiverAvatar: post.authorAvatar,
          receiverPhone: post.contactPhone,
          isLandlord: false,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedPost: post,
        ),
      ),
    );
  }

  Future<void> _reloadPosts() async {
    final filters = _currentFilters;
    ref.invalidate(roommatePostsStreamProvider(filters));
    try {
      await ref.read(roommatePostsStreamProvider(filters).future);
    } catch (_) {}
  }

  void _openAuthorProfile(RoommatePostModel post) {
    final authorId = post.authorId.trim();
    if (authorId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoleAwareProfileScreen(userId: authorId)),
    );
  }

  void _openSharedRoomDetail(RoommatePostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoommateRoomDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final postsAsync = ref.watch(roommatePostsStreamProvider(_currentFilters));

    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final user = ref.read(currentUserProvider);
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Vui lòng đăng nhập để đăng tin tìm ở ghép'),
                backgroundColor: AppColors.danger,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRoommatePostScreen()),
          );
        },
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Đăng tin ở ghép',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildFigmaAppBar(profile),

            _buildSegmentTabSwitcher(),

            Expanded(
              child: postsAsync.when(
                skipLoadingOnReload: true,
                data: (posts) => RefreshIndicator(
                  color: colors.primary,
                  onRefresh: _reloadPosts,
                  child: _buildPostsList(_sortedPosts(posts)),
                ),
                loading: () => Center(child: CircularProgressIndicator(color: colors.primary)),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Lỗi tải dữ liệu: $err', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// App Bar chuẩn Figma
  ImageProvider? _authorImage(String raw) {
    final url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return NetworkImage(url);
    return null;
  }

  Widget _buildFigmaAppBar(UserProfile? profile) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.home_rounded, color: colors.onPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Tìm Ở Ghép',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textDark,
                ),
              ),
            ],
          ),
          Row(
            children: [
              PopupMenuButton<_RoommateSort>(
                tooltip: 'Sắp xếp',
                initialValue: _sort,
                offset: const Offset(0, 44),
                color: colors.surface,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => [
                  _sortMenuItem(_RoommateSort.newest, Icons.article_outlined, 'Bài đăng mới nhất'),
                  _sortMenuItem(_RoommateSort.hobby, Icons.favorite_border, 'Sở thích phù hợp'),
                  _sortMenuItem(_RoommateSort.priceLow, Icons.payments_outlined, 'Giá thấp đến cao'),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.tune_rounded, color: colors.textDark, size: 24),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search_rounded, color: colors.textDark, size: 26),
                onPressed: _openRoommateSearch,
              ),
              const SizedBox(width: 4),
              // Profile Avatar
              Builder(builder: (context) {
                final raw = profile?.avatarUrl.trim() ?? '';
                final avatar = raw.startsWith('http') ? NetworkImage(raw) : null;
                return CircleAvatar(
                  radius: 17,
                  backgroundColor: colors.surfaceVariant,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(
                          (profile?.displayName.trim().isNotEmpty == true)
                              ? profile!.displayName.trim()[0].toUpperCase()
                              : 'U',
                          style: TextStyle(fontWeight: FontWeight.w800, color: colors.textDark),
                        )
                      : null,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }


  /// Hai tab: đã có phòng và đang cần tìm phòng.
  Widget _buildSegmentTabSwitcher() {
    final hasRoom = _currentFilters.hasRoom != false;
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabItem(
              title: 'Đã có phòng',
              isSelected: hasRoom,
              onTap: () {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(hasRoom: true);
                });
              },
            ),
            _buildTabItem(
              title: 'Cần tìm phòng',
              isSelected: !hasRoom,
              onTap: () {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(hasRoom: false);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? colors.primary : colors.textMuted,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_RoommateSort> _sortMenuItem(_RoommateSort value, IconData icon, String label) {
    final selected = _sort == value;
    final colors = AppColors.of(context);
    final color = selected ? colors.primary : colors.textDark;
    return PopupMenuItem<_RoommateSort>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  double _sortPrice(RoommatePostModel post) {
    if (post.pricePerPerson > 0) return post.pricePerPerson;
    return post.budgetMax;
  }

  List<RoommatePostModel> _sortedPosts(List<RoommatePostModel> posts) {
    final list = List<RoommatePostModel>.from(posts);
    switch (_sort) {
      case _RoommateSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _RoommateSort.hobby:
        list.sort((a, b) {
          final left = a.matchRate < 0 ? -1 : a.matchRate;
          final right = b.matchRate < 0 ? -1 : b.matchRate;
          final byRate = right.compareTo(left);
          if (byRate != 0) return byRate;
          return b.createdAt.compareTo(a.createdAt);
        });
      case _RoommateSort.priceLow:
        list.sort((a, b) {
          final byPrice = _sortPrice(a).compareTo(_sortPrice(b));
          if (byPrice != 0) return byPrice;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  /// Danh sách bài đăng
  Widget _buildPostsList(List<RoommatePostModel> posts) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Danh sách thẻ bài đăng
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.feed_outlined, size: 54, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có bài đăng nào',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hãy là người đầu tiên đăng tin tìm bạn ở ghép!',
                    style: TextStyle(fontSize: 14.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ...posts.map((post) => _buildPostCard(post)),

        const SizedBox(height: 8),

        // Banner CTA Tạo bài đăng cuối danh sách
        _buildBottomCtaBanner(),
      ],
    );
  }

  /// Thẻ Bài Đăng Chuẩn Figma 100% (Khớp thiết kế ảnh người dùng)
  Widget _buildPostCard(RoommatePostModel post) {
    final colors = AppColors.of(context);
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isBookmarked = ref.watch(favoritesProvider).favoritePostIds.contains(post.id);

    // Format giá hiển thị
    String priceText;
    if (post.hasRoom && post.pricePerPerson > 0) {
      priceText = '~${currencyFmt.format(post.pricePerPerson)}';
    } else if (post.pricePerPerson > 0) {
      priceText = '~${currencyFmt.format(post.pricePerPerson)}';
    } else {
      priceText = '${(post.budgetMin / 1000000).toStringAsFixed(1)} - ${(post.budgetMax / 1000000).toStringAsFixed(0)} triệu';
    }

    return InkWell(
      onTap: () => _openSharedRoomDetail(post),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tag trạng thái + Thời gian đăng
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.hasRoom
                        ? AppColors.primaryContainer
                        : AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: post.hasRoom ? const Color(0xFF0284C7) : const Color(0xFFEA580C),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          post.hasRoom ? 'Đã có phòng sẵn' : 'Chưa có phòng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: post.hasRoom
                                ? (colors.isDark ? colors.textDark : AppColors.primary)
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (post.matchRate >= 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${post.matchRate}% hợp',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
              const SizedBox(width: 8),
              Icon(Icons.access_time_rounded, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _formatTimeAgo(post.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Thông tin Tác giả: Avatar có tick xanh, Tên, Tuổi, Trường/Nghề + Bookmark
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openAuthorProfile(post),
                child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.primaryContainer,
                    backgroundImage: _authorImage(post.authorAvatar),
                    child: _authorImage(post.authorAvatar) == null
                        ? Text(
                            post.authorName.isNotEmpty ? post.authorName[0] : 'U',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  if (post.isVerified)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openAuthorProfile(post),
                    behavior: HitTestBehavior.opaque,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: post.authorName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.textDark,
                            ),
                          ),
                          TextSpan(
                            text: ' • ${post.authorAge} tuổi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                      children: [
                        Icon(
                          post.authorOccupation.contains('SV') || post.authorOccupation.contains('Sinh viên')
                              ? Icons.school_outlined
                              : Icons.work_outline_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            post.authorOccupation,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ),
              // Nút Yêu thích / Bookmark tròn bên phải
              InkWell(
                onTap: () => _onToggleBookmark(post),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isBookmarked ? colors.dangerContainer : colors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBookmarked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isBookmarked ? colors.danger : colors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Khung nội dung xám xanh nhạt bo góc (Tiêu đề, Giá, Địa chỉ)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: priceText,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      TextSpan(
                        text: post.hasRoom ? ' /người/tháng' : ' /tháng',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1.0),
                      child: Icon(Icons.location_on_outlined, size: 15, color: colors.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.address,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Hàng 2 ảnh căn phòng có nhãn chú thích
          _buildPhotosRow(post),

          // 5. Tiêu chí sinh hoạt (Lifestyle tags chuẩn Figma)
          if (post.habits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.hasRoom ? 'TIÊU CHÍ SINH HOẠT:' : 'LỐI SỐNG & THÓI QUEN:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.habits.take(4).map((h) {
                final visual = _getHabitVisual(h);
                return Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: visual['bg'] as Color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(visual['icon'] as IconData, size: 14, color: visual['color'] as Color),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          h,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),

          // 6. Nút Hành Động: [💬 Nhắn tin trao đổi] + [Xem hồ sơ]
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToChat(post),
                    icon: const Icon(Icons.chat_bubble_outline, size: 17),
                    label: const Text(
                      'Nhắn tin trao đổi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _openSharedRoomDetail(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.textDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Xem chi tiết',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  /// Hiển thị 2 ảnh song song có chú thích chuẩn Figma
  Widget _buildPhotosRow(RoommatePostModel post) {
    final images = post.images;
    if (images.isEmpty) return const SizedBox.shrink();

    final captions = post.imageCaptions;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 116,
        child: Row(
          children: [
            Expanded(
              child: _buildPhotoItem(
                images[0],
                captions.isNotEmpty ? captions[0] : 'Phòng ngủ máy lạnh',
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _buildPhotoItem(
                  images[1],
                  captions.length > 1 ? captions[1] : 'Bếp chung rộng',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(String imagePath, String caption) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildRoomImage(imagePath),
          if (caption.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomImage(String imgUrl) {
    imgUrl = imgUrl.trim();
    if (imgUrl.isEmpty) {
      return Container(
        color: AppColors.of(context).surfaceVariant,
        child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 28),
      );
    }
    // 1. Ảnh trực tuyến (Firebase Storage / Web URL)
    if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.of(context).surfaceVariant,
          child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 28),
        ),
      );
    }
    // 2. Ảnh mã hóa Base64 Data URI (hiển thị 100% trên mọi máy)
    if (imgUrl.startsWith('data:image')) {
      try {
        final commaIdx = imgUrl.indexOf(',');
        final base64Data = commaIdx != -1 ? imgUrl.substring(commaIdx + 1) : imgUrl;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.of(context).surfaceVariant,
            child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 28),
          ),
        );
      } catch (_) {}
    }
    // 3. File nội bộ trên cùng thiết bị
    try {
      final file = File(imgUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.of(context).surfaceVariant,
            child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 28),
          ),
        );
      }
    } catch (_) {}

    // 4. Fallback cho thiết bị khác khi bài viết cũ lưu file path cục bộ từ máy khác
    return Image.network(
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.of(context).surfaceVariant,
        child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 28),
      ),
    );
  }

  /// Banner Kêu gọi Đăng tin cuối trang
  Widget _buildBottomCtaBanner() {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa tìm được bạn ghép ưng ý?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: colors.textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tạo bài tìm người ghép miễn phí trong 1 phút',
                  style: TextStyle(fontSize: 13.5, color: colors.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoommatePostScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
