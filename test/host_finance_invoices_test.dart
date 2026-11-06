import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_finance_invoices.dart';

void main() {
  for (final deposit in [true, false]) {
    for (final state in ['pending', 'disbursed', 'legacy_received']) {
      testWidgets(
        '${deposit ? 'Deposit' : 'Full'} invoice $state needs no host confirmation',
        (tester) async {
          tester.view.physicalSize = const Size(390, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostPropertiesProvider.overrideWith((ref) => Stream.value([])),
                hostRoomsProvider.overrideWith((ref) => Stream.value([])),
                hostFinancePostsProvider.overrideWith(
                  (ref) => Stream.value([]),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: HostFinanceInvoices(
                    isDeposit: deposit,
                    bookings: [
                      {
                        'id': 'deposit',
                        'paymentOption': 'deposit',
                        'status': 'approved',
                        'roomTitle': 'Phòng cọc',
                        'depositAmount': 5000000,
                        'isDisbursed': state != 'pending',
                        if (state == 'legacy_received')
                          'hostReceiptConfirmedAt': DateTime(2026),
                      },
                      {
                        'id': 'full',
                        'paymentOption': 'full',
                        'status': 'paid',
                        'roomTitle': 'Phòng trả hết',
                        'totalPayable': 5000000,
                        'isDisbursed': state != 'pending',
                        if (state == 'legacy_received')
                          'hostReceiptConfirmedAt': DateTime(2026),
                      },
                      {
                        'id': 'cancelled',
                        'paymentOption': deposit ? 'deposit' : 'full',
                        'status': 'cancelled',
                        'roomTitle': 'Đã hủy',
                      },
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(deposit ? 'Phòng cọc' : 'Phòng trả hết'),
            findsOneWidget,
          );
          expect(
            find.text(deposit ? 'Phòng trả hết' : 'Phòng cọc'),
            findsNothing,
          );
          expect(find.text('Đã hủy'), findsNothing);
          expect(
            find.text(deposit ? '4.500.000 đ' : '4.750.000 đ'),
            findsWidgets,
          );
          expect(
            find.text('Thực nhận dự kiến sau phí hoa hồng'),
            findsOneWidget,
          );
          expect(find.text('Đã trừ phí hoa hồng'), findsNothing);
          expect(find.text('Đã nhận tiền'), findsNothing);
          expect(find.text('Đã nhận'), findsNothing);
          expect(
            find.text('Có thể xác nhận nhận tiền sau khi sàn giải ngân.'),
            findsNothing,
          );
          if (state != 'pending') {
            expect(find.text('Đã giải ngân'), findsOneWidget);
          }
          await tester.ensureVisible(find.text('Chi tiết'));
          await tester.tap(find.text('Chi tiết'));
          await tester.pumpAndSettle();
          expect(find.text('Chi tiết hóa đơn'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
