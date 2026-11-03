import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/theme/xml_dark_theme.dart';

void main() {
  final xml = File('assets/themes/dark_themes.xml').readAsStringSync();

  test('catalog XML có đúng 5 theme tối để chọn', () {
    final themes = XmlDarkThemeParser.parse(xml);
    expect(themes.map((theme) => theme.id).toList(), [
      'midnight_navy',
      'oled_graphite',
      'forest_night',
      'amber_ember',
      'plum_night',
    ]);
    expect(themes.map((theme) => theme.name).toList(), [
      'Đêm xanh than',
      'Graphite OLED',
      'Rừng đêm',
      'Than hổ phách',
      'Tím đêm',
    ]);
  });

  test('mỗi theme tối có accent và nền khác nhau, brightness dark', () {
    final themes = XmlDarkThemeParser.parse(xml);
    final accents = themes.map((theme) => theme.accent.toARGB32()).toSet();
    final papers = themes.map((theme) => theme.paper.toARGB32()).toSet();
    expect(accents.length, 5);
    expect(papers.length, 5);
    for (final theme in themes) {
      expect(theme.toThemeData().brightness, Brightness.dark);
      expect(theme.toThemeData().scaffoldBackgroundColor, theme.paper);
      expect(theme.toThemeData().colorScheme.primary, theme.accent);
    }
  });

  test('parseHex đọc #RRGGBB', () {
    expect(XmlDarkThemeParser.parseHex('#0B1220'), const Color(0xFF0B1220));
    expect(XmlDarkThemeParser.parseHex('#4C8DFF'), const Color(0xFF4C8DFF));
  });
}
