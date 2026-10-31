import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../data/models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/role_aware_profile_screen.dart';
import '../../profile/screens/cccd_verification_screen.dart';
import '../../profile/screens/help_faq_screen.dart';
import '../../profile/screens/terms_privacy_screen.dart';
import '../../profile/widgets/contact_hotline_sheet.dart';
import '../../renter/screens/favorite_rooms_screen.dart';
import '../../renter/screens/renter_bookings_screen.dart';
import '../../renter/screens/my_homes_screen.dart';
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref, String currentLang) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textDark = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final borderColor = isDark ? const Color(0xFF243044) : AppColors.border;

    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
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
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dangerContainer.withValues(alpha: isDark ? 0.2 : 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.tr('logout_confirm_title', currentLang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.tr('logout_confirm_message', currentLang),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textMuted,
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
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppTranslations.tr('cancel', currentLang),
                      style: TextStyle(color: textDark, fontWeight: FontWeight.w600),
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
                    child: Text(
                      AppTranslations.tr('logout', currentLang),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textDark = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final activeTileColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  AppTranslations.tr('select_language', currentLang),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppTranslations.tr('select_language_sub', currentLang),
              style: TextStyle(fontSize: 12.5, color: textMuted),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: currentLang == 'vi'
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0)),
                ),
              ),
              tileColor: currentLang == 'vi' ? activeTileColor : Colors.transparent,
              leading: const Text('🇻🇳', style: TextStyle(fontSize: 26)),
              title: Text(
                AppTranslations.tr('vietnamese_default', currentLang),
                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
              ),
              trailing: currentLang == 'vi'
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).setLanguage('vi');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.tr('lang_changed_vi', 'vi')),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: currentLang == 'en'
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0)),
                ),
              ),
              tileColor: currentLang == 'en' ? activeTileColor : Colors.transparent,
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 26)),
              title: Text(
                AppTranslations.tr('english_us', currentLang),
                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
              ),
              trailing: currentLang == 'en'
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).setLanguage('en');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.tr('lang_changed_en', 'en')),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(appThemeModeProvider);
    final currentLang = ref.read(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textDark = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final activeTileColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.palette_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  AppTranslations.tr('customize_appearance', currentLang),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppTranslations.tr('customize_appearance_sub', currentLang),
              style: TextStyle(fontSize: 12.5, color: textMuted),
            ),
            const SizedBox(height: 16),

            // Sáng (Light)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: currentMode == ThemeMode.light
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0)),
                ),
              ),
              tileColor: currentMode == ThemeMode.light ? activeTileColor : Colors.transparent,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              title: Text(
                AppTranslations.tr('theme_light', currentLang),
                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
              ),
              subtitle: Text(
                AppTranslations.tr('theme_light_sub', currentLang),
                style: TextStyle(fontSize: 11.5, color: textMuted),
              ),
              trailing: currentMode == ThemeMode.light
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.tr('theme_changed_light', currentLang)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF006948),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Tối (Dark)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: currentMode == ThemeMode.dark
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0)),
                ),
              ),
              tileColor: currentMode == ThemeMode.dark ? activeTileColor : Colors.transparent,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.nightlight_round, color: Color(0xFF818CF8), size: 20),
              ),
              title: Text(
                AppTranslations.tr('theme_dark', currentLang),
                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
              ),
              subtitle: Text(
                AppTranslations.tr('theme_dark_sub', currentLang),
                style: TextStyle(fontSize: 11.5, color: textMuted),
              ),
              trailing: currentMode == ThemeMode.dark
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.tr('theme_changed_dark', currentLang)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Hệ thống (System)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: currentMode == ThemeMode.system
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0)),
                ),
              ),
              tileColor: currentMode == ThemeMode.system ? activeTileColor : Colors.transparent,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings_system_daydream_rounded,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  size: 20,
                ),
              ),
              title: Text(
                AppTranslations.tr('theme_system', currentLang),
                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
              ),
              subtitle: Text(
                AppTranslations.tr('theme_system_sub', currentLang),
                style: TextStyle(fontSize: 11.5, color: textMuted),
              ),
              trailing: currentMode == ThemeMode.system
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.tr('theme_changed_system', currentLang)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
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
    final currentUser = ref.watch(currentUserProvider);
    final currentUid = currentUser?.uid ?? '';

    // Thống kê thực tế phòng đã lưu
    final favState = ref.watch(favoritesProvider);
    final savedCount = favState.favoriteRoomIds.length;

    // Thống kê thực tế đơn thuê & lịch hẹn của người thuê
    final bookingsAsync = currentUid.isNotEmpty
        ? ref.watch(renterBookingsStreamProvider(currentUid))
        : null;
    final bookings = bookingsAsync?.value ?? const <BookingRequestModel>[];
    final appointmentCount = bookings.where((b) => !b.isCancelled && !b.isActive).length;
    final activeRentals = bookings.where((b) => b.isActive).toList();
    final activeCount = activeRentals.length;

    // Thống kê thực tế của chủ trọ
    final hostBookingsAsync = currentUid.isNotEmpty
        ? ref.watch(hostBookingsStreamProvider(currentUid))
        : null;
    final hostBookings = hostBookingsAsync?.value ?? const <BookingRequestModel>[];
    final hostRentedCount = hostBookings.where((b) => b.isActive).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0);
    final textDark = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
    final iconBg = isDark ? const Color(0xFF1E2638) : const Color(0xFFF3F4F6);
    final dividerColor = isDark ? const Color(0xFF243044) : const Color(0xFFF1F3F5);

    String tr(String key) => AppTranslations.tr(key, currentLang);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          tr('my_profile'),
          style: TextStyle(fontWeight: FontWeight.bold, color: textDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: tr('personal_profile'),
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
                side: BorderSide(color: borderColor),
              ),
              color: cardColor,
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
                        backgroundColor: isDark
                            ? const Color(0xFF064E3B)
                            : AppColors.primaryContainer,
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
                                  color: Color(0xFF10B981),
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
                                    profile?.displayName ?? 'HomeShare User',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B)
                                        : AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (profile?.isHost == true ||
                                            profile?.role == 'host' ||
                                            profile?.role == 'landlord' ||
                                            profile?.role == 'chutro')
                                        ? tr('role_host')
                                        : tr('role_renter'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFD1FAE5) : AppColors.primary,
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
                                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      'ID: ${profile?.userCode ?? "---"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    profile?.email ?? 'user@homeshare.vn',
                                    style: TextStyle(fontSize: 12.5, color: textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (profile?.isCccdVerified == true)
                              Row(
                                children: [
                                  const Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      tr('verified_cccd'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
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
                                    color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          tr('unverified_cccd'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 13,
                                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Thống kê nhanh
            Card(
              margin: EdgeInsets.zero,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                child: (profile?.isHost == true)
                    ? Row(
                        children: [
                          _buildStatItem('03', tr('stat_properties'), mutedColor: textMuted),
                          _buildVerticalDivider(dividerColor: dividerColor),
                          _buildStatItem('12', tr('stat_managed_rooms'), mutedColor: textMuted),
                          _buildVerticalDivider(dividerColor: dividerColor),
                          _buildStatItem(hostRentedCount.toString().padLeft(2, '0'), tr('stat_rented_rooms'), mutedColor: textMuted),
                        ],
                      )
                    : Row(
                        children: [
                          _buildStatItem(
                            savedCount.toString().padLeft(2, '0'),
                            tr('stat_saved_rooms'),
                            mutedColor: textMuted,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FavoriteRoomsScreen()),
                              );
                            },
                          ),
                          _buildVerticalDivider(dividerColor: dividerColor),
                          _buildStatItem(
                            appointmentCount.toString().padLeft(2, '0'),
                            tr('stat_appointments'),
                            mutedColor: textMuted,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RenterBookingsScreen(initialStatusFilter: 'Đang xử lý'),
                                ),
                              );
                            },
                          ),
                          _buildVerticalDivider(dividerColor: dividerColor),
                          _buildStatItem(
                            activeCount.toString().padLeft(2, '0'),
                            tr('stat_renting'),
                            mutedColor: textMuted,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyHomesScreen(initialTab: 0),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Quản lý & Tiện ích
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                tr('section_management'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
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
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
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
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.holiday_village_outlined,
                          title: tr('manage_properties'),
                          subtitle: tr('manage_properties_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HostPropertyManagementScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.people_outline,
                          title: tr('manage_tenants'),
                          subtitle: tr('manage_tenants_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
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
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.assignment_turned_in_outlined,
                          title: tr('handover_room'),
                          subtitle: tr('handover_room_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
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
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.warning_amber_rounded,
                          title: tr('incidents_violations'),
                          subtitle: tr('incidents_violations_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
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
                          title: tr('view_schedule_bookings'),
                          subtitle: tr('view_schedule_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RenterBookingsScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.favorite_rounded,
                          title: tr('favorite_rooms'),
                          subtitle: tr('favorite_rooms_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FavoriteRoomsScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.storefront_outlined,
                          title: tr('host_interface'),
                          subtitle: tr('host_interface_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HostMainScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.admin_panel_settings_outlined,
                          title: tr('admin_portal'),
                          subtitle: tr('admin_portal_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminMainScreen()),
                            );
                          },
                        ),
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.meeting_room_outlined,
                          title: tr('current_rented_room'),
                          subtitle: activeCount > 0
                              ? (currentLang == 'vi'
                                  ? '$activeCount phòng đang hoạt động'
                                  : '$activeCount active rented room${activeCount > 1 ? "s" : ""}')
                              : (currentLang == 'vi'
                                  ? 'Chưa có phòng đang thuê'
                                  : 'No active rented rooms'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyHomesScreen(initialTab: 0),
                              ),
                            );
                          },
                        ),
                        _buildMenuDivider(dividerColor: dividerColor),
                        _buildMenuRow(
                          icon: Icons.build_outlined,
                          title: tr('report_issue'),
                          subtitle: tr('report_issue_sub'),
                          textDark: textDark,
                          textMuted: textMuted,
                          iconBg: iconBg,
                          onTap: () {},
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Cài đặt chung & Hỗ trợ
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                tr('section_general_settings'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.language_rounded,
                    title: tr('language'),
                    trailingText: currentLang == 'en' ? 'English (US)' : 'Tiếng Việt',
                    textDark: textDark,
                    textMuted: textMuted,
                    iconBg: iconBg,
                    onTap: () => _showLanguageDialog(context, ref),
                  ),
                  _buildMenuDivider(dividerColor: dividerColor),
                  _buildSettingsItem(
                    icon: Icons.palette_outlined,
                    title: tr('appearance'),
                    trailingText: currentThemeMode == ThemeMode.dark
                        ? tr('theme_name_dark')
                        : (currentThemeMode == ThemeMode.system
                            ? tr('theme_name_system')
                            : tr('theme_name_light')),
                    textDark: textDark,
                    textMuted: textMuted,
                    iconBg: iconBg,
                    onTap: () => _showThemeDialog(context, ref),
                  ),
                  _buildMenuDivider(dividerColor: dividerColor),
                  _buildSettingsItem(
                    icon: Icons.help_outline_rounded,
                    title: tr('help_faq'),
                    textDark: textDark,
                    textMuted: textMuted,
                    iconBg: iconBg,
                    onTap: () => _showHelpFaqDialog(context),
                  ),
                  _buildMenuDivider(dividerColor: dividerColor),
                  _buildSettingsItem(
                    icon: Icons.support_agent_rounded,
                    title: tr('contact_support'),
                    textDark: textDark,
                    textMuted: textMuted,
                    iconBg: iconBg,
                    onTap: () => _showHotlineDialog(context),
                  ),
                  _buildMenuDivider(dividerColor: dividerColor),
                  _buildSettingsItem(
                    icon: Icons.description_outlined,
                    title: tr('terms_privacy'),
                    textDark: textDark,
                    textMuted: textMuted,
                    iconBg: iconBg,
                    onTap: () => _showTermsDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Nút Đăng xuất
            Card(
              margin: EdgeInsets.zero,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: ListTile(
                onTap: () => _confirmLogout(context, ref, currentLang),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerContainer.withValues(alpha: isDark ? 0.25 : 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
                title: Text(
                  tr('logout'),
                  style: const TextStyle(
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
            Center(
              child: Text(
                tr('version_info'),
                style: TextStyle(
                  fontSize: 12,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String number, String label, {required Color mutedColor, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider({required Color dividerColor}) {
    return Container(
      height: 32,
      width: 1,
      color: dividerColor,
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textDark = AppColors.textDark,
    Color textMuted = AppColors.textMuted,
    Color iconBg = AppColors.surfaceVariant,
    int? badgeCount,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: textDark),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: textMuted),
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
          Icon(
            Icons.chevron_right,
            size: 20,
            color: textMuted,
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
    required Color textDark,
    required Color textMuted,
    required Color iconBg,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: textDark),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: textMuted),
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
                    color: textMuted,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: textMuted,
              ),
            ],
          ),
    );
  }

  Widget _buildMenuDivider({required Color dividerColor}) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: dividerColor,
    );
  }
}
