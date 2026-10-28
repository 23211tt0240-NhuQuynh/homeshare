import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../auth/providers/user_provider.dart';
import 'room_detail_screen.dart';
import 'search_filter_screen.dart';

class RenterDashboardScreen extends ConsumerStatefulWidget {
  const RenterDashboardScreen({super.key});

  @override
  ConsumerState<RenterDashboardScreen> createState() =>
      _RenterDashboardScreenState();
}

class _RenterDashboardScreenState extends ConsumerState<RenterDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Tự động nạp dữ liệu mẫu vào Cloud Firestore nếu database trống
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomServiceProvider).seedInitialRoomsIfEmpty();
    });
  }

  String _roomAddressLabel(RoomModel room) {
    final parts = <String>[];

    void addPart(String value) {
      final part = value.trim().replaceAll(RegExp(r'^,+|,+$'), '').trim();
      if (part.isEmpty) return;
      final normalizedPart = part.toLowerCase();
      final currentAddress = parts.join(', ').toLowerCase();
      if (!currentAddress.contains(normalizedPart)) {
        parts.add(part);
      }
    }

    addPart(room.address);
    addPart(room.district);
    addPart(room.city);
    return parts.isEmpty ? 'Địa chỉ đang cập nhật' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    final roomsAsync = ref.watch(roomsStreamProvider(const RoomFilterParams()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_work_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Tìm phòng & Ở ghép thông minh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mở bộ lọc tìm phòng',
            icon: const Icon(Icons.search, color: AppColors.textMuted),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SearchFilterScreen(initialAdvanced: true),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roomsStreamProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting row
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Xin chào, ${profile?.displayName.isNotEmpty == true ? profile!.displayName : "bạn"} 👋',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),

              // Danh sách tất cả bài viết phòng trọ (Realtime Firestore)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TẤT CẢ BÀI VIẾT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchFilterScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.tune,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Bộ lọc',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              roomsAsync.when(
                data: (rawRooms) {
                  final rooms = rawRooms.where((r) => r.isDisplayable).toList();
                  if (rooms.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0F2F5)),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 36,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chưa có bài viết nào',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: rooms.map((room) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildRoomCard(room, currencyFormatter),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Text('Lỗi tải bài viết: $err'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(RoomModel room) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String label = room.statusDisplayLabel;

    if (room.isPending) {
      bgColor = const Color(0xFFFEF0C7);
      textColor = const Color(0xFFB54708);
      icon = Icons.schedule_rounded;
    } else if (room.isHiddenOrRejected) {
      bgColor = const Color(0xFFFEE4E2);
      textColor = const Color(0xFFD92D20);
      icon = Icons.visibility_off_rounded;
    } else {
      final s = room.status.toLowerCase().trim();
      if (s == 'occupied' || s == 'dathue') {
        bgColor = const Color(0xFFF2F4F7);
        textColor = const Color(0xFF344054);
        icon = Icons.lock_outline_rounded;
      } else {
        bgColor = const Color(0xFFECFDF3);
        textColor = const Color(0xFF027A48);
        icon = Icons.check_circle_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(RoomModel room, NumberFormat formatter) {
    final priceStr = '${formatter.format(room.price)} đ';
    final addressLabel = _roomAddressLabel(room);
    final hostName = room.hostName.trim().isNotEmpty
        ? room.hostName.trim()
        : 'Đang cập nhật';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0F2F5)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: room.images.isNotEmpty
                        ? Image.network(
                            room.images.first,
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.apartment,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.apartment,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  if (room.isHiddenOrRejected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Bài viết đang ẩn',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 48,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room.roomType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusBadge(room),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final isFav = ref
                            .watch(favoritesProvider)
                            .favoriteRoomIds
                            .contains(room.id);
                        return InkWell(
                          onTap: () async {
                            final added = await ref
                                .read(favoritesProvider.notifier)
                                .toggleFavoriteRoom(room);
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added
                                        ? 'Đã lưu phòng vào danh sách yêu thích ❤️'
                                        : 'Đã bỏ lưu phòng khỏi danh sách yêu thích',
                                  ),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: added
                                      ? AppColors.primary
                                      : const Color(0xFF334155),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B),
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$priceStr/tháng',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${room.rating}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          addressLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '• ${room.area} m²',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          'Chủ trọ: $hostName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
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
          ],
        ),
      ),
    );
  }
}
