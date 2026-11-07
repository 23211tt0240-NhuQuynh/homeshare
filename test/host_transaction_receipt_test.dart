import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/screens/host_transaction_receipt_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('ReceiptPreview')
          ..addFont(rootBundle.load('lib/core/utils/admin_receipt_font.ttf')))
        .load();
    if (const bool.fromEnvironment('FINANCE_PREVIEW')) {
      final icons = File(
        'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync())),
            ))
            .load();
      }
    }
  });
  final bookings = <Map<String, dynamic>>[
    {
      'id': 'a',
      'orderCode': 'NT826',
      'renterName': 'Khách A',
      'roomTitle': 'Phòng Vip',
      'depositAmount': 2000,
      'platformFee': 100,
    },
    {
      'id': 'b',
      'orderCode': 'NT968',
      'renterName': 'Khách B',
      'roomTitle': 'Phòng bự',
      'depositAmount': 500000,
      'platformFee': 25000,
    },
    {
      'id': 'unrelated',
      'roomTitle': 'Không thuộc phiếu',
      'depositAmount': 900000,
    },
  ];
  final receipt = <String, dynamic>{
    'id': 'receipt-id',
    'receiptCode': '#REC-20261104-141040-IDBE',
    'bookingIds': ['a', 'b'],
    'totalAmount': 476900,
    'platformFeeRate': 5,
    'hostName': 'Chủ trọ',
    'hostBankName': 'MSB',
    'hostAccountNumber': '1001022005',
    'createdAt': DateTime(2026, 11, 4, 14, 10),
  };
  test('Receipt uses only its bookings and recorded fees', () {
    final items = hostSettlementReceiptItems({
      ...receipt,
      'platformFeeRate': 99,
    }, bookings);
    expect(items.length, 2);
    expect(items.map((i) => i['fee']), [100, 25000]);
    expect(items.map((i) => i['net']), [1900, 475000]);
  });
  test(
    'Legacy fee uses rate recorded on receipt; missing booking is reported',
    () {
      final items = hostSettlementReceiptItems(
        receipt,
        bookings.map((b) => {...b}..remove('platformFee')).toList(),
      );
      expect(items.map((i) => i['net']), [1900, 475000]);
      expect(
        () => hostSettlementReceiptItems(receipt, [bookings.first]),
        throwsStateError,
      );
    },
  );
  testWidgets('Receipt matches saved transfer details on narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'ReceiptPreview'),
          home: HostTransactionReceiptScreen(
            settlement: receipt,
            bookings: bookings,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('476.900 đ'), findsWidgets);
    expect(find.text('MSB: 1001022005'), findsOneWidget);
    expect(find.text('14:10 - 04/11/2026'), findsOneWidget);
    expect(find.text('Đã quyết toán 2 đơn'), findsOneWidget);
    expect(find.text('Không thuộc phiếu'), findsNothing);
    expect(find.text('IN PHIẾU PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('FINANCE_PREVIEW')) {
      tester.view.physicalSize = const Size(390, 1100);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/finance_preview').createSync(recursive: true);
        File(
          'build/finance_preview/transaction-receipt.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
