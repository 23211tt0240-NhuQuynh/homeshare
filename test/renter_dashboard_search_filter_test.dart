import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/app_colors.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/renter/screens/renter_dashboard_screen.dart';
import 'package:home_share/features/renter/screens/search_filter_screen.dart';
import 'package:home_share/features/renter/screens/user_notifications_screen.dart';

class _FakeRoomService implements RoomService {
  @override
  Future<void> seedInitialRoomsIfEmpty() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _searchFilterTestApp({
  List<RoomModel> rooms = const [],
  List<RoommatePostModel> roommatePosts = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => null),
      userProfileProvider.overrideWith((ref) => Stream.value(null)),
      roomServiceProvider.overrideWithValue(_FakeRoomService()),
      roomsStreamProvider.overrideWith(
        (ref, filters) => Stream<List<RoomModel>>.value(rooms),
      ),
      roommatePostsStreamProvider.overrideWith(
        (ref, filters) => Stream<List<RoommatePostModel>>.value(roommatePosts),
      ),
      userUnreadNotificationCountProvider.overrideWith((ref) => 0),
    ],
    child: const MaterialApp(home: SearchFilterScreen(initialAdvanced: true)),
  );
}

void main() {
  final testRoom = RoomModel.fromMap({
    'title': 'Kết quả phòng riêng',
    'description': 'Phòng riêng kiểm thử',
    'rentalPrice': 2500000,
    'address': 'Gò Vấp, TP. Hồ Chí Minh',
    'district': 'Gò Vấp',
    'city': 'TP. Hồ Chí Minh',
    'status': 'active',
    'isAvailable': true,
  }, 'post-private-room');
  final testRoommatePost = RoommatePostModel(
    id: 'roommate-result',
    authorId: 'renter-002',
    authorName: 'Minh Anh',
    authorAge: 21,
    authorGender: 'Nữ',
    authorOccupation: 'Sinh viên',
    title: 'Kết quả ở ghép',
    description: 'Tìm bạn cùng phòng',
    pricePerPerson: 2000000,
    budgetMin: 1500000,
    budgetMax: 3000000,
    district: 'Gò Vấp',
    targetGender: 'Tất cả',
    habits: const [],
    hasRoom: true,
    contactPhone: '0909000000',
    createdAt: DateTime(2026, 10, 21),
  );

  testWidgets('thanh trên bộ lọc không hiển thị chuông và avatar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_searchFilterTestApp());
    await tester.pumpAndSettle();

    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    expect(
      find.descendant(
        of: appBar,
        matching: find.byIcon(Icons.notifications_none),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.person)),
      findsNothing,
    );
    expect(find.text('Trang Chủ'), findsOneWidget);
  });

  testWidgets('hình thức Ở 1 mình chỉ hiển thị phòng cho thuê', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _searchFilterTestApp(
        rooms: [testRoom],
        roommatePosts: [testRoommatePost],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tìm kiếm'));
    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả phòng riêng'), findsOneWidget);
    expect(find.text('Kết quả ở ghép'), findsNothing);
  });

  testWidgets('hình thức Ở ghép chỉ hiển thị bài tìm ở ghép', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _searchFilterTestApp(
        rooms: [testRoom],
        roommatePosts: [testRoommatePost],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ở ghép'));
    await tester.tap(find.text('Ở ghép'));
    await tester.ensureVisible(find.text('Tìm kiếm'));
    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả ở ghép'), findsOneWidget);
    expect(find.text('Kết quả phòng riêng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hình thức Cả hai hiển thị phòng và bài tìm ở ghép', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _searchFilterTestApp(
        rooms: [testRoom],
        roommatePosts: [testRoommatePost],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cả hai'));
    await tester.tap(find.text('Cả hai'));
    await tester.ensureVisible(find.text('Tìm kiếm'));
    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả phòng riêng'), findsOneWidget);
    expect(find.text('Kết quả ở ghép'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thẻ phòng Trang chủ hiển thị địa chỉ đầy đủ và tên chủ trọ', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final room = RoomModel(
      id: 'post-001',
      roomCode: 'P001',
      title: 'Phòng trọ kiểm thử',
      description: 'Phòng đầy đủ nội thất',
      price: 2500000,
      deposit: 1500000,
      address: '12 Nguyễn Văn Bảo, Phường 4, Gò Vấp, TP. Hồ Chí Minh',
      district: 'Gò Vấp',
      city: 'TP. Hồ Chí Minh',
      area: 20,
      roomType: 'Phòng trọ',
      amenities: const [],
      images: const [],
      hostId: 'host-001',
      hostName: 'Cô Lan',
      hostPhone: '0909000000',
      createdAt: DateTime(2026, 10, 20),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          roomServiceProvider.overrideWithValue(_FakeRoomService()),
          roomsStreamProvider.overrideWith(
            (ref, filters) => Stream<List<RoomModel>>.value([room]),
          ),
          roommatePostsStreamProvider.overrideWith(
            (ref, filters) => Stream<List<RoommatePostModel>>.value(const []),
          ),
          userUnreadNotificationCountProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: RenterDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('12 Nguyễn Văn Bảo, Phường 4, Gò Vấp, TP. Hồ Chí Minh'),
      findsOneWidget,
    );
    expect(find.text('Chủ trọ: Cô Lan'), findsOneWidget);
    expect(find.textContaining('TP. Hồ Chí Minh, Gò Vấp'), findsNothing);
  });

  testWidgets('kính lúp trên Trang chủ mở bộ lọc nâng cao màu xanh dương', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          roomServiceProvider.overrideWithValue(_FakeRoomService()),
          roomsStreamProvider.overrideWith(
            (ref, filters) => Stream<List<RoomModel>>.value(const []),
          ),
          roommatePostsStreamProvider.overrideWith(
            (ref, filters) => Stream<List<RoommatePostModel>>.value(const []),
          ),
          userUnreadNotificationCountProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: RenterDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Tìm phòng, căn hộ, bạn ở ghép...'), findsNothing);

    final searchButton = find.byTooltip('Mở bộ lọc tìm phòng');
    expect(searchButton, findsOneWidget);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(find.byType(SearchFilterScreen), findsOneWidget);
    expect(find.text('Khu vực'), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);

    final locationIcon = tester.widget<Icon>(
      find.byIcon(Icons.near_me_outlined),
    );
    expect(locationIcon.color, AppColors.primary);
  });

  testWidgets('bỏ chọn tiện ích tùy chọn không xóa tiện ích khỏi danh sách', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_searchFilterTestApp());
    await tester.pumpAndSettle();

    final amenity = find.text('Gần trường ĐH / Bến xe');
    await tester.ensureVisible(amenity);
    await tester.tap(amenity);
    await tester.pumpAndSettle();

    expect(find.text('Gần trường ĐH / Bến xe'), findsOneWidget);
    expect(find.text('4 đang chọn'), findsOneWidget);
  });

  testWidgets('nút Đặt lại giữ nguyên bộ lọc đang mở', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_searchFilterTestApp());
    await tester.pumpAndSettle();

    final resetButton = find.text('Đặt lại');
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('Bộ lọc'), findsOneWidget);
    expect(find.text('Tiện ích & Yêu cầu'), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);
  });
}
