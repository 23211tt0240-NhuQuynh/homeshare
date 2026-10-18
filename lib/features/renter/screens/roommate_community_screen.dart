import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/roommate_service.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'create_roommate_post_screen.dart';
import 'roommate_lifestyle_filter_sheet.dart';
import 'roommate_room_detail_screen.dart';
import 'roommate_search_screen.dart';

/// Màn hình Tìm Ở Ghép chuẩn Figma 100% (Hình 1)
/// Tích hợp Bộ lọc Lifestyle & Ở ghép AI Match (Hình 2)
class RoommateCommunityScreen extends ConsumerStatefulWidget {
  const RoommateCommunityScreen({super.key});

  @override
  ConsumerState<RoommateCommunityScreen> createState() => _RoommateCommunityScreenState();
}

class _RoommateCommunityScreenState extends ConsumerState<RoommateCommunityScreen> {
  // Bộ lọc hiện tại (Mặc định: Toàn quốc, Tất cả giới tính, Đã có phòng)
  RoommateFilterParams _currentFilters = const RoommateFilterParams(
    district: 'Tất cả',
    targetGender: 'Tất cả',
    hasRoom: true, // Mặc định: Đang tìm người ghép (Có phòng)
    occupation: 'Tất cả',
    minMatchRate: 0,
  );

