import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Palette riêng của admin: sáng = đúng thiết kế gốc, tối = cùng bố cục trên nền navy.
class AdminColors {
  static bool get isDark => AppColors.isDark;

  static Color get paper =>
      isDark ? const Color(0xFF0B1822) : const Color(0xFFF4F9FF);
  static Color get card =>
      isDark ? const Color(0xFF132333) : const Color(0xFFFFFFFF);
  static Color get ink =>
      isDark ? const Color(0xFFE7F3FA) : const Color(0xFF101828);
  static Color get title =>
      isDark ? const Color(0xFFE7F3FA) : const Color(0xFF17324D);
  static Color get muted =>
      isDark ? const Color(0xFF93AFC0) : const Color(0xFF667085);
  static Color get mutedStrong =>
      isDark ? const Color(0xFFC5D6E2) : const Color(0xFF344054);
  static Color get accent => const Color(0xFF398FC0);
  static Color get accentDark => const Color(0xFF287AA8);
  static Color get accentLight =>
      isDark ? const Color(0xFF71B9DA) : const Color(0xFF89CFF0);
  static Color get accentSoft =>
      isDark ? const Color(0xFF163A4F) : const Color(0xFFE9F5FC);
  static Color get border =>
      isDark ? const Color(0xFF2A4A5E) : const Color(0xFFDCEAF5);
  static Color get watermark =>
      isDark ? const Color(0xFF1A3344) : const Color(0xFFD6EDF9);
  static Color get navInactive =>
      isDark ? const Color(0xFF8BA3B5) : const Color(0xFF7890A4);

  static Color get danger => const Color(0xFFD92D20);
  static Color get dangerInk =>
      isDark ? const Color(0xFFFDA29B) : const Color(0xFFB42318);
  static Color get dangerContainer =>
      isDark ? const Color(0xFF3A1D1C) : const Color(0xFFFEF3F2);

  static Color get success => const Color(0xFF12B76A);
  static Color get successInk =>
      isDark ? const Color(0xFF6CE9A6) : const Color(0xFF027A48);
  static Color get successContainer =>
      isDark ? const Color(0xFF143326) : const Color(0xFFECFDF3);

  static Color get warning => const Color(0xFFF79009);
  static Color get warningInk =>
      isDark ? const Color(0xFFFEDF89) : const Color(0xFFB54708);
  static Color get warningContainer =>
      isDark ? const Color(0xFF3A2A12) : const Color(0xFFFEF0C7);

  static Color get purple => const Color(0xFF6941C6);
  static Color get purpleContainer =>
      isDark ? const Color(0xFF2A1F3D) : const Color(0xFFF9F5FF);

  /// Chip "HỆ THỐNG": sáng = mực trên trắng, tối = chữ sáng trên navy.
  static Color get systemBadgeBg =>
      isDark ? const Color(0xFF1E3A4C) : ink;
  static Color get systemBadgeFg =>
      isDark ? ink : const Color(0xFFFFFFFF);
}
