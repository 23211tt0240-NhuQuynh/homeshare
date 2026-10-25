import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/admin/screens/admin_dashboard_screen.dart';
import 'package:home_share/features/admin/screens/admin_main_screen.dart';
import 'package:home_share/features/admin/widgets/revenue_line_chart.dart';
import 'package:home_share/features/admin/widgets/revenue_bar_chart.dart';
import 'package:home_share/features/admin/widgets/admin_alert_card.dart';

void main() {
  group('Admin Dashboard & Feature Tests', () {
    testWidgets('Tc_ADMIN_DASHBOARD_01: Render AdminMainScreen with 4 bottom tabs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminMainScreen(),
          ),
        ),
      );

      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Bài đăng'), findsOneWidget);
      expect(find.text('Quản lý đơn'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
    });

    testWidgets('Tc_ADMIN_DASHBOARD_02: Metric KPI cards render correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdminDashboardScreen(),
            ),
          ),
        ),
      );

      expect(find.text('TỔNG DÒNG TIỀN'), findsOneWidget);
      expect(find.text('GIAO DỊCH THÀNH CÔNG'), findsOneWidget);
      expect(find.text('THỐNG KÊ DOANH THU'), findsOneWidget);
      expect(find.text('Tuần'), findsOneWidget);
      expect(find.text('Tháng'), findsOneWidget);
      expect(find.text('Năm'), findsOneWidget);
    });

    testWidgets('Tc_ADMIN_DASHBOARD_03: Switch time range tabs in revenue chart', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdminDashboardScreen(),
            ),
          ),
        ),
      );

      // Tap 'Tuần'
      await tester.tap(find.text('Tuần'));
      await tester.pumpAndSettle();

      expect(find.byType(RevenueLineChart), findsOneWidget);

      // Tap 'Năm'
      await tester.tap(find.text('Năm'));
      await tester.pumpAndSettle();

      expect(find.byType(RevenueBarChart), findsOneWidget);
    });

    testWidgets('Tc_ADMIN_DASHBOARD_04: AdminAlertCard displays and triggers action dialog', (tester) async {
      bool processed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAlertCard.disbursement(
              orderCode: '#DH8821',
              hostCode: 'CT0089',
              hostName: 'Đặng Thu Hà',
              amount: '4.250.000 đ',
              onProcess: () {
                processed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Xử lý ngay'), findsOneWidget);
      await tester.tap(find.text('Xử lý ngay'));
      await tester.pump();

      expect(processed, isTrue);
    });
  });
}
