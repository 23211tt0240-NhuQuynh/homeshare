import 'package:home_share/data/models/period_model.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/data/host_property.dart';
import 'package:home_share/features/host/widgets/tenant_card.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/providers/tenant_management_provider.dart';
import 'package:home_share/features/host/repositories/tenant_repository.dart';
import 'package:home_share/features/host/screens/host_tenant_management_screen.dart';

TenantItem tenant(
  String id,
  String name,
  String status, {
  List<ResidentModel> members = const [],
}) => TenantItem(
  id: id,
  primaryName: name,
  phone: '0912345678',
  roomId: 'room_$id',
  roomName: 'P.$id',
  propertyId: 'home',
  propertyName: 'Nhà A',
  bookingId: 'DP_$id',
  moveInDate: DateTime(2026, 10, 23),
  status: status,
  roommates: members,
);

void main() {
  test(
    'Separates approved bookings from checked-in occupants and searches roommates',
    () {
      for (final status in ['approved', 'paid', 'daDuyet', 'deposit_paid']) {
        expect(tenant('1', 'An', status).isActive, isFalse);
      }
      for (final status in ['dangO', 'active', 'daNhanPhong', 'dang_o']) {
        expect(tenant('1', 'An', status).isActive, isTrue);
      }
      final group = tenant(
        '1',
        'An',
        'active',
        members: [
          ResidentModel(
            id: 'r',
            periodId: 'p',
            userId: 'u',
            fullName: 'Bình',
            phone: '0987654321',
            moveInDate: DateTime(2026),
          ),
        ],
      );
      expect(group.matches('bình'), isTrue);
      expect(group.matches('098765'), isTrue);
      expect(group.matches('DP_1'), isTrue);
      expect(group.matches('Nhà A'), isTrue);
      expect(group.matches('không tồn tại'), isFalse);
    },
  );

  test('Both check-in routes work without a matching host_rooms row', () {
    for (final fields in [
      {'status': 'dangO', 'isCheckIn': true},
      {'status': 'active', 'trangThai': 'dangO'},
      {'status': 'approved', 'daNhanPhong': true},
    ]) {
      final data = <String, dynamic>{
        ...fields,
        'roomId': 'public_room',
        'phongId': '',
        'renterName': 'vanthe',
        'renterId': 'renter_uid',
        'tenNguoiO': '',
        'roomTitle': 'Chung cư ngon mơn mởn',
        'hostId': 'host',
        'deposit': 500000,
      };
      expect(TenantRepository.isCheckedInBooking(data), isTrue);
      final booking = TenantRepository.bookingForTenant(data, 'DP_NT968');
      final item = TenantRepository.tenantFromBooking(booking);
      expect(item.primaryName, 'vanthe');
      expect(item.renterId, 'renter_uid');
      expect(item.roomId, 'public_room');
      expect(item.bookingId, 'DP_NT968');
      expect(item.isActive, isTrue);
    }
    for (final data in [
      {'status': 'approved'},
      {'status': 'paid'},
      {'status': 'pending_payment'},
      {'status': 'active', 'source': 'host_manual'},
      {'status': 'cancelled', 'isCheckIn': true},
    ]) {
      expect(TenantRepository.isCheckedInBooking(data), isFalse);
    }
  });

  testWidgets(
    'Tenant card only offers SMS and opens the in-app message action',
    (tester) async {
      var messages = 0;
      var details = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TenantCard(
              tenant: tenant('101', 'An', 'active'),
              onMessage: () => messages++,
              onTap: () => details++,
            ),
          ),
        ),
      );
      expect(find.text('Gọi'), findsNothing);
      expect(find.text('SMS'), findsOneWidget);
      await tester.tap(find.text('SMS'));
      expect(messages, 1);
      expect(details, 0);
    },
  );

  test(
    'Listing IDs resolve to the original room and property, not the post title',
    () {
      final room = RoomModel.fromMap({
        'roomCode': 'TB01',
        'propertyId': 'toan_bel',
        'hostId': 'host',
        'title': 'Phòng TB01',
      }, 'PWFFQHMBU783');
      final roomMap = {room.id: room};
      for (final field in ['roomId', 'phongId', 'room_id', 'phong_tro_id']) {
        final resolved = TenantRepository.resolveTenantRoom(
          'post_toan',
          roomMap,
          {
            'post_toan': {field: room.id, 'title': 'Toan'},
          },
        );
        final booking = TenantRepository.bookingForTenant({
          'roomId': 'post_toan',
          'renterId': 'renter',
          'renterName': 'vanthe',
          'status': 'active',
        }, 'booking');
        final item = TenantRepository.tenantFromBooking(
          booking,
          room: resolved,
          propertyNames: {'toan_bel': 'Chung cư Toàn Bel'},
        );
        expect(item.roomId, 'PWFFQHMBU783');
        expect(item.propertyId, 'toan_bel');
        expect(item.propertyName, 'Chung cư Toàn Bel');
        expect(item.roomName, 'P.TB01');
        expect(item.roomName, isNot('Toan'));
      }
      expect(
        TenantRepository.resolveTenantRoom(room.id, roomMap, {}),
        same(room),
      );
      expect(
        TenantRepository.resolveTenantRoom('unknown', roomMap, {}),
        isNull,
      );
    },
  );

  testWidgets('Property and room filters use original IDs', (tester) async {
    final rooms = [
      TenantItem(
        id: 'b1',
        primaryName: 'Khách TB01',
        phone: '',
        roomId: 'r1',
        roomName: 'P.TB01',
        propertyId: 'bel',
        propertyName: 'Chung cư Toàn Bel',
        moveInDate: DateTime(2026),
      ),
      TenantItem(
        id: 'b2',
        primaryName: 'Khách TB02',
        phone: '',
        roomId: 'r2',
        roomName: 'P.TB02',
        propertyId: 'bel',
        propertyName: 'Chung cư Toàn Bel',
        moveInDate: DateTime(2026),
      ),
      TenantItem(
        id: 'b3',
        primaryName: 'Khách khác',
        phone: '',
        roomId: 'r3',
        roomName: 'P.K01',
        propertyId: 'other',
        propertyName: 'Cơ sở khác',
        moveInDate: DateTime(2026),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostTenantsProvider.overrideWith((ref) => Stream.value(rooms)),
          hostPropertiesProvider.overrideWith(
            (ref) => Stream.value([
              const HostProperty(
                id: 'bel',
                name: 'Chung cư Toàn Bel',
                address: '',
                city: '',
                ward: '',
                hostId: 'host',
                plannedRooms: 2,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: HostTenantManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chung cư Toàn Bel').last);
    await tester.pumpAndSettle();
    expect(find.text('Khách khác'), findsNothing);
    expect(find.text('Khách TB01'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('P.TB02').last);
    await tester.pumpAndSettle();
    expect(find.text('Khách TB01'), findsNothing);
    expect(find.text('Khách TB02'), findsOneWidget);
  });

  test(
    'Approved roommates in a period without bookingId join the checked-in tenant',
    () {
      final room = RoomModel.fromMap({
        'propertyId': 'bel',
        'roomCode': 'TB01',
      }, 'real_room');
      final rooms = {'real_room': room, 'post_toan': room};
      final booking = TenantRepository.bookingForTenant({
        'roomId': 'post_toan',
        'renterId': 'primary',
        'status': 'dangO',
      }, 'booking');
      PeriodModel period(
        String tenant, {
        String bookingId = '',
        String roomId = 'real_room',
      }) => PeriodModel(
        id: 'period',
        bookingId: bookingId,
        roomId: roomId,
        renterId: tenant,
        startDate: DateTime(2026),
        createdAt: DateTime(2026),
      );
      expect(
        TenantRepository.bookingForPeriod(period('primary'), [booking], rooms),
        same(booking),
      );
      expect(
        TenantRepository.bookingForPeriod(period('other'), [booking], rooms),
        isNull,
      );
      expect(
        TenantRepository.bookingForPeriod(
          period('primary', roomId: 'another_room'),
          [booking],
          rooms,
        ),
        isNull,
      );
      expect(
        TenantRepository.bookingForPeriod(
          period('primary', bookingId: 'old_booking'),
          [booking],
          rooms,
        ),
        isNull,
      );
      expect(
        TenantRepository.bookingForPeriod(period('primary'), [], rooms),
        isNull,
      );
    },
  );

  Future<void> pumpScreen(WidgetTester tester, List<TenantItem> items) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostTenantsProvider.overrideWith((ref) => Stream.value(items)),
          hostPropertiesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: HostTenantManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Empty data shows a real empty state without sample tenants', (
    tester,
  ) async {
    await pumpScreen(tester, []);
    expect(find.textContaining('Chưa có người thuê.'), findsOneWidget);
    expect(find.text('Lê Hoàng Nam'), findsNothing);
    expect(find.text('0 người đang thuê'), findsOneWidget);
  });

  testWidgets('Stats count only checked-in members; filters and details work', (
    tester,
  ) async {
    await pumpScreen(tester, [
      tenant('101', 'An', 'active'),
      tenant('102', 'Bình', 'paid'),
    ]);
    expect(find.text('1 người đang thuê'), findsOneWidget);
    expect(find.text('1 phòng đang sử dụng'), findsOneWidget);
    expect(find.text('Bình'), findsNothing);
    expect(find.text('Thêm khách thuê trực tiếp'), findsNothing);
    await tester.enterText(find.byType(TextField), 'DP_101');
    await tester.pumpAndSettle();
    expect(find.text('Bình'), findsNothing);
    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    expect(find.text('Mã đặt phòng'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'DP_101',
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có hồ sơ kỳ ở'), findsOneWidget);
  });
  testWidgets('Quick check-in updates waiting status and counts live', (
    tester,
  ) async {
    final changes = StreamController<List<TenantItem>>();
    addTearDown(changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostTenantsProvider.overrideWith((ref) => changes.stream),
          hostPropertiesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: HostTenantManagementScreen()),
      ),
    );
    changes.add([tenant('101', 'An', 'approved')]);
    await tester.pumpAndSettle();
    expect(find.text('0 người đang thuê'), findsOneWidget);
    changes.add([
      tenant(
        '101',
        'An',
        'dangO',
        members: [
          ResidentModel(
            id: '1',
            periodId: 'p',
            userId: 'u1',
            fullName: 'An',
            moveInDate: DateTime(2026),
          ),
          ResidentModel(
            id: '2',
            periodId: 'p',
            userId: 'u2',
            fullName: 'Bình',
            moveInDate: DateTime(2026),
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('2 người đang thuê'), findsOneWidget);
    expect(find.text('1 phòng đang sử dụng'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