  final Set<String> _bookmarkedPostIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSavedFavorites);
  }

  Future<void> _loadSavedFavorites() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final ids = await ref.read(roommateServiceProvider).favoritePostIds(user.uid);
      if (!mounted) return;
      setState(() {
        _bookmarkedPostIds
          ..clear()
          ..addAll(ids);
      });
    } catch (e) {
      debugPrint('Đọc yeu_thich: $e');
    }
  }

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

  /// Mở Bottom Sheet "Bộ lọc Lifestyle & Ở ghép AI Match" (Hình 2)
  void _openLifestyleFilterSheet(int matchingCount) {
    RoommateLifestyleFilterSheet.show(
      context,
      initialFilters: _currentFilters,
      matchingCount: matchingCount,
      onApply: (updated) {
        setState(() {
          _currentFilters = updated;
        });
      },
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
      return {'icon': Icons.smoke_free_rounded, 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEE2E2)};
    } else if (lower.contains('yên tĩnh')) {
      return {'icon': Icons.nightlight_round, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)};
    } else if (lower.contains('sạch sẽ')) {
      return {'icon': Icons.cleaning_services_rounded, 'color': const Color(0xFF10B981), 'bg': const Color(0xFFECFDF5)};
    } else if (lower.contains('thân thiện') || lower.contains('vui vẻ')) {
      return {'icon': Icons.sentiment_satisfied_alt_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('giờ giấc')) {
      return {'icon': Icons.access_time_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)};
    } else if (lower.contains('xe máy')) {
      return {'icon': Icons.two_wheeler_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)};
    } else if (lower.contains('thể thao')) {
      return {'icon': Icons.sports_soccer_rounded, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('ồn ào') || lower.contains('tụ tập')) {
      return {'icon': Icons.volume_off_rounded, 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEE2E2)};
    } else if (lower.contains('chăm học')) {
      return {'icon': Icons.menu_book_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)};
    } else if (lower.contains('nấu ăn')) {
      return {'icon': Icons.restaurant_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)};
    } else if (lower.contains('dậy sớm')) {
      return {'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('thú cưng') || lower.contains('pet')) {
      return {'icon': Icons.pets_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('dẫn bạn')) {
      return {'icon': Icons.people_alt_rounded, 'color': AppColors.primary, 'bg': const Color(0xFFEFF6FF)};
    }
    return {'icon': Icons.check_circle_outline, 'color': const Color(0xFF475569), 'bg': const Color(0xFFF1F5F9)};
  }

  void _onToggleBookmark(String postId) {
    final willSave = !_bookmarkedPostIds.contains(postId);
    setState(() {
      if (willSave) {
        _bookmarkedPostIds.add(postId);
      } else {
        _bookmarkedPostIds.remove(postId);
      }
    });
    final user = ref.read(currentUserProvider);
    if (user != null) {
      ref.read(roommateServiceProvider).setRoommateFavorite(
        userId: user.uid,
        postId: postId,
        saved: willSave,
      );
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bookmarkedPostIds.contains(postId) ? 'Đã lưu bài đăng vào mục yêu thích ✓' : 'Đã bỏ lưu bài đăng'),
        backgroundColor: AppColors.primary,
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
          roommatePostId: post.id,
        ),
      ),
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
    final hasHobbies = (ref.watch(viewerHobbyNamesProvider).value ?? const <String>[]).isNotEmpty;

    final count = postsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 18,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final user = ref.read(currentUserProvider);
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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

            // 5. Danh sách bài đăng & Banner AI Matching
            Expanded(
              child: postsAsync.when(
                data: (posts) => _buildPostsList(posts, count, hasHobbies),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
  Widget _buildFigmaAppBar(UserProfile? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tìm Ở Ghép',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.search_rounded, color: Color(0xFF334155), size: 26),
            onPressed: _openRoommateSearch,
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF334155), size: 24),
                  onPressed: () {},
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: SizedBox(
                    width: 7,
                    height: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: _listAvatar(profile?.avatarUrl ?? ''),
            child: _listAvatar(profile?.avatarUrl ?? '') == null
                ? const Icon(Icons.person, size: 18, color: Color(0xFF64748B))
                : null,
          ),
        ],
      ),
    );
  }


  /// Segment Tab Switcher: "Đang tìm người ghép (Có phòng)" vs "Người cần tìm phòng ghép"
  Widget _buildSegmentTabSwitcher() {
    final isHasRoom = _currentFilters.hasRoom == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(hasRoom: true);
                  });
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  decoration: BoxDecoration(
                    color: isHasRoom ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isHasRoom
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Đã có phòng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isHasRoom ? FontWeight.bold : FontWeight.w500,
                      color: isHasRoom ? AppColors.primary : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(hasRoom: false);
                  });
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  decoration: BoxDecoration(
                    color: !isHasRoom ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: !isHasRoom
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Cần tìm phòng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: !isHasRoom ? FontWeight.bold : FontWeight.w500,
                      color: !isHasRoom ? AppColors.primary : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Danh sách thường, không dùng sliver. Sliver đang đo sai chiều cao nên kéo
  /// vượt quá bài cuối vào khoảng trắng.
  Widget _buildPostsList(List<RoommatePostModel> posts, int matchingCount, bool hasHobbies) {
    return SingleChildScrollView(
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAiMatchBanner(matchingCount, hasHobbies),
          ),
          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.feed_outlined, size: 54, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có bài đăng nào',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hãy là người đầu tiên đăng tin tìm bạn ở ghép!',
                    style: TextStyle(fontSize: 14.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          if (posts.isNotEmpty) ...posts.map(_buildPostCard),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildBottomCtaBanner(),
          ),
        ],
      ),
    );
  }

  /// Banner Gợi ý AI Lifestyle Matching
  Widget _buildAiMatchBanner(int matchingCount, bool hasHobbies) {
    return InkWell(
      onTap: () => _openLifestyleFilterSheet(matchingCount),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Độ tương thích lối sống',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasHobbies
                        ? 'Xếp theo sở thích của bạn, mỗi bài một mức %'
                        : 'Thêm sở thích ở hồ sơ để xem mức hợp',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  /// Thẻ Bài Đăng Chuẩn Figma 100% (Khớp thiết kế ảnh người dùng)
  Widget _buildPostCard(RoommatePostModel post) {
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isBookmarked = _bookmarkedPostIds.contains(post.id);

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tag trạng thái + Thời gian đăng
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.hasRoom ? const Color(0xFFDCEEFE) : const Color(0xFFFFEDD5),
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
                            color: post.hasRoom ? const Color(0xFF0369A1) : const Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                _formatTimeAgo(post.createdAt),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              if (post.matchRate >= 0) ...[
                const Spacer(),
                Text(
                  '${post.matchRate}% hợp',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // 2. Thông tin Tác giả: Avatar có tick xanh, Tên, Tuổi, Trường/Nghề + Bookmark
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: _listAvatar(post.authorAvatar),
                    child: _listAvatar(post.authorAvatar) == null
                        ? Text(
                            post.authorName.isNotEmpty ? post.authorName[0] : 'U',
                            style: const TextStyle(
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: post.authorName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        TextSpan(
                          text: ' • ${post.authorAge} tuổi',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                            style: const TextStyle(
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
              // Nút Bookmark tròn bên phải
              InkWell(
                onTap: () => _onToggleBookmark(post.id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isBookmarked ? AppColors.primary : const Color(0xFF475569),
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
              color: const Color(0xFFF6F8FD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: priceText,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      TextSpan(
                        text: post.hasRoom ? ' /người/tháng' : ' /tháng',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1.0),
                      child: Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.habits.take(4).map((h) {
                final visual = _getHabitVisual(h);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(visual['icon'] as IconData, size: 14, color: visual['color'] as Color),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          h,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
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
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      post.hasRoom ? 'Xem hồ sơ' : 'Xem chi tiết',
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

  /// Ảnh chỉ là lớp vẽ. Khung luôn cao 116 nên danh sách không bị kéo vào khoảng trắng.
  Widget _buildPhotosRow(RoommatePostModel post) {
    final images = <String>[
      for (final raw in post.images)
        if (_isHttpPhoto(raw)) raw.trim(),
    ];
    if (images.isEmpty) return const SizedBox.shrink();

    final captions = post.imageCaptions;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 116,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _photoTile(images[0], captions.isNotEmpty ? captions[0] : '')),
            if (images.length > 1) ...[
              const SizedBox(width: 10),
              Expanded(child: _photoTile(images[1], captions.length > 1 ? captions[1] : '')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoTile(String url, String caption) {
    final label = caption.length > 80 ? caption.substring(0, 80) : caption;
    return SizedBox(
      height: 116,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            image: DecorationImage(
              image: NetworkImage(url),
              fit: BoxFit.cover,
              onError: (_, _) {},
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: label.isEmpty
                ? const SizedBox(width: double.infinity, height: 116)
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool _isHttpPhoto(String raw) {
    final url = raw.trim();
    if (url.length > 2000) return false;
    return url.startsWith('https://') || url.startsWith('http://');
  }

  ImageProvider? _listAvatar(String raw) {
    final url = raw.trim();
    if (!_isHttpPhoto(url)) return null;
    return NetworkImage(url);
  }

  /// Banner Kêu gọi Đăng tin cuối trang
  Widget _buildBottomCtaBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa tìm được bạn ghép ưng ý?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 3),
                Text(
                  'Tạo bài tìm người ghép miễn phí trong 1 phút',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
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
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              elevation: 0,
              // Theme đặt chiều rộng tối thiểu là vô hạn. Trong hàng ngang nút không có size.
              minimumSize: const Size(88, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
