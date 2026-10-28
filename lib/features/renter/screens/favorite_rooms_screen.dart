import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/favorites_service.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../profile/widgets/host_reputation_stars.dart';
import 'renter_main_screen.dart';
import 'room_detail_screen.dart';
import 'roommate_post_detail_screen.dart';

class FavoriteRoomsScreen extends ConsumerStatefulWidget {
  const FavoriteRoomsScreen({super.key});

  @override
  ConsumerState<FavoriteRoomsScreen> createState() => _FavoriteRoomsScreenState();
}

class _FavoriteRoomsScreenState extends ConsumerState<FavoriteRoomsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favState = ref.watch(favoritesProvider);
    final rooms = favState.favoriteRooms;
    final posts = favState.favoritePosts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Phòng trọ yêu thích',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Phòng trọ (${rooms.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Tin ở ghép (${posts.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: PHÒNG TRỌ ĐÃ LƯU
          _buildRoomsTab(rooms),

          // TAB 2: BÀI ĐĂNG Ở GHÉP ĐÃ LƯU
          _buildPostsTab(posts),
        ],
      ),
    );
  }

  Widget _buildRoomsTab(List<RoomModel> rooms) {
    if (rooms.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Chưa có phòng trọ yêu thích',
        subtitle: 'Bấm vào biểu tượng trái tim ở các phòng trọ để lưu lại và tiện theo dõi bất cứ khi nào!',
        buttonText: 'Khám phá phòng trọ ngay',
        onButtonPressed: () {
          Navigator.pop(context);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: rooms.length,
      itemBuilder: (ctx, idx) {
        final room = rooms[idx];
        return _buildRoomFavoriteCard(room);
      },
    );
  }

  Widget _buildRoomFavoriteCard(RoomModel room) {
    final priceStr = '${_currencyFormatter.format(room.price)} đ/tháng';
    final imageUrl = room.images.isNotEmpty
        ? room.images.first
        : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail ảnh phòng
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 100,
                          height: 100,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.apartment, size: 36, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room.roomType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Thông tin chi tiết phòng
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng Tiêu đề & Nút Tim đỏ
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              room.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                height: 1.3,
                              ),
                            ),
                          ),
                          // Nút Bỏ lưu / Tim
                          InkWell(
                            onTap: () async {
                              await ref.read(favoritesProvider.notifier).toggleFavoriteRoom(room);
                              if (mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Đã bỏ lưu phòng khỏi danh sách yêu thích'),
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'Hoàn tác',
                                      textColor: Colors.amber,
                                      onPressed: () {
                                        ref.read(favoritesProvider.notifier).toggleFavoriteRoom(room);
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFEF4444),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Địa chỉ
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              room.address.isNotEmpty ? room.address : '${room.district}, ${room.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Giá thuê & Đánh giá
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            priceStr,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          HostReputationStarLabel(
                            hostId: room.hostId,
                            iconSize: 15,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
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
        ),
      ),
    );
  }

  Widget _buildPostsTab(List<RoommatePostModel> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Chưa có bài đăng ở ghép yêu thích',
        subtitle: 'Bấm vào biểu tượng lưu ở các bài đăng tìm bạn cùng phòng để xem lại danh sách bất cứ lúc nào!',
        buttonText: 'Tìm bạn cùng phòng ngay',
        onButtonPressed: () {
          // Chuyển tab sang Tìm ở ghép
          ref.read(renterBottomNavIndexProvider.notifier).setIndex(3);
          Navigator.pop(context);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: posts.length,
      itemBuilder: (ctx, idx) {
        final post = posts[idx];
        return _buildPostFavoriteCard(post);
      },
    );
  }

  Widget _buildPostFavoriteCard(RoommatePostModel post) {
    final priceStr = '${_currencyFormatter.format(post.pricePerPerson)} đ/người';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoommatePostDetailScreen(post: post)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Tác giả + Nút tim đỏ
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primarySurface,
                      backgroundImage: post.authorAvatar.startsWith('http') ? NetworkImage(post.authorAvatar) : null,
                      child: post.authorAvatar.startsWith('http')
                          ? null
                          : Text(
                              post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (post.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: AppColors.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${post.authorAge} tuổi • ${post.authorGender} • ${post.authorOccupation}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        await ref.read(favoritesProvider.notifier).toggleFavoritePost(post);
                        if (mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Đã bỏ lưu bài đăng khỏi danh sách yêu thích'),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'Hoàn tác',
                                textColor: Colors.amber,
                                onPressed: () {
                                  ref.read(favoritesProvider.notifier).toggleFavoritePost(post);
                                },
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tiêu đề bài đăng
                Text(
                  post.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Giá & Địa chỉ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      priceStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: post.hasRoom ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        post.hasRoom ? 'Đã có phòng' : 'Đang tìm phòng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: post.hasRoom ? const Color(0xFF059669) : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.address.isNotEmpty ? post.address : post.district,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),

                // Tiêu chí sinh hoạt (Habits chips)
                if (post.habits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: post.habits.take(3).map((h) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$h',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA), width: 2),
              ),
              child: Icon(icon, size: 42, color: const Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
