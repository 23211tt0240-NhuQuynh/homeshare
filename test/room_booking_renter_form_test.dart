import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/renter/screens/room_booking_detail_screen.dart';

RoomModel _room() {
  return RoomModel(
    id: 'post-001',
    title: 'Phòng trọ kiểm thử',
    description: 'Mô tả',
    price: 2500000,
    deposit: 1500000,
    address: 'TP. Hồ Chí Minh',
    district: 'Thủ Đức',
    area: 20,
    roomType: 'Phòng trọ',
    amenities: const [],
    images: const [],
    hostId: 'host-001',
    hostName: 'Chủ nhà',
    hostPhone: '0909000000',
    createdAt: DateTime(2026, 10, 20),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'form người thuê bỏ nghề nghiệp, bỏ ghi chú và tự điền tên, số điện thoại, giới tính',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final profile = UserProfile(
        uid: 'renter-001',
        email: 'renter@example.com',
        displayName: 'Trần Thanh Anh Toàn',
        phoneNumber: '0382542737',
        gender: 'nu',
        occupation: 'Sinh viên',
        birthDate: DateTime(2000, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            userProfileProvider.overrideWith((ref) => Stream.value(profile)),
          ],
          child: MaterialApp(home: RoomBookingDetailScreen(room: _room())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Nghề nghiệp / Trường học hoặc Nơi làm việc'),
        findsNothing,
      );
      expect(find.textContaining('không yêu cầu xác thực CCCD'), findsNothing);
      expect(find.text('Tuổi'), findsOneWidget);
      expect(find.text('Tuổi / Năm sinh'), findsNothing);

      await tester.ensureVisible(find.text('Lấy từ tài khoản'));
      await tester.tap(find.text('Lấy từ tài khoản'));
      await tester.pump();

      final fieldValues = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text ?? '')
          .toList();
      expect(fieldValues, contains('Trần Thanh Anh Toàn'));
      expect(fieldValues, contains('0382542737'));
      expect(fieldValues, isNot(contains('Sinh viên')));
      expect(fieldValues.where((value) => value.contains('tuổi')), isEmpty);
      expect(
        tester.widget<Text>(find.text('Nữ')).style?.fontWeight,
        FontWeight.bold,
      );

      final ageFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'VD: 20',
      );
      expect(ageFieldFinder, findsOneWidget);
      await tester.enterText(ageFieldFinder, '20 tuổi abc');
      final ageField = tester.widget<TextField>(ageFieldFinder);
      expect(ageField.controller?.text, '20');
    },
  );

  testWidgets(
    'thanh toán toàn bộ chỉ tính tiền thuê phòng, không cộng tiền cọc',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            userProfileProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(home: RoomBookingDetailScreen(room: _room())),
        ),
      );
      await tester.pumpAndSettle();

      final fullPayment = find.text('Thanh toán toàn bộ');
      expect(fullPayment, findsOneWidget);
      await tester.ensureVisible(fullPayment);
      await tester.tap(fullPayment);
      await tester.pump();

      expect(find.textContaining('4.000.000'), findsNothing);
      expect(find.textContaining('2.500.000'), findsWidgets);
      expect(find.textContaining('không bao gồm tiền cọc'), findsOneWidget);
      expect(find.textContaining('Bao gồm cọc'), findsNothing);
    },
  );
}
