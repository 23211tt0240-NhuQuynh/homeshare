import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';

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
    final mode = ref.watch(appThemeModeProvider);
    return AppThemeState(mode: mode);
  }

  Future<void> setMode(ThemeMode mode) async {
    await ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
    state = AsyncData(AppThemeState(mode: mode));
  }
}

final appThemeControllerProvider =
    AsyncNotifierProvider<AppThemeController, AppThemeState>(
      AppThemeController.new,
    );
