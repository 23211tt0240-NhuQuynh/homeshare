import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_dashboard_screen.dart';
import 'admin_posts_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_history_screen.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const AdminMainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onSelectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(
        onNavigateToOrders: () => _onSelectTab(2),
        onNavigateToPosts: () => _onSelectTab(1),
        onNavigateToHistory: () => _onSelectTab(3),
      ),
      const AdminPostsScreen(),
      const AdminOrdersScreen(),
      const AdminHistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: const Color(0xFFEAECF0), width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.bar_chart_rounded,
                  label: 'Tổng quan',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.apartment_rounded,
                  label: 'BÀI ĐĂNG',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.receipt_long_rounded,
                  label: 'Quản lý đơn',
                  hasBadge: true,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.history_rounded,
                  label: 'Lịch sử',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    bool hasBadge = false,
  }) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF1E60FF);
    const inactiveColor = Color(0xFF64748B);

    return InkWell(
      onTap: () => _onSelectTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (hasBadge)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E60FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 2),
            if (isSelected)
              Container(
                width: 18,
                height: 2.5,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(height: 2.5),
          ],
        ),
      ),
    );
  }
}
