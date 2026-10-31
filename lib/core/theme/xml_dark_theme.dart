import 'package:flutter/material.dart';

class XmlDarkTheme {
  final String id;
  final String name;
  final String subtitle;
  final Color paper;
  final Color card;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color price;
  final Color priceSoft;
  final Color line;
  final Color hold;
  final Color live;
  final Color empty;
  final Color bezel;
  final Color alt;
  final Color onAlt;

  const XmlDarkTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.price,
    required this.priceSoft,
    required this.line,
    required this.hold,
    required this.live,
    required this.empty,
    required this.bezel,
    required this.alt,
    required this.onAlt,
  });

  ThemeData toThemeData() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: paper,
      cardColor: card,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: card,
      ),
    );
  }
}

class XmlDarkThemeParser {
  static Color parseHex(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    return Color(int.parse(clean, radix: 16));
  }

  static List<XmlDarkTheme> parse(String xmlContent) {
    final list = <XmlDarkTheme>[];
    final themeRegex = RegExp(
      r'<theme\s+id="([^"]+)"\s+name="([^"]+)"\s+subtitle="([^"]*)">(.*?)</theme>',
      dotAll: true,
    );
    final colorRegex = RegExp(r'<color\s+name="([^"]+)">([^<]+)</color>');

    for (final match in themeRegex.allMatches(xmlContent)) {
      final id = match.group(1)!;
      final name = match.group(2)!;
      final subtitle = match.group(3) ?? '';
      final body = match.group(4)!;

      final colorMap = <String, Color>{};
      for (final cMatch in colorRegex.allMatches(body)) {
        final cName = cMatch.group(1)!;
        final cHex = cMatch.group(2)!.trim();
        colorMap[cName] = parseHex(cHex);
      }

      list.add(XmlDarkTheme(
        id: id,
        name: name,
        subtitle: subtitle,
        paper: colorMap['paper'] ?? const Color(0xFF111827),
        card: colorMap['card'] ?? const Color(0xFF1F2937),
        ink: colorMap['ink'] ?? const Color(0xFFF1F5F9),
        muted: colorMap['muted'] ?? const Color(0xFF94A3B8),
        accent: colorMap['accent'] ?? const Color(0xFF3B82F6),
        accentSoft: colorMap['accentSoft'] ?? const Color(0xFF1E3A8A),
        onAccent: colorMap['onAccent'] ?? const Color(0xFFF8FAFC),
        price: colorMap['price'] ?? const Color(0xFFF1F5F9),
        priceSoft: colorMap['priceSoft'] ?? const Color(0xFF1F2937),
        line: colorMap['line'] ?? const Color(0xFF334155),
        hold: colorMap['hold'] ?? const Color(0xFFF59E0B),
        live: colorMap['live'] ?? const Color(0xFF22C55E),
        empty: colorMap['empty'] ?? const Color(0xFF94A3B8),
        bezel: colorMap['bezel'] ?? const Color(0xFF111827),
        alt: colorMap['alt'] ?? const Color(0xFFCBD5E1),
        onAlt: colorMap['onAlt'] ?? const Color(0xFF000000),
      ));
    }

    return list;
  }
}

