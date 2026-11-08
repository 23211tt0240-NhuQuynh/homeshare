import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/localization/app_translations.dart';
import 'package:home_share/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. AppTranslations - Ngôn ngữ & Dịch thuật Anh/Việt', () {
    test('Dịch chính xác các mục trong Cài đặt & Trang cá nhân sang Tiếng Việt', () {
      expect(AppTranslations.tr('my_profile', 'vi'), 'Trang cá nhân');
      expect(AppTranslations.tr('language', 'vi'), 'Ngôn ngữ');
      expect(AppTranslations.tr('logout', 'vi'), 'Đăng xuất');
      expect(AppTranslations.tr('help_faq', 'vi'), 'Trung tâm trợ giúp & FAQ');
      expect(AppTranslations.tr('select_language', 'vi'), 'Chọn ngôn ngữ');
    });

    test('Dịch chính xác các mục trong Cài đặt & Trang cá nhân sang English', () {
      expect(AppTranslations.tr('my_profile', 'en'), 'My Profile');
      expect(AppTranslations.tr('language', 'en'), 'Language');
      expect(AppTranslations.tr('logout', 'en'), 'Log Out');
      expect(AppTranslations.tr('help_faq', 'en'), 'Help Center & FAQ');
      expect(AppTranslations.tr('select_language', 'en'), 'Select Language');
    });

    test('Fallback an toàn khi truyền khóa không tồn tại hoặc ngôn ngữ không hỗ trợ', () {
      expect(AppTranslations.tr('unknown_key_xyz', 'vi'), 'unknown_key_xyz');
      expect(AppTranslations.tr('unknown_key_xyz', 'en'), 'unknown_key_xyz');
      expect(AppTranslations.tr('my_profile', 'fr'), 'Trang cá nhân');
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

  group('2. AppTheme - Giao diện sáng', () {
    test('Light Theme có độ sáng chuẩn Brightness.light và màu nền dịu mắt', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.cardColor, isNotNull);
      expect(theme.scaffoldBackgroundColor, isNotNull);
    });
  });
}
