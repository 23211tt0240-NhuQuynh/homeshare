import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme_controller.dart';

/// Quản lý ngôn ngữ ứng dụng: 'vi' (Tiếng Việt) hoặc 'en' (English)
class AppLanguageNotifier extends Notifier<String> {
  static const _key = 'app_language_preference';

  @override
  String build() {
    _loadFromPrefs();
    return 'vi';
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString(_key);
      if (lang != null && (lang == 'vi' || lang == 'en')) {
        state = lang;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String lang) async {
    if (state == lang) return;
    state = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, lang);
    } catch (_) {}
  }

  String get displayName => state == 'en' ? 'English' : 'Tiếng Việt';
}

final appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, String>(AppLanguageNotifier.new);

/// Quản lý giao diện: Sáng (light), Tối (dark) hoặc Theo hệ thống (system)
class AppThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';
  static const _legacyKey = 'app_theme_mode_preference';
  static ThemeMode? initialMode;

  @override
  ThemeMode build() {
    if (initialMode != null) {
      return initialMode!;
    }
    _loadFromPrefs();
    return ref.watch(appThemeControllerProvider).value?.mode ?? ThemeMode.light;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_key) ?? prefs.getString(_legacyKey);
      if (mode == 'dark') {
        state = ThemeMode.dark;
      } else if (mode == 'system') {
        state = ThemeMode.system;
      } else {
        state = ThemeMode.light;
      }
      initialMode = state;
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    initialMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString(_key, val);
      await prefs.setString(_legacyKey, val);
      await ref.read(appThemeControllerProvider.notifier).setMode(mode);
    } catch (_) {}
  }

  String get displayName {
    switch (state) {
      case ThemeMode.dark:
        return 'Tối';
      case ThemeMode.system:
        return 'Hệ thống';
      case ThemeMode.light:
        return 'Sáng';
    }
  }
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeNotifier, ThemeMode>(AppThemeModeNotifier.new);
