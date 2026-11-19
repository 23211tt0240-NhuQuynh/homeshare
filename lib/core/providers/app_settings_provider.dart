import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
