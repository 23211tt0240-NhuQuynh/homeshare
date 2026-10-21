import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/widgets/host_area_input.dart';

void main() {
  testWidgets('exact area accepts typing and slider updates the same field', (tester) async {
    var area = 25.0;
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) => Form(key: form, child: HostAreaInput(
        value: area, onChanged: (value) => setState(() => area = value),
      )),
    ))));
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(RangeSlider), findsNothing);
    final input = find.byKey(const ValueKey('room_area_input'));
    await tester.enterText(input, '42,5');
    await tester.pump();
    expect(area, 42.5);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 42.5);
    expect(form.currentState!.validate(), isTrue);
    await tester.enterText(input, '150');
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 150);
    await tester.tap(find.byType(Slider));
    await tester.pump();
    final controller = tester.widget<TextFormField>(input).controller!;
    expect(double.parse(controller.text), area);
    await tester.enterText(input, '0');
    expect(form.currentState!.validate(), isFalse);
    await tester.enterText(input, '');
    expect(form.currentState!.validate(), isFalse);
  });
}
