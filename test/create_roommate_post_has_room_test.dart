import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/booking_service.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/renter/screens/create_roommate_post_screen.dart';

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? phoneNumber;
  @override
  final String? photoURL;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
  });
}

void main() {
  group('CreateRoommatePostScreen - Has Room Constraint Tests', () {
    testWidgets(
      '1. Khi người dùng chưa có phòng: ô "Đã có phòng" bị vô hiệu hóa, hiển thị nhãn "Chưa thuê phòng" và không thể tích chọn',
      (tester) async {
        final mockProfile = UserProfile(
          uid: 'user_no_room',
          email: 'noroom@test.com',
          displayName: 'Nguyễn Văn A',
          phoneNumber: '0912345678',
          role: 'renter',
          occupation: 'Sinh viên',
          birthDate: DateTime(2002, 5, 20),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
              currentUserProvider.overrideWith((ref) => MockUser(uid: 'user_no_room', displayName: 'Nguyễn Văn A')),
              userProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
              renterBookingsStreamProvider('user_no_room')
                  .overrideWith((ref) => Stream.value(<BookingRequestModel>[])),
            ],
            child: const MaterialApp(
              home: CreateRoommatePostScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Nhập đủ thông tin Bước 1
        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(4));
        await tester.enterText(textFields.at(0), 'Nguyễn Văn A');
        await tester.enterText(textFields.at(1), '22');
        await tester.enterText(textFields.at(2), 'Sinh viên');
        await tester.enterText(textFields.at(3), '0912345678');
        await tester.pumpAndSettle();

        // Nhấn nút "Tiếp tục" từ Bước 1 sang Bước 2
        final nextButton = find.text('Tiếp tục');
        expect(nextButton, findsOneWidget);
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // 2. Tại Bước 2: Kiểm tra thẻ "Đã có phòng" hiển thị nhãn "Chưa thuê phòng"
        expect(find.text('Chưa thuê phòng'), findsOneWidget);
        expect(find.text('Chưa có phòng'), findsOneWidget);

        // 3. Hiển thị thông điệp cảnh báo người dùng chưa có hợp đồng thuê phòng
        expect(find.textContaining('Tài khoản của bạn chưa có hợp đồng thuê phòng nào đang hoạt động'), findsOneWidget);

        // 4. Nhấn vào thẻ "Đã có phòng" -> Không cho phép chọn và hiện SnackBar thông báo
        await tester.tap(find.text('Đã có phòng'));
        await tester.pump();

        expect(
          find.text('Bạn hiện chưa có phòng đang thuê trên hệ thống nên không thể chọn "Đã có phòng". Vui lòng chọn "Chưa có phòng" để tìm bạn cùng thuê.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Khi người dùng ĐÃ CÓ PHÒNG thuê thực tế: ô "Đã có phòng" cho phép tích chọn và hiển thị gợi ý phòng đang thuê',
      (tester) async {
        final mockProfile = UserProfile(
          uid: 'user_has_room',
          email: 'hasroom@test.com',
          displayName: 'Trần Thị B',
          phoneNumber: '0987654321',
          role: 'renter',
          occupation: 'Nhân viên văn phòng',
          birthDate: DateTime(2001, 8, 15),
        );

        final activeBooking = BookingRequestModel(
          id: 'booking_123',
          renterId: 'user_has_room',
          renterName: 'Trần Thị B',
          renterPhone: '0987654321',
          renterGender: 'Nữ',
          roomId: 'room_thu_duc',
          roomTitle: 'Phòng trọ ban công Linh Trung',
          roomAddress: '12 Đường Số 8, Linh Trung, Thủ Đức',
          roomPrice: 3200000,
          deposit: 3200000,
          totalAmount: 3200000,
          rentalMonths: 6,
          hostId: 'host_001',
          hostName: 'Chủ trọ An',
          status: 'dangO', // Trạng thái đang ở (isActive = true)
          paymentOption: 'deposit',
          moveInDate: DateTime.now(),
          note: '',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
              currentUserProvider.overrideWith((ref) => MockUser(uid: 'user_has_room', displayName: 'Trần Thị B')),
              userProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
              renterBookingsStreamProvider('user_has_room')
                  .overrideWith((ref) => Stream.value(<BookingRequestModel>[activeBooking])),
            ],
            child: const MaterialApp(
              home: CreateRoommatePostScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Điền Bước 1 và chuyển sang Bước 2
        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(4));
        await tester.enterText(textFields.at(0), 'Trần Thị B');
        await tester.enterText(textFields.at(1), '21');
        await tester.enterText(textFields.at(2), 'Nhân viên văn phòng');
        await tester.enterText(textFields.at(3), '0987654321');
        await tester.pumpAndSettle();

        final nextButton = find.text('Tiếp tục');
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Kiểm tra không có badge "Chưa thuê phòng"
        expect(find.text('Chưa thuê phòng'), findsNothing);

        // Thẻ "Đã có phòng" được chọn và hiển thị box "Phòng đang thuê: ..." kèm nút "Điền nhanh"
        expect(find.textContaining('Phòng đang thuê: Phòng trọ ban công Linh Trung'), findsOneWidget);
        expect(find.text('Điền nhanh'), findsOneWidget);

        // Nhấn nút "Điền nhanh" để tự động điền tiêu đề và địa chỉ phòng
        await tester.tap(find.text('Điền nhanh'));
        await tester.pumpAndSettle();

        // Kiểm tra tiêu đề đã được điền tự động
        expect(find.text('Tìm bạn ở ghép - Phòng trọ ban công Linh Trung'), findsOneWidget);
      },
    );
  });
}
