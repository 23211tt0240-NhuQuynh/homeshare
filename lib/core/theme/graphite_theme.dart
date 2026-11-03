import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'phong_sang_theme.dart';

/// Dark Graphite — mẫu 3. Token cùng tên Phòng Sáng.
class GraphiteColors {
  const GraphiteColors._();

  static const Color paper = Color(0xFF111827);
  static const Color ink = Color(0xFFF1F5F9);
  static const Color muted = Color(0xFF94A3B8);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentSoft = Color(0xFF1E3A8A);
  static const Color onAccent = Color(0xFFF8FAFC);
  static const Color price = Color(0xFFF1F5F9);
  static const Color priceSoft = Color(0xFF273548);
  static const Color card = Color(0xFF1F2937);
  static const Color line = Color(0xFF334155);
  static const Color hold = Color(0xFFF59E0B);
  static const Color live = Color(0xFF22C55E);
  static const Color empty = Color(0xFF94A3B8);
  static const Color bezel = Color(0xFF0F172A);
  static const Color alt = Color(0xFFCBD5E1);
  static const Color onAlt = Color(0xFF111827);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerContainer = Color(0xFF3F1212);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFF3F2E0F);
  static const Color success = Color(0xFF22C55E);
  static const Color successContainer = Color(0xFF0F3D24);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoContainer = Color(0xFF1E3A8A);
  static const Color noteHighlight = Color(0xFF3F3B12);
  static const Color primaryLight = Color(0xFF1E3A8A);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const LinearGradient photoA = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2330), Color(0xFF2A3A4C), Color(0xFF4A5F73)],
    stops: [0.0, 0.48, 1.0],
  );

  static const LinearGradient photoB = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF161D27), Color(0xFF263445), Color(0xFF51657A)],
    stops: [0.0, 0.50, 1.0],
  );
}

class GraphiteTheme {
  const GraphiteTheme._();

  static const PhongSangTokens tokens = PhongSangTokens(
    price: GraphiteColors.price,
    priceSoft: GraphiteColors.priceSoft,
    muted: GraphiteColors.muted,
    line: GraphiteColors.line,
    hold: GraphiteColors.hold,
    live: GraphiteColors.live,
    empty: GraphiteColors.empty,
    bezel: GraphiteColors.bezel,
    tagBackground: GraphiteColors.priceSoft,
    tagForeground: GraphiteColors.ink,
    badgeBackground: GraphiteColors.accentSoft,
    badgeForeground: GraphiteColors.accent,
    badgeOkBackground: GraphiteColors.accentSoft,
    badgeOkForeground: GraphiteColors.live,
    photoA: GraphiteColors.photoA,
    photoB: GraphiteColors.photoB,
    shadow: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.35),
        offset: Offset(0, 12),
        blurRadius: 28,
      ),
    ],
  );

  static ThemeData get dark {
    final base = GoogleFonts.interTextTheme().apply(
      bodyColor: GraphiteColors.ink,
      displayColor: GraphiteColors.ink,
    );
    final textTheme = base.copyWith(
      displayLarge: PhongSangText.display.copyWith(color: GraphiteColors.ink),
      headlineMedium: PhongSangText.screenTitle.copyWith(color: GraphiteColors.ink),
      titleLarge: PhongSangText.roomName.copyWith(color: GraphiteColors.ink),
      titleMedium: PhongSangText.price.copyWith(color: GraphiteColors.price),
      bodyLarge: PhongSangText.body.copyWith(color: GraphiteColors.muted),
      bodyMedium: PhongSangText.caption.copyWith(fontSize: 13, color: GraphiteColors.muted),
      bodySmall: PhongSangText.caption.copyWith(color: GraphiteColors.muted),
      labelLarge: PhongSangText.button.copyWith(color: GraphiteColors.onAccent),
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GraphiteColors.paper,
      canvasColor: GraphiteColors.paper,
      dividerColor: GraphiteColors.line,
      splashColor: GraphiteColors.accent.withValues(alpha: 0.12),
      highlightColor: GraphiteColors.accent.withValues(alpha: 0.06),
      extensions: const [tokens],
      colorScheme: const ColorScheme.dark(
        primary: GraphiteColors.accent,
        onPrimary: GraphiteColors.onAccent,
        primaryContainer: GraphiteColors.accentSoft,
        onPrimaryContainer: GraphiteColors.accent,
        secondary: GraphiteColors.alt,
        onSecondary: GraphiteColors.onAlt,
        secondaryContainer: GraphiteColors.priceSoft,
        onSecondaryContainer: GraphiteColors.ink,
        surface: GraphiteColors.card,
        onSurface: GraphiteColors.ink,
        onSurfaceVariant: GraphiteColors.muted,
        outline: GraphiteColors.line,
        outlineVariant: GraphiteColors.line,
        error: GraphiteColors.danger,
        onError: GraphiteColors.onAccent,
        shadow: GraphiteColors.paper,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: GraphiteColors.paper,
        foregroundColor: GraphiteColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: PhongSangText.roomName.copyWith(color: GraphiteColors.ink),
      ),
      cardTheme: const CardThemeData(
        color: GraphiteColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.card)),
          side: BorderSide(color: GraphiteColors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GraphiteColors.accent,
          foregroundColor: GraphiteColors.onAccent,
          disabledBackgroundColor: GraphiteColors.line,
          disabledForegroundColor: GraphiteColors.muted,
          elevation: 0,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: shape,
          textStyle: PhongSangText.button.copyWith(color: GraphiteColors.onAccent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GraphiteColors.accent,
          foregroundColor: GraphiteColors.onAccent,
          elevation: 0,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: shape,
          textStyle: PhongSangText.button.copyWith(color: GraphiteColors.onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GraphiteColors.ink,
          backgroundColor: GraphiteColors.card,
          side: const BorderSide(color: GraphiteColors.line),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: shape,
          textStyle: PhongSangText.button.copyWith(color: GraphiteColors.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GraphiteColors.accent,
          textStyle: PhongSangText.button.copyWith(color: GraphiteColors.accent),
          shape: shape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: GraphiteColors.card,
        selectedColor: GraphiteColors.accent,
        disabledColor: GraphiteColors.priceSoft,
        labelStyle: PhongSangText.label(color: GraphiteColors.ink, fontSize: 12),
        secondaryLabelStyle: PhongSangText.label(
          color: GraphiteColors.onAccent,
          fontSize: 12,
        ),
        side: const BorderSide(color: GraphiteColors.line),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.pill)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GraphiteColors.card,
        hintStyle: PhongSangText.search.copyWith(color: GraphiteColors.muted),
        labelStyle: PhongSangText.search.copyWith(color: GraphiteColors.ink),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: GraphiteColors.accent),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: GraphiteColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: GraphiteColors.accent, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: GraphiteColors.danger),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: GraphiteColors.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GraphiteColors.accent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GraphiteColors.card,
        modalBackgroundColor: GraphiteColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: GraphiteColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GraphiteColors.card,
        selectedItemColor: GraphiteColors.accent,
        unselectedItemColor: GraphiteColors.muted,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GraphiteColors.ink,
        contentTextStyle: PhongSangText.body.copyWith(color: GraphiteColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
        ),
      ),
    );
  }
}
