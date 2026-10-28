import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_finance_screen.dart';
import 'package:home_share/features/admin/widgets/revenue_line_chart.dart';

void main() {
  testWidgets(
    'Totals use settlement net amount and successful orders await admin disbursement',
    (tester) async {
      final now = DateTime.now();
      final settlements = StateProvider<List<Map<String, dynamic>>>(
        (ref) => [],
      );
      final container = ProviderContainer(
        overrides: [
          hostSessionProvider.overrideWith((ref) => Stream.value('host')),
          hostFinanceBookingsProvider.overrideWith(
            (ref) => Stream.value([
              {
                'id': 'a',
                'roomTitle': 'Bài viết Toan',
                'status': 'paid',
                'paymentAmount': 100000000,
                'createdAt': now,
              },
              {
                'id': 'b',
                'roomTitle': 'Bài viết TTM',
                'status': 'approved',
                'paymentAmount': 5000000,
                'createdAt': now,
              },
              {
                'id': 'c',
                'status': 'approved',
                'paymentAmount': 1000000,
                'createdAt': now,
              },
            ]),
          ),
          hostFinanceDisbursementsProvider.overrideWith(
            (ref) => Stream.value(ref.watch(settlements)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HostFinanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 đơn'), findsOneWidget);
      expect(find.text('3 đơn'), findsOneWidget);
      expect(find.text('ĐÃ GIẢI NGÂN'), findsNothing);
      container.read(settlements.notifier).state = [
        {
          'id': 'receipt',
          'receiptCode': 'REC-TEST',
          'totalAmount': 95000000,
          'totalDeposit': 105000000,
          'bookingIds': ['a', 'b'],
          'itemCount': 2,
          'createdAt': now,
        },
      ];
      await tester.pumpAndSettle();
      expect(find.text('95.000.000 đ'), findsWidgets);
      expect(find.text('2 đơn'), findsOneWidget);
      expect(find.text('1 đơn'), findsOneWidget);
      expect(find.text('Bài viết Toan, Bài viết TTM'), findsOneWidget);
      expect(find.text('REC-TEST'), findsNothing);
      final chart = tester.widget<RevenueLineChart>(
        find.byType(RevenueLineChart),
      );
      expect(chart.weeklyData.fold<double>(0, (a, b) => a + b), 95000000);
      expect(tester.takeException(), isNull);
    },
  );
}
