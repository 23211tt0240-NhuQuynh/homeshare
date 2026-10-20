<<<<<<< HEAD
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
=======
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWelcomeDialog();
    });
  }

  Future<void> _showWelcomeDialog() async {
    var adminName = '';
    try {
      final profile = await ref.read(userProfileProvider.future);
      final displayName = profile?.displayName.trim() ?? '';
      if (displayName.isNotEmpty && displayName != 'Người dùng HomeShare') {
        adminName = displayName;
      } else {
        final email = profile?.email.trim() ?? '';
        if (email.contains('@')) adminName = email.split('@').first;
      }
    } catch (error) {
      debugPrint('Không tải được tên admin cho lời chào: $error');
    }
    if (adminName.isEmpty) adminName = 'Admin HomeShare';
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCEAF5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF398FC0).withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6FC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  color: Color(0xFF71B9DA),
                  size: 25,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Have a nice day, $adminName!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF69AFCF),
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Chúc $adminName một ngày làm việc thật vui nhé!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7A8798),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF287AA8),
                    backgroundColor: const Color(0xFFEAF6FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text(
                    'Bắt đầu nào',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }

  void _onSelectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final size = MediaQuery.sizeOf(context);
    final useNavigationRail = size.width >= 700 || size.width > size.height;
    final List<Widget> screens = [
=======
    final screens = [
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      AdminDashboardScreen(
        onNavigateToOrders: () => _onSelectTab(2),
        onNavigateToPosts: () => _onSelectTab(1),
        onNavigateToHistory: () => _onSelectTab(3),
      ),
      const AdminPostsScreen(),
      const AdminOrdersScreen(),
      const AdminHistoryScreen(),
    ];

<<<<<<< HEAD
    final pages = CustomErrorTabScope(
      child: IndexedStack(index: _currentIndex, children: screens),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF398FC0),
          secondary: const Color(0xFF89CFF0),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F9FF),
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF17324D),
          elevation: 0,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          selectedIconTheme: IconThemeData(color: Color(0xFF398FC0)),
          unselectedIconTheme: IconThemeData(color: Color(0xFF7890A4)),
          indicatorColor: Color(0xFFE3F3FB),
          selectedLabelTextStyle: TextStyle(
            color: Color(0xFF287AA8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: Color(0xFF7890A4),
            fontSize: 11,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9FF),
        body: Stack(
          children: [
            const Positioned(
              right: 24,
              bottom: 20,
              child: IgnorePointer(
                child: Opacity(
                  opacity: .5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.home_work_rounded,
                        size: 78,
                        color: Color(0xFFD6EDF9),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'HomeShare',
                        style: TextStyle(
                          color: Color(0xFFD6EDF9),
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (useNavigationRail)
              Row(
                children: [
                  NavigationRail(
                    backgroundColor: Colors.white,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _onSelectTab,
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: -.65,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.bar_chart_rounded),
                        selectedIcon: Icon(Icons.bar_chart_rounded),
                        label: Text('Tổng quan'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.apartment_rounded),
                        selectedIcon: Icon(Icons.apartment_rounded),
                        label: Text('Bài đăng'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_rounded),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: Text('Quản lý đơn'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_rounded),
                        selectedIcon: Icon(Icons.history_rounded),
                        label: Text('Lịch sử'),
                      ),
                    ],
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFDCEAF5),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: pages,
                      ),
                    ),
                  ),
                ],
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: pages,
                ),
              ),
          ],
        ),
        bottomNavigationBar: useNavigationRail
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFDCEAF5), width: 1.0),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
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
                          label: 'Bài đăng',
                        ),
                        // Lồng StreamBuilder
                        StreamBuilder<QuerySnapshot>(
                          stream: () {
                            try {
                              return FirebaseFirestore.instance
                                  .collection('bookings')
                                  .where('status', isEqualTo: 'disburse')
                                  .snapshots();
                            } catch (_) {
                              return const Stream<QuerySnapshot>.empty();
                            }
                          }(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _buildNavItem(
                              index: 2,
                              icon: Icons.receipt_long_rounded,
                              label: 'Quản lý đơn',
                              badgeCount: count,
                            );
                          },
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
=======
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
<<<<<<< HEAD
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF398FC0);
    const inactiveColor = Color(0xFF667085);
=======
    bool hasBadge = false,
  }) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF1E60FF);
    const inactiveColor = Color(0xFF64748B);
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

    return InkWell(
      onTap: () => _onSelectTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
<<<<<<< HEAD
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
=======
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                if (badgeCount > 0)
=======
                if (hasBadge)
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
<<<<<<< HEAD
                        color: Color(0xFFD92D20),
=======
                        color: Color(0xFF1E60FF),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
=======
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.1,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              ),
            ),
            const SizedBox(height: 2),
            if (isSelected)
              Container(
<<<<<<< HEAD
                width: 16,
=======
                width: 18,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD

class CustomErrorTabScope extends StatefulWidget {
  final Widget child;

  const CustomErrorTabScope({super.key, required this.child});

  @override
  State<CustomErrorTabScope> createState() => _CustomErrorTabScopeState();
}

class _CustomErrorTabScopeState extends State<CustomErrorTabScope> {
  ErrorWidgetBuilder? _previousBuilder;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFFFEF3F2),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Color(0xFFD92D20),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'LỖI DỰNG GIAO DIỆN (LAYOUT ERROR)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475467),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };
  }

  @override
  void dispose() {
    if (_previousBuilder != null) {
      ErrorWidget.builder = _previousBuilder!;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
