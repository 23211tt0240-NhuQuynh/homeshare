import 'package:flutter/material.dart';
import '../theme/graphite_theme.dart';
import '../theme/phong_sang_theme.dart';

/// Palette theo theme đang chạy: sáng = Phòng Sáng, tối = Graphite.
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryContainer,
    required this.primarySurface,
    required this.textDark,
    required this.textMuted,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.danger,
    required this.dangerContainer,
    required this.warning,
    required this.warningContainer,
    required this.success,
    required this.isDark,
  });

  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryContainer;
  final Color primarySurface;
  final Color textDark;
  final Color textMuted;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color danger;
  final Color dangerContainer;
  final Color warning;
  final Color warningContainer;
  final Color success;
  final bool isDark;

  Color get textPrimary => textDark;
  Color get textSecondary => textMuted;
  Color get onPrimary => const Color(0xFFF8FAFC);

  static const light = AppPalette(
    primary: PhongSangColors.accent,
    primaryLight: Color(0xFF2E90FA),
    primaryDark: Color(0xFF175CD3),
    primaryContainer: PhongSangColors.accentSoft,
    primarySurface: Color(0xFFE8F5E9),
    textDark: PhongSangColors.ink,
    textMuted: PhongSangColors.muted,
    background: PhongSangColors.paper,
    surface: PhongSangColors.card,
    surfaceVariant: PhongSangColors.priceSoft,
    border: PhongSangColors.line,
    danger: Color(0xFFD92D20),
    dangerContainer: Color(0xFFFEE4E2),
    warning: PhongSangColors.hold,
    warningContainer: Color(0xFFFEF0C7),
    success: PhongSangColors.live,
    isDark: false,
  );

  static const graphite = AppPalette(
    primary: GraphiteColors.accent,
    primaryLight: GraphiteColors.primaryLight,
    primaryDark: GraphiteColors.primaryDark,
    primaryContainer: GraphiteColors.accentSoft,
    primarySurface: GraphiteColors.successContainer,
    textDark: GraphiteColors.ink,
    textMuted: GraphiteColors.muted,
    background: GraphiteColors.paper,
    surface: GraphiteColors.card,
    surfaceVariant: GraphiteColors.priceSoft,
    border: GraphiteColors.line,
    danger: GraphiteColors.danger,
    dangerContainer: GraphiteColors.dangerContainer,
    warning: GraphiteColors.warning,
    warningContainer: GraphiteColors.warningContainer,
    success: GraphiteColors.success,
    isDark: true,
  );
}

/// Màu app theo theme hiện tại. Gọi [bind] khi MaterialApp đổi sáng/tối.
class AppColors {
  static AppPalette palette = AppPalette.light;

  static void bind(Brightness brightness) {
    palette = brightness == Brightness.dark
        ? AppPalette.graphite
        : AppPalette.light;
  }

  static bool get isDark => palette.isDark;

  static Color get primary => palette.primary;
  static Color get primaryLight => palette.primaryLight;
  static Color get primaryDark => palette.primaryDark;
  static Color get primaryContainer => palette.primaryContainer;
  static Color get primarySurface => palette.primarySurface;

  static Color get textDark => palette.textDark;
  static Color get textPrimary => palette.textDark;
  static Color get textSecondary => palette.textMuted;
  static Color get textMuted => palette.textMuted;

  static Color get background => palette.background;
  static Color get surface => palette.surface;
  static Color get surfaceVariant => palette.surfaceVariant;
  static Color get priceSoft => palette.surfaceVariant;
  static Color get border => palette.border;
  static Color get borderDark => palette.textDark;
  static Color get noteHighlight =>
      palette.isDark ? GraphiteColors.noteHighlight : const Color(0xFFFEFFDD);

  static Color get hold => palette.isDark ? GraphiteColors.hold : PhongSangColors.hold;
  static Color get live => palette.isDark ? GraphiteColors.live : PhongSangColors.live;
  static Color get empty => palette.textMuted;
  static Color get price => palette.textDark;

  static Color get danger => palette.danger;
  static Color get dangerContainer => palette.dangerContainer;
  static Color get warning => palette.warning;
  static Color get warningContainer => palette.warningContainer;
  static Color get info => palette.primary;
  static Color get infoContainer => palette.primaryContainer;
  static Color get success => palette.success;
  static Color get successContainer =>
      palette.isDark ? GraphiteColors.successContainer : const Color(0xFFD1FADF);

  static LinearGradient get photoA =>
      palette.isDark ? GraphiteColors.photoA : PhongSangColors.photoA;
  static LinearGradient get photoB =>
      palette.isDark ? GraphiteColors.photoB : PhongSangColors.photoB;

  static Color get onPrimary => palette.onPrimary;

  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppPalette.graphite
        : AppPalette.light;
  }
}
