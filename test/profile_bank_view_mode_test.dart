import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/user_profile_service.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/profile/screens/host_profile_screen.dart';
import 'package:home_share/features/profile/screens/personal_profile_screen.dart';

class _FakeUserProfileService extends Fake implements UserProfileService {
  final BankAccount bankAccount;
  _FakeUserProfileService(this.bankAccount);

  @override
  Future<BankAccount> loadBankAccount(String uid) async {
    return bankAccount;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fakeAccount = BankAccount(
    id: 'u1',
    userId: 'u1',
    accountNumber: '19031234567890',
    accountHolder: 'NGUYEN VAN A',
    bankName: 'Techcombank',
  );

  final testProfile = UserProfile(
    uid: 'u1',
    email: 'test@example.com',
    displayName: 'Nguyen Van A',
    phoneNumber: '0912345678',
    role: 'renter',
  );

  final testHostProfile = UserProfile(
    uid: 'host1',
    email: 'host@example.com',
    displayName: 'Chu Tro A',
    phoneNumber: '0987654321',
    role: 'host',
  );

  group('PersonalProfileScreen - Khóa ngân hàng ở chế độ xem', () {
    testWidgets('Khi chưa bấm chỉnh sửa: hiển thị dạng text profileLine, không có dropdown', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testProfile)),
            userProfileServiceProvider.overrideWithValue(_FakeUserProfileService(fakeAccount)),
          ],
          child: const MaterialApp(
            home: PersonalProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề mục "Tài khoản ngân hàng"
      expect(find.text('Tài khoản ngân hàng'), findsOneWidget);

      // Hiển thị text chỉ xem (read-only)
      expect(find.text('Ngân hàng'), findsOneWidget);
      expect(find.text('Techcombank'), findsOneWidget);
      expect(find.text('Số tài khoản'), findsOneWidget);
      expect(find.text('19031234567890'), findsOneWidget);
      expect(find.text('Chủ tài khoản'), findsOneWidget);
      expect(find.text('NGUYEN VAN A'), findsOneWidget);

      // Không có DropdownButtonFormField cho phép chỉnh sửa
      expect(find.byKey(const ValueKey('bank-account-name')), findsNothing);
    });

    testWidgets('Khi bấm Chỉnh sửa: hiển thị DropdownButtonFormField và ô nhập', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testProfile)),
            userProfileServiceProvider.overrideWithValue(_FakeUserProfileService(fakeAccount)),
          ],
          child: const MaterialApp(
            home: PersonalProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Nhấn nút Chỉnh sửa trên thanh AppBar (Icon edit_outlined)
      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Đã chuyển sang chế độ chỉnh sửa: Dropdown xuất hiện
      expect(find.byKey(const ValueKey('bank-account-name')), findsOneWidget);
      expect(find.text('Techcombank'), findsWidgets);
    });
  });

  group('HostProfileScreen - Khóa ngân hàng ở chế độ xem', () {
    testWidgets('Khi chưa bấm chỉnh sửa: hiển thị dạng text profileLine, không có dropdown', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testHostProfile)),
            userProfileServiceProvider.overrideWithValue(_FakeUserProfileService(fakeAccount)),
          ],
          child: const MaterialApp(
            home: HostProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tài khoản ngân hàng'), findsOneWidget);
      expect(find.text('Ngân hàng'), findsOneWidget);
      expect(find.text('Techcombank'), findsOneWidget);
      expect(find.text('Số tài khoản'), findsOneWidget);
      expect(find.text('19031234567890'), findsOneWidget);
      expect(find.text('Chủ tài khoản'), findsOneWidget);
      expect(find.text('NGUYEN VAN A'), findsOneWidget);

      // Không có dropdown tương tác khi đang khóa
      expect(find.byKey(const ValueKey('host-bank-account-name')), findsNothing);
    });

    testWidgets('Khi bấm Chỉnh sửa: hiển thị DropdownButtonFormField trên HostProfile', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(testHostProfile)),
            userProfileServiceProvider.overrideWithValue(_FakeUserProfileService(fakeAccount)),
          ],
          child: const MaterialApp(
            home: HostProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('host-bank-account-name')), findsOneWidget);
    });
  });
}
