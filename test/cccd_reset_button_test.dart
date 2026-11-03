import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/profile/screens/personal_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cccd_verified_USER_1': true,
      'cccd_number_USER_1': '051206004529',
      'cccd_name_USER_1': 'Trần Thanh Anh Toàn',
      'draft_cccd_data_json': '{"fullName":"Trần Thanh Anh Toàn"}',
    });
  });

  group('CCCD Reset Verification For Testing Tests', () {
    test('resetCccdVerificationForTesting dọn sạch SharedPreferences và draft cache', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cccd_verified_USER_1'), isTrue);
      expect(prefs.getString('draft_cccd_data_json'), isNotNull);

      // Gọi hàm reset (kèm try-catch Firestore khi offline test)
      await resetCccdVerificationForTesting(uid: 'USER_1');

      // Xác thực toàn bộ cache CCCD và draft bị xóa sạch
      expect(prefs.getBool('cccd_verified_USER_1'), isNull);
      expect(prefs.getString('cccd_number_USER_1'), isNull);
      expect(prefs.getString('cccd_name_USER_1'), isNull);
      expect(prefs.getString('draft_cccd_data_json'), isNull);
      expect(prefs.getString('draft_cccd_front_image'), isNull);
      expect(prefs.getString('draft_cccd_back_image'), isNull);
    });

    testWidgets('PersonalProfileScreen hiển thị nút "Xóa xác thực CCCD (để test lại)" khi đã xác thực', (tester) async {
      final verifiedProfile = UserProfile(
        uid: 'USER_1',
        displayName: 'Trần Thanh Anh Toàn',
        email: 'toan@email.com',
        phoneNumber: '0382542737',
        isCccdVerified: true,
        cccdNumber: '051206004529',
        cccdFullName: 'Trần Thanh Anh Toàn',
        cccdHometown: 'Quảng Ngãi',
        gender: 'nam',
        birthDate: DateTime(2006, 8, 21),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(verifiedProfile)),
          ],
          child: const MaterialApp(
            home: PersonalProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Huy hiệu xanh "Đã xác thực VNeID / CCCD"
      expect(find.text('Đã xác thực VNeID / CCCD'), findsOneWidget);

      // Nút xóa màu đỏ phục vụ kiểm thử
      final resetBtn = find.text('Xóa xác thực CCCD (để test lại)');
      expect(resetBtn, findsOneWidget);

      // Chạm vào nút xóa -> Mở dialog xác nhận
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Xóa xác thực CCCD?'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xóa để test'), findsOneWidget);
    });

    testWidgets('PersonalProfileScreen KHÔNG hiển thị nút xóa khi chưa xác thực', (tester) async {
      final unverifiedProfile = UserProfile(
        uid: 'USER_2',
        displayName: 'Nguyễn Văn B',
        email: 'b@email.com',
        phoneNumber: '0988776655',
        isCccdVerified: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(unverifiedProfile)),
          ],
          child: const MaterialApp(
            home: PersonalProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Huy hiệu chưa xác thực
      expect(find.text('Chưa xác thực VNeID / CCCD'), findsOneWidget);

      // Nút xóa không được hiển thị
      expect(find.text('Xóa xác thực CCCD (để test lại)'), findsNothing);
    });
  });
}
