import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/app_colors.dart';
import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/core/theme/app_theme_controller.dart';
import 'package:home_share/core/theme/graphite_theme.dart';
import 'package:home_share/core/theme/phong_sang_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Graphite matches sample 3 tokens', () {
    expect(GraphiteColors.paper, const Color(0xFF111827));
    expect(GraphiteColors.card, const Color(0xFF1F2937));
    expect(GraphiteColors.ink, const Color(0xFFF1F5F9));
    expect(GraphiteColors.muted, const Color(0xFF94A3B8));
    expect(GraphiteColors.accent, const Color(0xFF3B82F6));
    expect(GraphiteColors.accentSoft, const Color(0xFF1E3A8A));
    expect(GraphiteColors.onAccent, const Color(0xFFF8FAFC));
    expect(GraphiteColors.line, const Color(0xFF334155));
    expect(GraphiteColors.hold, const Color(0xFFF59E0B));
    expect(GraphiteColors.live, const Color(0xFF22C55E));
    expect(GraphiteColors.danger, const Color(0xFFEF4444));
  });

  test('Light theme stays Phong Sang, dark theme is Graphite', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.lightTheme.scaffoldBackgroundColor, PhongSangColors.paper);
    expect(AppTheme.lightTheme.colorScheme.primary, PhongSangColors.accent);

    final dark = AppTheme.darkTheme;
    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, GraphiteColors.paper);
    expect(dark.colorScheme.primary, GraphiteColors.accent);
    expect(dark.colorScheme.surface, GraphiteColors.card);
    expect(dark.colorScheme.primary, GraphiteTheme.dark.colorScheme.primary);
  });

  test('AppPalette switches by brightness', () {
    expect(AppPalette.light.primary, PhongSangColors.accent);
    expect(AppPalette.light.background, PhongSangColors.paper);
    expect(AppPalette.graphite.primary, GraphiteColors.accent);
    expect(AppPalette.graphite.background, GraphiteColors.paper);
    expect(AppPalette.graphite.surface, GraphiteColors.card);
  });

  test('Theme mode labels for personal tab', () {
    expect(const AppThemeState(mode: ThemeMode.light).label, 'Sáng');
    expect(const AppThemeState(mode: ThemeMode.dark).label, 'Tối');
    expect(const AppThemeState(mode: ThemeMode.system).label, 'Hệ thống');
  });
}
