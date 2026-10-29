import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/role_aware_profile_screen.dart';
import '../../profile/screens/cccd_verification_screen.dart';
import '../../profile/screens/help_faq_screen.dart';
import '../../profile/screens/terms_privacy_screen.dart';
import '../../profile/widgets/contact_hotline_sheet.dart';
import '../../renter/screens/favorite_rooms_screen.dart';
import '../../renter/screens/renter_bookings_screen.dart';
import '../../host/screens/host_main_screen.dart';
import '../../host/screens/host_property_management_screen.dart';
import '../../host/screens/host_tenant_management_screen.dart';
import '../../host/screens/host_checkin_checkout_screen.dart';
import '../../host/screens/host_violation_management_screen.dart';
import '../../host/screens/host_post_management_screen.dart';
import '../../host/data/host_post_repository.dart';
import '../../admin/screens/admin_main_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Đăng xuất khỏi tài khoản?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn sẽ cần đăng nhập lại để tiếp tục quản lý phòng hoặc liên hệ ở ghép.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (shouldLogout == true) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLang = ref.read(appLanguageProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.language_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Chọn ngôn ngữ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Lựa chọn ngôn ngữ hiển thị trên giao diện HomeShare',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: currentLang == 'vi'
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              leading: const Text('🇻🇳', style: TextStyle(fontSize: 24)),
              title: const Text('Tiếng Việt (Mặc định)', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: currentLang == 'vi'
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).setLanguage('vi');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã thiết lập ngôn ngữ hiển thị: Tiếng Việt'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: currentLang == 'en'
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English (US)', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: currentLang == 'en'
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).setLanguage('en');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Display language set to English'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(appThemeModeProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.palette_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Tùy chỉnh giao diện',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Chọn chủ đề sáng hoặc tối phù hợp với mắt bạn',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: currentMode == ThemeMode.light
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              leading: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Giao diện sáng (Mặc định)', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: currentMode == ThemeMode.light
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã chuyển sang giao diện sáng'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: currentMode == ThemeMode.dark
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              leading: const Icon(Icons.nightlight_round, color: Color(0xFF818CF8)),
              title: const Text('Giao diện tối (Dark mode)', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: currentMode == ThemeMode.dark
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã kích hoạt giao diện tối (Dark mode)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: currentMode == ThemeMode.system
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              leading: const Icon(Icons.settings_system_daydream_rounded, color: Color(0xFF64748B)),
              title: const Text('Theo hệ thống thiết bị', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: currentMode == ThemeMode.system
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Giao diện sẽ tự động đổi theo cài đặt hệ thống'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpFaqDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
    );
  }

  void _showHotlineDialog(BuildContext context) {
    showContactHotlineSheet(context);
  }

  void _showTermsDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final authUser = ref.watch(currentUserProvider);
    final firebaseAuthUser = FirebaseAuth.instance.currentUser;
    final currentUserId = (authUser?.uid != null && authUser!.uid.isNotEmpty)
        ? authUser.uid
        : (firebaseAuthUser?.uid != null && firebaseAuthUser!.uid.isNotEmpty
            ? firebaseAuthUser.uid
            : (profile?.uid ?? ''));
    final rejectedCountAsync = ref.watch(hostRejectedCountProvider(currentUserId));
    final rejectedPostsCount = rejectedCountAsync.value ?? 0;
    final currentLang = ref.watch(appLanguageProvider);
    final currentThemeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trang cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Hồ sơ cá nhân',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RoleAwareProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Profile Header Card: Nhấn vào để mở Hồ sơ cá nhân
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleAwareProfileScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: (profile?.avatarUrl.startsWith('http') == true)
                            ? NetworkImage(profile!.avatarUrl)
                            : null,
                        child: profile?.avatarUrl.startsWith('http') == true
                            ? null
                            : Text(
                                (profile?.displayName.isNotEmpty ?? false)
                                    ? profile!.displayName[0].toUpperCase()
                                    : 'HS',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    profile?.displayName ?? 'Người dùng HomeShare',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (profile?.isHost == true ||
                                            profile?.role == 'host' ||
                                            profile?.role == 'landlord' ||
                                            profile?.role == 'chutro')
                                        ? 'Chủ trọ'
                                        : 'Người tìm phòng',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (profile?.isHost == true ||
                                    profile?.role == 'host' ||
                                    profile?.role == 'landlord' ||
                                    profile?.role == 'chutro' ||
                                    profile?.isAdmin == true ||
                                    profile?.role == 'admin') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      'ID: ${profile?.userCode ?? "---"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    profile?.email ?? 'user@homeshare.vn',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (profile?.isCccdVerified == true)
                              Row(
                                children: [
                                  const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      profile?.cccdNumber.isNotEmpty == true
                                          ? 'Đã xác thực CCCD (${profile!.cccdNumber.substring(0, 4)}****${profile.cccdNumber.substring(profile.cccdNumber.length - 2)}) ✓'
                                          : 'Đã xác thực CCCD (eKYC) ✓',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CccdVerificationScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Chưa xác thực CCCD (Quét ngay)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.chevron_right, size: 13, color: Color(0xFFB45309)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Thống kê nhanh
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                child: (profile?.isHost == true)
                    ? Row(
                        children: [
                          _buildStatItem('03', 'Cơ sở / Nhà'),
                          _buildVerticalDivider(),
                          _buildStatItem('12', 'Phòng quản lý'),
                          _buildVerticalDivider(),
                          _buildStatItem('09', 'Đang cho thuê'),
                        ],
                      )
                    : Row(
                        children: [
                          _buildStatItem('08', 'Phòng đã lưu'),
                          _buildVerticalDivider(),
                          _buildStatItem('02', 'Lịch hẹn'),
                          _buildVerticalDivider(),
                          _buildStatItem('01', 'Đang thuê'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Quản lý & Tiện ích
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'QUẢN LÝ & TIỆN ÍCH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: (profile?.isHost == true)
                    ? [
                        _buildMenuRow(
                          icon: Icons.post_add_rounded,
                          title: 'Quản lý bài đăng',
                          subtitle: rejectedPostsCount > 0
                              ? '$rejectedPostsCount bài đăng bị từ chối duyệt'
                              : 'Danh sách bài đăng phòng, trạng thái kiểm duyệt',
                          badgeCount: rejectedPostsCount,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostPostManagementScreen(
                                  initialTabIndex: rejectedPostsCount > 0 ? 0 : 2,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.holiday_village_outlined,
                          title: 'Quản lý cơ sở & Tòa nhà',
                          subtitle: 'Danh sách các dãy trọ, căn hộ quản lý',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HostPropertyManagementScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.people_outline,
                          title: 'Quản lý khách thuê & Hợp đồng',
                          subtitle: 'Danh sách khách thuê và trạng thái hợp đồng',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostTenantManagementScreen(
                                  onSectionChanged: (_) {},
                                ),
                              ),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Bàn giao phòng (Check-in / Check-out)',
                          subtitle: 'Biên bản bàn giao tài sản và trang thiết bị',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostCheckinCheckoutScreen(
                                  onSectionChanged: (_) {},
                                ),
                              ),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.warning_amber_rounded,
                          title: 'Biên bản sự cố & Vi phạm',
                          subtitle: 'Ghi nhận và xử lý vi phạm nội quy',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostViolationManagementScreen(
                                  onSectionChanged: (_) {},
                                ),
                              ),
                            );
                          },
                        ),
                      ]
                    : [
                        _buildMenuRow(
                          icon: Icons.calendar_month_outlined,
                          title: 'Lịch xem phòng & Đơn thuê',
                          subtitle: 'Theo dõi yêu cầu xem phòng của bạn',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RenterBookingsScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.favorite_rounded,
                          title: 'Phòng trọ yêu thích',
                          subtitle: 'Danh sách phòng & bài đăng bạn quan tâm',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FavoriteRoomsScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.storefront_outlined,
                          title: 'Giao diện Chủ trọ (Quản lý)',
                          subtitle: 'Quản lý cơ sở, phòng, khách thuê & hợp đồng',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HostMainScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Quản trị hệ thống (Admin Portal)',
                          subtitle: 'Báo cáo doanh thu, giải ngân, duyệt tin',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminMainScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.meeting_room_outlined,
                          title: 'Phòng đang thuê (Nhà của tôi)',
                          subtitle: '1 phòng đang hoạt động',
                          onTap: () {},
                        ),
                        _buildMenuDivider(),
                        _buildMenuRow(
                          icon: Icons.build_outlined,
                          title: 'Báo cáo sự cố phòng trọ',
                          subtitle: 'Máy lạnh, điện nước, wifi',
                          onTap: () {},
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Cài đặt chung & Hỗ trợ (Chuyển từ Account Settings ra đây)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'CÀI ĐẶT CHUNG & HỖ TRỢ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.language_outlined,
                    title: 'Ngôn ngữ',
                    trailingText: currentLang == 'en' ? 'English' : 'Tiếng Việt',
                    onTap: () => _showLanguageDialog(context, ref),
                  ),
                  _buildMenuDivider(),
                  _buildSettingsItem(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Giao diện',
                    trailingText: currentThemeMode == ThemeMode.dark
                        ? 'Tối'
                        : (currentThemeMode == ThemeMode.system ? 'Hệ thống' : 'Sáng'),
                    onTap: () => _showThemeDialog(context, ref),
                  ),
                  _buildMenuDivider(),
                  _buildSettingsItem(
                    icon: Icons.help_outline,
                    title: 'Trung tâm trợ giúp & FAQ',
                    onTap: () => _showHelpFaqDialog(context),
                  ),
                  _buildMenuDivider(),
                  _buildSettingsItem(
                    icon: Icons.support_agent_outlined,
                    title: 'Liên hệ hỗ trợ / Hotline',
                    onTap: () => _showHotlineDialog(context),
                  ),
                  _buildMenuDivider(),
                  _buildSettingsItem(
                    icon: Icons.description_outlined,
                    title: 'Điều khoản & Chính sách bảo mật',
                    onTap: () => _showTermsDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Nút Đăng xuất theo chuẩn Figma
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                onTap: () => _confirmLogout(context, ref),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Phiên bản ứng dụng v3.8.2 • HomeShare',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String number, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 32,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount != null && badgeCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : null,
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
    );
  }

  Widget _buildMenuDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Color(0xFFF1F3F5),
    );
  }
}

