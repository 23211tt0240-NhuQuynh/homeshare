import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/role_aware_profile_screen.dart';
import '../../profile/screens/cccd_verification_screen.dart';
import '../../renter/screens/favorite_rooms_screen.dart';
import '../../renter/screens/renter_bookings_screen.dart';
import '../../host/screens/host_main_screen.dart';
import '../../host/screens/host_property_management_screen.dart';
import '../../host/screens/host_tenant_management_screen.dart';
import '../../host/screens/host_checkin_checkout_screen.dart';
import '../../host/screens/host_violation_management_screen.dart';
import '../../admin/screens/admin_main_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                Icons.logout_rounded,
                color: colors.danger,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Đăng xuất khỏi tài khoản?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn sẽ cần đăng nhập lại để tiếp tục quản lý phòng hoặc liên hệ ở ghép.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textMuted,
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
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(color: colors.textDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.danger,
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
        );
      },
    );

    if (shouldLogout == true) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  void _showLanguageDialog(BuildContext context) {
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
            const Text(
              'Chọn ngôn ngữ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.check, color: AppColors.of(ctx).primary),
              title: const Text('Tiếng Việt', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('Mặc định', style: TextStyle(color: AppColors.of(ctx).primary)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('English (US)'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ngôn ngữ tiếng Anh sẽ sớm được hỗ trợ!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(appThemeControllerProvider).value?.mode ?? ThemeMode.light;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        Widget check(ThemeMode mode) => mode == current
            ? Icon(Icons.check, color: colors.primary)
            : const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tùy chỉnh giao diện',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.wb_sunny_outlined, color: colors.primary),
                title: const Text(
                  'Giao diện sáng (Phòng Sáng)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: check(ThemeMode.light),
                onTap: () {
                  ref.read(appThemeControllerProvider.notifier).setMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(Icons.nightlight_round_outlined, color: colors.primary),
                title: const Text('Giao diện tối (Graphite)'),
                trailing: check(ThemeMode.dark),
                onTap: () {
                  ref.read(appThemeControllerProvider.notifier).setMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_system_daydream_outlined),
                title: const Text('Theo hệ thống thiết bị'),
                trailing: check(ThemeMode.system),
                onTap: () {
                  ref.read(appThemeControllerProvider.notifier).setMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpFaqDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: const [
            Center(
              child: SizedBox(
                width: 40,
                child: Divider(thickness: 4, height: 4),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Trung tâm trợ giúp & FAQ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ExpansionTile(
              title: Text('Làm thế nào để tìm phòng trọ phù hợp?'),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Bạn có thể vào tab Khám phá, sử dụng bộ lọc khu vực, mức giá, tiện ích hoặc tìm kiếm quanh các trường đại học.'),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('Đặt cọc phòng trực tuyến có an toàn không?'),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Toàn bộ khoản cọc qua HomeShare được giữ an toàn trên hệ thống và chỉ giải ngân cho chủ trọ sau khi bạn nhận phòng thành công.'),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('Quy trình xác thực CCCD (eKYC) là gì?'),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Xác thực CCCD gắn chip giúp tăng độ tin cậy của tài khoản, bảo vệ quyền lợi khi ký hợp đồng thuê trọ điện tử.'),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('Làm thế nào để đăng ký làm Chủ trọ?'),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Bạn có thể liên hệ quản trị viên hoặc vào mục Quản lý Chủ trọ để đăng ký cơ sở và phòng cho thuê.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHotlineDialog(BuildContext context) {
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
            const Text(
              'Liên hệ hỗ trợ & Hotline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.phone_in_talk, color: AppColors.of(ctx).primary),
              title: const Text('Tổng đài hỗ trợ 24/7'),
              subtitle: const Text('1900 1234 (Miễn phí cước)'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang kết nối tới tổng đài 1900 1234...')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.email_outlined, color: AppColors.of(ctx).primary),
              title: const Text('Email hỗ trợ'),
              subtitle: const Text('cskh@homeshare.vn'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: AppColors.of(ctx).primary),
              title: const Text('Zalo / Hỗ trợ trực tuyến'),
              subtitle: const Text('0981 234 567 (8:00 - 22:00)'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: const [
            Center(
              child: SizedBox(
                width: 40,
                child: Divider(thickness: 4, height: 4),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Điều khoản & Chính sách bảo mật',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '1. Điều khoản dịch vụ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'HomeShare là nền tảng kết nối người thuê trọ, người tìm bạn ở ghép và chủ nhà trọ. Người dùng có trách nhiệm cung cấp thông tin trung thực, tuân thủ pháp luật và nội quy phòng trọ khi ký kết hợp đồng.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 14),
            Text(
              '2. Chính sách bảo mật thông tin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Chúng tôi cam kết bảo vệ dữ liệu cá nhân, thông tin CCCD gắn chip và lịch sử giao dịch của bạn theo tiêu chuẩn an toàn bảo mật cao nhất. Dữ liệu chỉ được dùng cho mục đích định danh và xác thực hợp đồng.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 14),
            Text(
              '3. Quy định thanh toán & đặt cọc',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Các khoản đặt cọc giữ phòng được đảm bảo bởi HomeShare Escrow, bảo vệ tối đa quyền lợi của cả người thuê và chủ nhà.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final colors = AppColors.of(context);
    final themeState = ref.watch(appThemeControllerProvider).value;
    final themeIcon = themeState?.mode == ThemeMode.dark
        ? Icons.nightlight_round_outlined
        : Icons.wb_sunny_outlined;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Trang cá nhân'),
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
                side: BorderSide(color: colors.border),
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
                        backgroundColor: colors.primaryContainer,
                        backgroundImage: (profile?.avatarUrl.startsWith('http') == true)
                            ? NetworkImage(profile!.avatarUrl)
                            : null,
                        child: profile?.avatarUrl.startsWith('http') == true
                            ? null
                            : Text(
                                (profile?.displayName.isNotEmpty ?? false)
                                    ? profile!.displayName[0].toUpperCase()
                                    : 'HS',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
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
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (profile?.isHost == true ||
                                            profile?.role == 'host' ||
                                            profile?.role == 'landlord' ||
                                            profile?.role == 'chutro')
                                        ? 'Chủ trọ'
                                        : 'Người tìm phòng',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
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
                                      color: colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Text(
                                      'ID: ${profile?.userCode ?? "---"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textDark,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    profile?.email ?? 'user@homeshare.vn',
                                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (profile?.isCccdVerified == true)
                              Row(
                                children: [
                                  Icon(Icons.verified, size: 14, color: colors.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      profile?.cccdNumber.isNotEmpty == true
                                          ? 'Đã xác thực CCCD (${profile!.cccdNumber.substring(0, 4)}****${profile.cccdNumber.substring(profile.cccdNumber.length - 2)}) ✓'
                                          : 'Đã xác thực CCCD (eKYC) ✓',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary,
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
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colors.textMuted),
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
                          _buildStatItem(colors, '03', 'Cơ sở / Nhà'),
                          _buildVerticalDivider(colors),
                          _buildStatItem(colors, '12', 'Phòng quản lý'),
                          _buildVerticalDivider(colors),
                          _buildStatItem(colors, '09', 'Đang cho thuê'),
                        ],
                      )
                    : Row(
                        children: [
                          _buildStatItem(colors, '08', 'Phòng đã lưu'),
                          _buildVerticalDivider(colors),
                          _buildStatItem(colors, '02', 'Lịch hẹn'),
                          _buildVerticalDivider(colors),
                          _buildStatItem(colors, '01', 'Đang thuê'),
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
                  color: colors.textMuted,
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
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
                          icon: Icons.meeting_room_outlined,
                          title: 'Phòng đang thuê (Nhà của tôi)',
                          subtitle: '1 phòng đang hoạt động',
                          onTap: () {},
                        ),
                        _buildMenuDivider(colors),
                        _buildMenuRow(
                          colors: colors,
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
                  color: colors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsItem(
                    colors: colors,
                    icon: Icons.language_outlined,
                    title: 'Ngôn ngữ',
                    trailingText: 'Tiếng Việt',
                    onTap: () => _showLanguageDialog(context),
                  ),
                  _buildMenuDivider(colors),
                  _buildSettingsItem(
                    colors: colors,
                    icon: themeIcon,
                    title: 'Giao diện',
                    trailingText: themeState?.label ?? 'Sáng',
                    onTap: () => _showThemeDialog(context, ref),
                  ),
                  _buildMenuDivider(colors),
                  _buildSettingsItem(
                    colors: colors,
                    icon: Icons.help_outline,
                    title: 'Trung tâm trợ giúp & FAQ',
                    onTap: () => _showHelpFaqDialog(context),
                  ),
                  _buildMenuDivider(colors),
                  _buildSettingsItem(
                    colors: colors,
                    icon: Icons.support_agent_outlined,
                    title: 'Liên hệ hỗ trợ / Hotline',
                    onTap: () => _showHotlineDialog(context),
                  ),
                  _buildMenuDivider(colors),
                  _buildSettingsItem(
                    colors: colors,
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
                    color: colors.dangerContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: colors.danger,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: colors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.danger,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Phiên bản ứng dụng v3.8.2 • HomeShare',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(AppPalette colors, String number, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(AppPalette colors) {
    return Container(
      height: 32,
      width: 1,
      color: colors.border,
    );
  }

  Widget _buildMenuRow({
    required AppPalette colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: colors.textDark),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textMuted),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: colors.textMuted,
      ),
    );
  }

  Widget _buildSettingsItem({
    required AppPalette colors,
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
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: colors.textDark),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            )
          : null,
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textMuted,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ),
    );
  }

  Widget _buildMenuDivider(AppPalette colors) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: colors.border,
    );
  }
}

