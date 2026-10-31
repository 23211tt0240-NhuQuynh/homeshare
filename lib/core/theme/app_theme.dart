import 'package:flutter/material.dart';
import 'graphite_theme.dart';
import 'phong_sang_theme.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => PhongSangTheme.light;

  static ThemeData get darkTheme => GraphiteTheme.dark;
}
