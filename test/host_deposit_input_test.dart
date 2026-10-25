import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/room_deposit.dart';
import 'package:home_share/features/host/widgets/host_deposit_input.dart';

void main() {
  // Chủ trọ - Kiểm thử cọc - Luồng đi: Số tiền theo đúng tỷ lệ hợp lệ,
  // làm tròn đến đồng và không tự thay khoản cọc cũ ngoài danh sách.
  test('Calculates all deposit rates and handles legacy amounts safely', () {
    for (final percent in roomDepositPercentages) {
      expect(roomDeposit(2500000, percent), 25000 * percent);
    }
    expect(roomDeposit(1005, 10), 101);
    expect(() => roomDeposit(2500000, 0), throwsArgumentError);
    expect(() => roomDeposit(double.nan, 20), throwsArgumentError);
    expect(existingRoomDepositPercentage(2500000, 500000, null), 20);
    expect(existingRoomDepositPercentage(2500000, 2500000, 100), 100);
    expect(existingRoomDepositPercentage(2500000, 750000, 20), 30);
    expect(existingRoomDepositPercentage(2500000, 0, null), isNull);
    expect(existingRoomDepositPercentage(2500000, 700000, null), isNull);
  });

  testWidgets(
    'Compact picker offers 10–100 and updates computed amount with rent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final price = TextEditingController(text: '2.500.000');
      addTearDown(price.dispose);
      var percent = 20;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => Form(
                  child: HostDepositInput(
                    priceController: price,
                    percentage: percent,
                    onChanged: (value) => setState(() => percent = value!),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final picker = find.byKey(const ValueKey('host_deposit_percentage'));
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.descendant(
                of: picker,
                matching: find.byType(DropdownButton<int>),
              ),
            )
            .items!
            .map((item) => item.value)
            .toList(),
        roomDepositPercentages,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('host_deposit_amount')))
            .data,
        '500.000',
      );
      tester.widget<DropdownButtonFormField<int>>(picker).onChanged!(100);
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('host_deposit_amount')))
            .data,
        '2.500.000',
      );
      price.text = '3.000.000';
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('host_deposit_amount')))
            .data,
        '3.000.000',
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Legacy deposit requires explicit percentage before saving', (
    tester,
  ) async {
    final price = TextEditingController(text: '2500000');
    addTearDown(price.dispose);
    final form = GlobalKey<FormState>();
    int? percent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              key: form,
              child: HostDepositInput(
                priceController: price,
                percentage: percent,
                formattedPrice: false,
                legacyDeposit: 700000,
                onChanged: (value) => setState(() => percent = value),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('host_deposit_amount')))
          .data,
      '700.000',
    );
    expect(form.currentState!.validate(), isFalse);
    tester
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('host_deposit_percentage')),
        )
        .onChanged!(30);
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('host_deposit_amount')))
          .data,
      '750.000',
    );
  });
}
