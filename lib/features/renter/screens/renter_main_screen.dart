import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../home/screens/home_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import 'renter_dashboard_screen.dart';
import 'roommate_community_screen.dart';
import 'create_roommate_post_screen.dart';

class RenterBottomNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final renterBottomNavIndexProvider = NotifierProvider<RenterBottomNavIndexNotifier, int>(RenterBottomNavIndexNotifier.new);

class RenterMainScreen extends ConsumerStatefulWidget {
  const RenterMainScreen({super.key});

  @override
  ConsumerState<RenterMainScreen> createState() => _RenterMainScreenState();
}

class _RenterMainScreenState extends ConsumerState<RenterMainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
    });
  }

  Brightness _resolvedBrightness() {
    final mode =
        ref.watch(appThemeControllerProvider).value?.mode ?? ThemeMode.light;
    switch (mode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _resolvedBrightness();
    AppColors.bind(brightness);
    final currentIndex = ref.watch(renterBottomNavIndexProvider);
    final currentLang = ref.watch(appLanguageProvider);
    final colors = AppColors.of(context);
    // Không const — IndexedStack bỏ qua widget identical khi đổi theme.
    final screens = [
      RenterDashboardScreen(),
      ChatListScreen(),
      CreateRoommatePostScreen(),
      RoommateCommunityScreen(),
      HomeScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: colors.surface,
          elevation: 0,
          selectedItemColor: colors.primary,
          unselectedItemColor: colors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
            ref.read(renterBottomNavIndexProvider.notifier).setIndex(index);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: AppTranslations.tr('nav_home', currentLang),
            ),
            BottomNavigationBarItem(
              icon: Badge(
                smallSize: 8,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.chat_bubble_outline),
              ),
              activeIcon: Badge(
                smallSize: 8,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.chat_bubble),
              ),
              label: AppTranslations.tr('nav_messages', currentLang),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, color: colors.primary, size: 28),
              activeIcon: Icon(Icons.add_circle, color: colors.primary, size: 28),
              label: AppTranslations.tr('nav_post', currentLang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.group_outlined),
              activeIcon: const Icon(Icons.group),
              label: AppTranslations.tr('nav_roommate', currentLang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: AppTranslations.tr('nav_profile', currentLang),
            ),
          ],
        ),
      ),
    );
  }
}
