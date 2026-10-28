import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'phong_sang_theme.dart';

/// Lớp đại diện AppTheme chính thức của ứng dụng, kế thừa toàn diện từ PhongSangTheme
class AppTheme {
  const AppTheme._();

  /// Trả về theme sáng chuẩn moodboard "Phòng sáng" (phong_sang_theme.dart)
  /// Trả về theme sáng chuẩn moodboard "Phòng sáng" kết hợp tinh hoa thẩm mỹ hiện đại
  static ThemeData get lightTheme {
    final baseLight = PhongSangTheme.light;
    return baseLight.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      canvasColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      colorScheme: baseLight.colorScheme.copyWith(
        surface: Colors.white,
        primary: const Color(0xFF006948),
        secondary: const Color(0xFF155EEF),
        outline: const Color(0xFFE2E8F0),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  /// Trả về theme tối cao cấp (Deep Obsidian Midnight & Luminous Emerald)
  static ThemeData get darkTheme {
    const bg = Color(0xFF0B0F17); // Obsidian Midnight sang trọng
    const cardBg = Color(0xFF151C28); // Elevated Slate-Navy card
    const textLight = Color(0xFFF8FAFC); // Slate-50 trắng tinh tế
    const textMuted = Color(0xFF94A3B8); // Slate-400
    const primaryAccent = Color(0xFF10B981); // Emerald ngọc lục bảo rực rỡ
    const primaryContainer = Color(0xFF064E3B);
    const lineBorder = Color(0xFF243044); // Viền mảnh tinh tế

    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: textLight,
      displayColor: textLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: lineBorder,
      cardColor: cardBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        onPrimary: Color(0xFF0B0F17),
        primaryContainer: primaryContainer,
        onPrimaryContainer: Color(0xFFD1FAE5),
        secondary: Color(0xFF38BDF8),
        onSecondary: Color(0xFF0B0F17),
        surface: cardBg,
        onSurface: textLight,
        onSurfaceVariant: textMuted,
        outline: lineBorder,
        outlineVariant: lineBorder,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lineBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: base,
      primaryTextTheme: base,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primaryAccent,
        unselectedItemColor: textMuted,
      ),
    );
  }
}
