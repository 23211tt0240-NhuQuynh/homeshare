import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_controller.dart';
import '../theme/admin_colors.dart';

/// Nút mặt trời / mặt trăng trên AppBar admin. Cùng kích thước vòng tròn 38 với chuông.
class AdminThemeToggle extends ConsumerWidget {
  const AdminThemeToggle({
    super.key,
    this.padding = const EdgeInsets.only(right: 16),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(appThemeControllerProvider).value?.mode ?? ThemeMode.light;
    final isDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    return Padding(
      padding: padding,
      child: InkWell(
        onTap: () {
          ref.read(appThemeControllerProvider.notifier).setMode(
            isDark ? ThemeMode.light : ThemeMode.dark,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AdminColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: AdminColors.mutedStrong,
            size: 21,
          ),
        ),
      ),
    );
  }
}

