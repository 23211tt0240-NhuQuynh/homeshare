import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/providers/app_settings_provider.dart';
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
  final List<Widget> _screens = const [
    RenterDashboardScreen(),
    ChatListScreen(),
    CreateRoommatePostScreen(),
    RoommateCommunityScreen(),
    HomeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(renterBottomNavIndexProvider);
    final currentLang = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C28) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF243044) : const Color(0xFFE5EBF1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF151C28) : Colors.white,
          elevation: 0,
          selectedItemColor: isDark ? const Color(0xFF10B981) : AppColors.primary,
          unselectedItemColor: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
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
              icon: const Badge(
                smallSize: 8,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.chat_bubble_outline),
              ),
              activeIcon: const Badge(
                smallSize: 8,
                backgroundColor: AppColors.danger,
                child: Icon(Icons.chat_bubble),
              ),
              label: AppTranslations.tr('nav_messages', currentLang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.add_circle, color: Color(0xFF155EEF), size: 28),
              activeIcon: const Icon(Icons.add_circle, color: Color(0xFF155EEF), size: 28),
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
