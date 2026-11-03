import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/host_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_post_repository.dart';
import 'host_create_post_screen.dart';
import 'host_post_detail_screen.dart';
import 'host_management_menu.dart';
import 'host_violation_management_screen.dart';

/// Màn hình Quản lý bài đăng dành riêng cho Role Chủ trọ.
/// Cho phép lọc các bài: Bị từ chối, Chờ duyệt, Đang hiển thị và Tất cả.
/// Hỗ trợ xem lý do từ chối từ Firestore, Chỉnh sửa và Gửi lại bài đăng để Admin duyệt lại.
class HostPostManagementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final ValueChanged<HostManagementSection>? onSectionChanged;

  const HostPostManagementScreen({
    super.key,
    this.initialTabIndex = 0,
    this.onSectionChanged,
  });

  @override
  ConsumerState<HostPostManagementScreen> createState() => _HostPostManagementScreenState();
}

class _HostPostManagementScreenState extends ConsumerState<HostPostManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hasAutoSelectedTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double price) {
    if (price <= 0) return 'Thoả thuận';
    final formatter = NumberFormat.decimalPattern('vi');
    return '${formatter.format(price.toInt())} đ/tháng';
  }

  String _formatDeposit(double deposit) {
    if (deposit <= 0) return 'Không cọc';
    final formatter = NumberFormat.decimalPattern('vi');
    return '${formatter.format(deposit.toInt())} đ';
  }

  Widget _buildThumbnail(List<String> images) {
    if (images.isEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.home_work_outlined, size: 36, color: Colors.grey),
      );
    }

    final raw = images.first.trim();

    // 1. Base64
    if (raw.startsWith('data:image') || (!raw.startsWith('http') && raw.length > 100)) {
      try {
        final commaIdx = raw.indexOf(',');
        final cleanBase64 = commaIdx != -1 ? raw.substring(commaIdx + 1) : raw;
        final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(),
          ),
        );
      } catch (_) {
        return _buildFallbackThumbnail();
      }
    }

    // 2. Network image
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        raw,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 100,
            height: 100,
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(),
      ),
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
    );
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const HostCreatePostScreen(),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo bài đăng mới thành công! Đang chờ quản trị viên duyệt.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editAndResubmitPost(HostPostModel post) async {
    if (post.isApprovedOrActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài đăng đã được duyệt không thể chỉnh sửa.'),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (post.isHidden) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài đăng ở trạng thái ẩn không thể chỉnh sửa.'),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HostCreatePostScreen(
          postToEdit: post,
          isResubmitting: post.isRejected,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            post.isRejected
                ? 'Đã gửi lại bài đăng để Admin phê duyệt lại!'
                : 'Cập nhật bài đăng thành công!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _viewPostDetail(HostPostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostPostDetailScreen(
          postId: post.id,
          post: post,
          isOwnPost: true,
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(HostPostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa bài đăng?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài đăng "${post.tieuDe.isNotEmpty ? post.tieuDe : 'Bài đăng'}"? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa bài'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(hostPostRepositoryProvider);
      final success = await repo.deletePost(post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Đã xóa bài đăng.' : 'Lỗi xóa bài đăng, vui lòng thử lại.',
            ),
            backgroundColor: success ? AppColors.textDark : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildStatusBadge(HostPostModel post) {
    if (post.isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFDC2626)),
            SizedBox(width: 4),
            Text(
              'Bị từ chối',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (post.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text(
              post.hostResubmittedAt != null ? 'Đã gửi lại duyệt' : 'Chờ duyệt',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (post.isApprovedOrActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
            SizedBox(width: 4),
            Text(
              'Đang hiển thị',
              style: TextStyle(
                color: Color(0xFF047857),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (post.isHidden) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_rounded, size: 13, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              'Đã ẩn',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        post.status.isNotEmpty ? post.status : 'Khác',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPostCard(HostPostModel post) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(post.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: post.isRejected
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
          width: post.isRejected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: post.isRejected
                ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phần thông tin chính
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(post.images),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatusBadge(post),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_horiz, size: 20, color: AppColors.textMuted),
                            onSelected: (val) {
                              if (val == 'view') {
                                _viewPostDetail(post);
                              } else if (val == 'edit') {
                                _editAndResubmitPost(post);
                              } else if (val == 'delete') {
                                _confirmDeletePost(post);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Xem chi tiết'),
                                  ],
                                ),
                              ),
                              if (post.canEdit)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Text('Xóa bài', style: TextStyle(color: Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.tieuDe.isNotEmpty ? post.tieuDe : 'Bài đăng phòng trọ',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            _formatCurrency(post.giaThue),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Cọc: ${_formatDeposit(post.tienCoc)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              post.address.isNotEmpty
                                  ? post.address
                                  : [post.district, post.city].where((s) => s.isNotEmpty).join(', '),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đăng ngày: $formattedDate',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Khối lý do từ chối (Nổi bật màu đỏ/cam khi bài đăng bị reject)
          if (post.isRejected) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LÝ DO TỪ CHỐI DUYỆT BÀI:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.rejectReason.isNotEmpty
                              ? post.rejectReason
                              : 'Bài đăng chưa đạt tiêu chuẩn nội dung hoặc thông tin phòng chưa đầy đủ. Vui lòng kiểm tra và chỉnh sửa lại.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7F1D1D),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Thông báo đã gửi lại duyệt chờ admin
          if (post.isPending && post.hostResubmittedAt != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã gửi lại duyệt lúc ${dateFormat.format(post.hostResubmittedAt!)}. Đang đợi Admin phê duyệt.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Divider
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Khối hành động chính
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: (post.isRejected && !post.isHidden)
                ? Row(
                    children: [
                      // Nút Xem chi tiết
                      OutlinedButton.icon(
                        onPressed: () => _viewPostDetail(post),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Xem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nút Chỉnh sửa & Gửi duyệt lại (NỔI BẬT)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _editAndResubmitPost(post),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text(
                            'Sửa & Gửi duyệt lại',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _viewPostDetail(post),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Xem chi tiết', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      if (post.canEdit) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _editAndResubmitPost(post),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    bool showCreateButton = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (showCreateButton) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openCreatePost,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Đăng bài mới', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<HostPostModel> posts, {required String emptyType}) {
    // Lọc theo search query
    final filtered = posts.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      return p.tieuDe.toLowerCase().contains(q) ||
          p.address.toLowerCase().contains(q) ||
          p.district.toLowerCase().contains(q) ||
          p.rejectReason.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy kết quả',
          description: 'Không có bài đăng nào khớp với từ khóa "$_searchQuery".',
        );
      }

      switch (emptyType) {
        case 'rejected':
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Không có bài đăng bị từ chối',
            description: 'Tuyệt vời! Tất cả các bài đăng của bạn đều tuân thủ đúng quy định và được duyệt thuận lợi.',
          );
        case 'pending':
          return _buildEmptyState(
            icon: Icons.hourglass_empty_rounded,
            title: 'Không có bài đăng chờ duyệt',
            description: 'Hiện không có bài đăng nào đang trong hàng đợi kiểm duyệt của quản trị viên.',
            showCreateButton: true,
          );
        case 'active':
          return _buildEmptyState(
            icon: Icons.storefront_outlined,
            title: 'Chưa có bài đăng đang hiển thị',
            description: 'Hãy đăng tin cho thuê để tiếp cận hàng nghìn khách thuê tiềm năng trên HomeShare.',
            showCreateButton: true,
          );
        default:
          return _buildEmptyState(
            icon: Icons.article_outlined,
            title: 'Bạn chưa tạo bài đăng nào',
            description: 'Bấm nút "Đăng bài mới" bên dưới để đăng tin cho thuê phòng trọ đầu tiên của bạn!',
            showCreateButton: true,
          );
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authUser = ref.read(currentUserProvider);
        final firebaseAuthUser = FirebaseAuth.instance.currentUser;
        final userProfile = ref.read(userProfileProvider).asData?.value;
        final currentUserId = (authUser?.uid != null && authUser!.uid.isNotEmpty)
            ? authUser.uid
            : (firebaseAuthUser?.uid != null && firebaseAuthUser!.uid.isNotEmpty
                ? firebaseAuthUser.uid
                : (userProfile?.uid ?? ''));
        ref.invalidate(hostMyPostsProvider(currentUserId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildPostCard(filtered[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(currentUserProvider);
    final firebaseAuthUser = FirebaseAuth.instance.currentUser;
    final userProfile = ref.watch(userProfileProvider).asData?.value;
    final currentUserId = (authUser?.uid != null && authUser!.uid.isNotEmpty)
        ? authUser.uid
        : (firebaseAuthUser?.uid != null && firebaseAuthUser!.uid.isNotEmpty
            ? firebaseAuthUser.uid
            : (userProfile?.uid ?? ''));
    final postsAsync = ref.watch(hostMyPostsProvider(currentUserId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Quản lý bài đăng',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: postsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 12),
                const Text(
                  'Không thể tải danh sách bài đăng',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(hostMyPostsProvider(currentUserId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (allPosts) {
          final rejectedPosts = allPosts.where((p) => p.isRejected).toList();
          final pendingPosts = allPosts.where((p) => p.isPending).toList();
          final activePosts = allPosts.where((p) => p.isApprovedOrActive).toList();

          // Tự động chuyển đến tab "Bị từ chối" lần đầu tiên nếu có bài bị reject và chưa chỉ định tab
          if (!_hasAutoSelectedTab && rejectedPosts.isNotEmpty && widget.initialTabIndex == 0) {
            _hasAutoSelectedTab = true;
          }

          return Column(
            children: [
              // Thanh tìm kiếm
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tiêu đề, địa chỉ, lý do từ chối...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Tab Bar với số đếm động
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Text('Tất cả'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${allPosts.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Text('Chờ duyệt'),
                          if (pendingPosts.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${pendingPosts.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Text('Đang hiển thị'),
                          if (activePosts.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${activePosts.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Text('Bị từ chối'),
                          if (rejectedPosts.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${rejectedPosts.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Nội dung từng Tab: Tất cả, Chờ duyệt, Đang hiển thị, Bị từ chối
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent(allPosts, emptyType: 'all'),
                    _buildTabContent(pendingPosts, emptyType: 'pending'),
                    _buildTabContent(activePosts, emptyType: 'active'),
                    _buildTabContent(rejectedPosts, emptyType: 'rejected'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
