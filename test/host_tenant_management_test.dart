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
        'tenNguoiO': '',
        'roomTitle': 'Chung cư ngon mơn mởn',
        'hostId': 'host',
        'deposit': 500000,
      };
      expect(TenantRepository.isCheckedInBooking(data), isTrue);
      final booking = TenantRepository.bookingForTenant(data, 'DP_NT968');
      final item = TenantRepository.tenantFromBooking(booking);
      expect(item.primaryName, 'vanthe');
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
