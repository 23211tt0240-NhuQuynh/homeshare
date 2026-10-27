import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'phong_sang_theme.dart';

/// Lớp đại diện AppTheme chính thức của ứng dụng, kế thừa toàn diện từ PhongSangTheme
class AppTheme {
  const AppTheme._();

  /// Trả về theme sáng chuẩn moodboard "Phòng sáng" (phong_sang_theme.dart)
  static ThemeData get lightTheme => PhongSangTheme.light;

  /// Trả về theme tối chuẩn Material 3
  static ThemeData get darkTheme {
    const bg = Color(0xFF0F172A); // slate-900
    const cardBg = Color(0xFF1E293B); // slate-800
    const textLight = Color(0xFFF8FAFC); // slate-50
    const textMuted = Color(0xFF94A3B8); // slate-400
    const primaryAccent = Color(0xFF38BDF8); // sky-400
    const lineBorder = Color(0xFF334155); // slate-700

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
        onPrimary: Color(0xFF0F172A),
        primaryContainer: Color(0xFF0369A1),
        onPrimaryContainer: Colors.white,
        secondary: Color(0xFF60A5FA),
        onSecondary: Color(0xFF0F172A),
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
      textTheme: base,
      primaryTextTheme: base,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
    );
  }
}
