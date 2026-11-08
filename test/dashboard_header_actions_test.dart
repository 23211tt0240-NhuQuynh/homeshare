import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/home/screens/home_screen.dart';
import 'package:home_share/features/profile/screens/role_aware_profile_screen.dart';
import 'package:home_share/features/renter/screens/renter_dashboard_screen.dart';
import 'package:home_share/features/renter/screens/user_notifications_screen.dart';

class _FakeRoomService extends Fake implements RoomService {
  @override
  Future<void> seedInitialRoomsIfEmpty() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = UserProfile(
    uid: 'u1',
    email: 'test@example.com',
    displayName: 'vanthe',
    phoneNumber: '0912345678',
    avatarUrl: '',
    role: 'renter',
  );

  group('Dashboard Header Actions & Profile Pencil Removal Tests', () {
    testWidgets('HomeScreen tab Trang cá nhân không còn icon cây bút ở AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testProfile)),
            userUnreadNotificationCountProvider.overrideWithValue(0),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề "Trang cá nhân"
      expect(find.text('Trang cá nhân'), findsOneWidget);

      // Icon cây bút đã bị xóa khỏi AppBar
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('RenterDashboardScreen có icon tìm kiếm, chuông thông báo và avatar theo đúng thứ tự', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(_FakeRoomService()),
            roomsStreamProvider.overrideWith((ref, filters) => Stream.value(<RoomModel>[])),
            userProfileProvider.overrideWith((ref) => Stream.value(testProfile)),
            userUnreadNotificationCountProvider.overrideWithValue(2),
          ],
          child: const MaterialApp(
            home: RenterDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Icon tìm kiếm
      final searchIcon = find.byIcon(Icons.search);
      expect(searchIcon, findsOneWidget);

      // 2. Icon thông báo
      final bellIcon = find.byIcon(Icons.notifications_none_rounded);
      expect(bellIcon, findsOneWidget);

      // 3. Avatar
      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsOneWidget);

      // Kiểm tra thứ tự tọa độ X: search.dx < bell.dx < avatar.dx
      final searchOffset = tester.getTopLeft(searchIcon);
      final bellOffset = tester.getTopLeft(bellIcon);
      final avatarOffset = tester.getTopLeft(avatarFinder);

      expect(searchOffset.dx < bellOffset.dx, isTrue);
      expect(bellOffset.dx < avatarOffset.dx, isTrue);
    });

    testWidgets('Nhấn vào chuông thông báo trên Dashboard sẽ mở UserNotificationsScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(_FakeRoomService()),
            roomsStreamProvider.overrideWith((ref, filters) => Stream.value(<RoomModel>[])),
            userProfileProvider.overrideWith((ref) => Stream.value(testProfile)),
            userUnreadNotificationCountProvider.overrideWithValue(1),
          ],
          child: const MaterialApp(
            home: RenterDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final bellIcon = find.byIcon(Icons.notifications_none_rounded);
      await tester.tap(bellIcon);
      await tester.pumpAndSettle();

      // Màn hình thông báo xuất hiện
      expect(find.byType(UserNotificationsScreen), findsOneWidget);
    });

    testWidgets('Nhấn vào avatar trên Dashboard sẽ mở RoleAwareProfileScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomServiceProvider.overrideWithValue(_FakeRoomService()),
            roomsStreamProvider.overrideWith((ref, filters) => Stream.value(<RoomModel>[])),
            userProfileProvider.overrideWith((ref) => Stream.value(testProfile)),
            userUnreadNotificationCountProvider.overrideWithValue(0),
          ],
          child: const MaterialApp(
            home: RenterDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final avatarFinder = find.byType(CircleAvatar);
      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      // Mở RoleAwareProfileScreen
      expect(find.byType(RoleAwareProfileScreen), findsOneWidget);
    });
  });
}
