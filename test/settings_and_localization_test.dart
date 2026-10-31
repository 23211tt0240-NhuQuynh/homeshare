import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/localization/app_translations.dart';
import 'package:home_share/core/providers/app_settings_provider.dart';
import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/core/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. AppTranslations - Ngôn ngữ & Dịch thuật Anh/Việt', () {
    test('Dịch chính xác các mục trong Cài đặt & Trang cá nhân sang Tiếng Việt', () {
      expect(AppTranslations.tr('my_profile', 'vi'), 'Trang cá nhân');
      expect(AppTranslations.tr('language', 'vi'), 'Ngôn ngữ');
      expect(AppTranslations.tr('appearance', 'vi'), 'Giao diện');
      expect(AppTranslations.tr('logout', 'vi'), 'Đăng xuất');
      expect(AppTranslations.tr('help_faq', 'vi'), 'Trung tâm trợ giúp & FAQ');
      expect(AppTranslations.tr('select_language', 'vi'), 'Chọn ngôn ngữ');
      expect(AppTranslations.tr('customize_appearance', 'vi'), 'Tùy chỉnh giao diện');
      expect(AppTranslations.tr('theme_light', 'vi'), contains('sáng'));
      expect(AppTranslations.tr('theme_dark', 'vi'), contains('tối'));
    });

    test('Dịch chính xác các mục trong Cài đặt & Trang cá nhân sang English', () {
      expect(AppTranslations.tr('my_profile', 'en'), 'My Profile');
      expect(AppTranslations.tr('language', 'en'), 'Language');
      expect(AppTranslations.tr('appearance', 'en'), 'Appearance');
      expect(AppTranslations.tr('logout', 'en'), 'Log Out');
      expect(AppTranslations.tr('help_faq', 'en'), 'Help Center & FAQ');
      expect(AppTranslations.tr('select_language', 'en'), 'Select Language');
      expect(AppTranslations.tr('customize_appearance', 'en'), 'Customize Appearance');
      expect(AppTranslations.tr('theme_light', 'en'), contains('Light'));
      expect(AppTranslations.tr('theme_dark', 'en'), contains('Dark'));
    });

    test('Fallback an toàn khi truyền khóa không tồn tại hoặc ngôn ngữ không hỗ trợ', () {
      expect(AppTranslations.tr('unknown_key_xyz', 'vi'), 'unknown_key_xyz');
      expect(AppTranslations.tr('unknown_key_xyz', 'en'), 'unknown_key_xyz');
      expect(AppTranslations.tr('my_profile', 'fr'), 'Trang cá nhân'); // Fallback về Tiếng Việt
    });

    test('Hỗ trợ dịch Bottom Navigation Bar Tabs (Renter & Host)', () {
      expect(AppTranslations.tr('nav_home', 'vi'), 'Trang chủ');
      expect(AppTranslations.tr('nav_home', 'en'), 'Home');
      expect(AppTranslations.tr('nav_messages', 'vi'), 'Tin nhắn');
      expect(AppTranslations.tr('nav_messages', 'en'), 'Messages');
      expect(AppTranslations.tr('nav_profile', 'vi'), 'Cá nhân');
      expect(AppTranslations.tr('nav_profile', 'en'), 'Profile');
      expect(AppTranslations.tr('nav_management', 'vi'), 'Quản lý');
      expect(AppTranslations.tr('nav_management', 'en'), 'Management');
      expect(AppTranslations.tr('nav_create', 'vi'), 'Tạo mới');
      expect(AppTranslations.tr('nav_create', 'en'), 'Create');
      expect(AppTranslations.tr('nav_general_info', 'en'), 'General');
      expect(AppTranslations.tr('nav_tenant_mgmt', 'en'), 'Tenants');
      expect(AppTranslations.tr('nav_finance_mgmt', 'en'), 'Finance');
      expect(AppTranslations.tr('nav_back', 'en'), 'Back');
    });
  });

  group('2. AppTheme - Tối ưu màu sắc Chuyển đổi Tối / Sáng (Dark & Light Theme)', () {
    test('Light Theme có độ sáng chuẩn Brightness.light và màu nền dịu mắt', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.cardColor, isNotNull);
      expect(theme.scaffoldBackgroundColor, isNotNull);
    });

    test('Dark Theme có độ sáng chuẩn Brightness.dark và màu nền bóng bẩy, cao cấp', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      // Nền tối chuẩn Graphite dark cao cấp
      expect(theme.scaffoldBackgroundColor, const Color(0xFF111827));
      expect(theme.cardColor, const Color(0xFF1F2937));
      expect(theme.colorScheme.surface, const Color(0xFF1F2937));
    });
  });

  group('3. AppThemeModeNotifier & Controller Synchronization', () {
    test('AppThemeModeNotifier khởi tạo và đổi sang Dark / System / Light', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appThemeModeProvider), ThemeMode.light);

      await container.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(container.read(appThemeModeProvider), ThemeMode.dark);
      expect(container.read(appThemeModeProvider.notifier).displayName, 'Tối');

      await container.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.system);
      expect(container.read(appThemeModeProvider), ThemeMode.system);
      expect(container.read(appThemeModeProvider.notifier).displayName, 'Hệ thống');

      await container.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.light);
      expect(container.read(appThemeModeProvider), ThemeMode.light);
      expect(container.read(appThemeModeProvider.notifier).displayName, 'Sáng');
    });

    test('appThemeControllerProvider đồng bộ với appThemeModeProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      final controllerState = await container.read(appThemeControllerProvider.future);
      expect(controllerState.mode, ThemeMode.dark);
      expect(controllerState.label, 'Tối');

      // Đổi từ AppThemeController ngược lại
      await container.read(appThemeControllerProvider.notifier).setMode(ThemeMode.light);
      expect(container.read(appThemeModeProvider), ThemeMode.light);
    });
  });
}
