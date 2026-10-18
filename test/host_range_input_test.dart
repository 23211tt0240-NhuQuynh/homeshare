import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/widgets/host_range_input.dart';
import 'host_management_test.dart' as fixture;
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/core/utils/vnd_input.dart';
import 'package:home_share/features/host/data/host_property.dart';

void main() {
  // Chủ trọ - Kiểm thử giá nhà - Luồng đi: Giá dự kiến chỉ được dùng
  // khi chưa có phòng; phòng khác cơ sở và phòng đã xóa không ảnh hưởng.
  test('Actual rent follows room creation, price changes and deletion', () {
    expect(PropertySummary(fixture.house, []).hasActualRent, isFalse);
    final summary = PropertySummary(fixture.house, [
      fixture.makeRoom('A1', price: 2000000),
      fixture.makeRoom('A2', price: 7000000),
      fixture.makeRoom('A3', price: 9000000, status: 'deleted'),
      fixture.makeRoom('B1', price: 1000000, propertyId: 'other'),
    ]);
    expect(summary.minRent, 2000000);
    expect(summary.maxRent, 7000000);
    expect(
      PropertySummary(fixture.house, [
        fixture.makeRoom('A1', price: 3500000),
      ]).maxRent,
      3500000,
    );
  });

  // Chủ trọ - Kiểm thử ô tiền - Luồng đi: Định dạng khi nhập, lưu lại
  // đúng số nguyên và không nhận dấu âm hay giá vượt giới hạn.
  test('Money formatting preserves amount and rejects invalid input', () {
    final formatter = VndInputFormatter();
    const old = TextEditingValue();
    final result = formatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '2500000',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    expect(result.text, '2.500.000');
    expect(vndDigits(result.text), '2500000');
    expect(
      formatter.formatEditUpdate(old, const TextEditingValue(text: '-100')),
      old,
    );
    expect(
      formatter.formatEditUpdate(
        old,
        const TextEditingValue(text: '1000000001'),
      ),
      old,
    );
  });

  testWidgets('Optional money range validates and slider uses 100000 steps', (
    tester,
  ) async {
    var values = const RangeValues(0, 0);
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              key: form,
              child: HostRangeInput(
                label: 'Giá dự kiến',
                unit: 'đ',
                values: values,
                sliderMax: 20000000,
                money: true,
                optional: true,
                onChanged: (next) => setState(() => values = next),
              ),
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isTrue);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '2000000');
    expect(form.currentState!.validate(), isFalse);
    await tester.enterText(fields.last, '5000000');
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    expect(values, const RangeValues(2000000, 5000000));
    tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
      const RangeValues(2483721, 4980000),
    );
    await tester.pump();
    expect(values, const RangeValues(2500000, 5000000));
    expect(
      tester.widget<TextFormField>(fields.first).controller!.text,
      '2.500.000',
    );
    await tester.enterText(fields.first, '');
    await tester.enterText(fields.last, '');
    await tester.pump();
    expect(values, const RangeValues(0, 0));
    expect(form.currentState!.validate(), isTrue);
  });
  testWidgets('Typing expands slider and dragging updates both fields', (
    tester,
  ) async {
    var values = const RangeValues(2000000, 5000000);
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              key: form,
              child: HostRangeInput(
                label: 'Giá thuê',
                unit: 'đ',
                values: values,
                sliderMax: 20000000,
                onChanged: (next) => setState(() => values = next),
              ),
            ),
          ),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '45000000');
    await tester.pump();
    expect(values.end, 45000000);
    expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).max, 45000000);
    tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
      const RangeValues(40000000, 42000000),
    );
    await tester.pump();
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      '40000000',
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      '42000000',
    );
    await tester.enterText(fields.at(1), '30000000');
    expect(form.currentState!.validate(), isFalse);
  });
  test('Area range survives storage and legacy single area stays readable', () {
    final room = RoomModel.fromMap({
      ...fixture.makeRoom('A1').toMap(),
      'area': 40,
      'minArea': 40,
      'maxArea': 45,
    }, 'A1');
    final restored = RoomModel.fromMap(room.toMap(), room.id);
    expect(restored.minArea, 40);
    expect(restored.maxArea, 45);
    expect(restored.areaLabel, '40.0–45.0 m²');
    expect(fixture.makeRoom('old').area, 25);
  });
}
