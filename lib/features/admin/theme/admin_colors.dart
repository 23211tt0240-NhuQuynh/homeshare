import 'package:flutter/material.dart';

/// Palette admin cố định sáng — không áp Graphite / dark theme.
class AdminColors {
  static bool get isDark => false;

  static Color get paper => const Color(0xFFF4F9FF);
  static Color get card => const Color(0xFFFFFFFF);
  static Color get ink => const Color(0xFF101828);
  static Color get title => const Color(0xFF17324D);
  static Color get muted => const Color(0xFF667085);
  static Color get mutedStrong => const Color(0xFF344054);
  static Color get accent => const Color(0xFF398FC0);
  static Color get accentDark => const Color(0xFF287AA8);
  static Color get accentLight => const Color(0xFF89CFF0);
  static Color get accentSoft => const Color(0xFFE9F5FC);
  static Color get border => const Color(0xFFDCEAF5);
  static Color get watermark => const Color(0xFFD6EDF9);
  static Color get navInactive => const Color(0xFF7890A4);

  /// Chữ nhấn: luôn xanh admin (giao diện sáng).
  static Color get accentText => accent;

  static Color get danger => const Color(0xFFD92D20);
  static Color get dangerInk => const Color(0xFFB42318);
  static Color get dangerContainer => const Color(0xFFFEF3F2);

  static Color get success => const Color(0xFF12B76A);
  static Color get successInk => const Color(0xFF027A48);
  static Color get successContainer => const Color(0xFFECFDF3);

  static Color get warning => const Color(0xFFF79009);
  static Color get warningInk => const Color(0xFFB54708);
  static Color get warningContainer => const Color(0xFFFEF0C7);

  static Color get purple => const Color(0xFF6941C6);
  static Color get purpleContainer => const Color(0xFFF9F5FF);

  /// Chip "HỆ THỐNG": mực trên nền sáng.
  static Color get systemBadgeBg => ink;
  static Color get systemBadgeFg => const Color(0xFFFFFFFF);

  static Color get chipIdle => accentSoft;
  static Color get chipIdleLabel => muted;
  static Color get disabledFill => const Color(0xFFE4E7EC);
  static Color get onAccent => const Color(0xFFFFFFFF);
}
