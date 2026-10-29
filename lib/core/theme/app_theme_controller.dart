import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'app_theme_mode';
const _legacyPrefKey = 'app_theme_id';

class AppThemeState {
  const AppThemeState({required this.mode});

  final ThemeMode mode;

  String get label {
    switch (mode) {
      case ThemeMode.dark:
        return 'Tối';
      case ThemeMode.system:
        return 'Hệ thống';
      case ThemeMode.light:
        return 'Sáng';
    }
  }
}

class AppThemeController extends AsyncNotifier<AppThemeState> {
  @override
  Future<AppThemeState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey) ?? prefs.getString(_legacyPrefKey);
    return AppThemeState(mode: _parse(raw));
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _encode(mode));
    state = AsyncData(AppThemeState(mode: mode));
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      default:
        // Pref cũ từng lưu id XML dark theme.
        if (raw != null && raw.isNotEmpty && raw != 'light') {
          return ThemeMode.dark;
        }
        return ThemeMode.light;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}

final appThemeControllerProvider =
    AsyncNotifierProvider<AppThemeController, AppThemeState>(
      AppThemeController.new,
    );
