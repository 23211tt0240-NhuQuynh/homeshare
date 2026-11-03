import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/data/host_property.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_finance_invoices.dart';
import 'package:home_share/features/host/screens/host_finance_screen.dart';
import 'package:home_share/features/host/widgets/host_finance_style.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('FinancePreview')
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
  testWidgets(
    'Mobile navigation, bar chart periods and existing-property filtering',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostSessionProvider.overrideWith((ref) => Stream.value('host')),
            hostFinancePostsProvider.overrideWith((ref) => Stream.value([])),
            hostPropertiesProvider.overrideWith(
              (ref) => Stream.value([
                HostProperty.fromMap('bel', {
                  'name': 'Chung cư Toàn Bel',
                  'hostId': 'host',
                }),
                HostProperty.fromMap('other', {
                  'name': 'Cơ sở khác',
                  'hostId': 'host',
                }),
              ]),
            ),
            hostRoomsProvider.overrideWith(
              (ref) => Stream.value([
                RoomModel.fromMap({
                  'propertyId': 'bel',
                  'hostId': 'host',
                }, 'room'),
              ]),
            ),
            hostFinanceBookingsProvider.overrideWith(
              (ref) => Stream.value([
                {
                  'id': 'deposit',
                  'roomId': 'room',
                  'roomTitle': 'Studio ban công · Toàn Bel',
                  'renterName': 'Nguyễn Minh Anh',
                  'orderCode': 'COC-TB01',
                  'paymentOption': 'deposit',
                  'status': 'approved',
                  'depositAmount': 5000000,
                  'createdAt': now,
                },
                {
                  'id': 'full',
                  'roomId': 'room',
                  'roomTitle': 'Căn hộ ánh sáng · Toàn Bel',
                  'renterName': 'Trần Quốc Minh',
                  'orderCode': 'HD-TB02',
                  'paymentOption': 'full',
                  'status': 'paid',
                  'totalPayable': 100000000,
                  'platformFee': 5000000,
                  'isDisbursed': true,
                  'createdAt': now,
                },
              ]),
            ),
            hostFinanceDisbursementsProvider.overrideWith(
              (ref) => Stream.value([
                {
                  'id': 'receipt',
                  'bookingIds': ['full'],
                  'totalAmount': 95000000,
                  'createdAt': now,
                },
              ]),
            ),
          ],
          child: RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'FinancePreview'),
              home: const HostFinanceScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('FINANCE_PREVIEW')) return;
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/finance_preview')
            ..createSync(recursive: true);
          File(
            '${directory.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('statistics');
      for (final entry in {'Tuần': 7, 'Tháng': 5, 'Năm': 12}.entries) {
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HostCashflowChart>(find.byType(HostCashflowChart))
              .values
              .length,
          entry.value,
        );
        await tester.tap(find.byType(HostCashflowChart));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        find.text('Thực nhận sau phí hoa hồng · Đơn vị: Việt Nam đồng'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tiền cọc'));
      await tester.pumpAndSettle();
      await capture('deposit');
      expect(find.text('Studio ban công · Toàn Bel'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cơ sở khác').last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có hóa đơn phù hợp'), findsOneWidget);
      expect(find.text('Studio ban công · Toàn Bel'), findsNothing);
      await tester.tap(find.text('Trả hết'));
      await tester.pumpAndSettle();
      await capture('full-payment');
      expect(find.text('Căn hộ ánh sáng · Toàn Bel'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Thống kê'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
