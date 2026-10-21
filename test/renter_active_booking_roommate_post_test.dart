import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/booking_service.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/renter/screens/renter_bookings_screen.dart';

class _MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  final String? phoneNumber;
  @override
  String? get photoURL => null;

  _MockUser(this.uid, {this.displayName, this.email, this.phoneNumber});
}

void main() {
  testWidgets('đơn đang ở có nút gửi tin ở ghép và mở đúng màn hình đăng tin', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const userId = 'renter-active';
    final booking = BookingRequestModel(
      id: 'booking-active',
      renterId: userId,
      renterName: 'Người thuê',
      renterPhone: '0909000000',
      roomId: 'room-001',
      roomTitle: 'Phòng đang thuê P003',
      roomAddress:
          '66 Lê Văn Tăng, Phường Phước Long A, Thành phố Thủ Đức, TP. Hồ Chí Minh',
      roomPrice: 3000000,
      deposit: 600000,
      totalAmount: 3000000,
      rentalMonths: 6,
      hostId: 'host-001',
      hostName: 'QA',
      status: 'active',
      moveInDate: DateTime(2026, 10, 20),
      createdAt: DateTime(2026, 10, 19),
    );
    final profile = UserProfile(
      uid: userId,
      displayName: 'Người thuê',
      email: 'renter@example.com',
      phoneNumber: '0909000000',
      gender: 'nam',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => _MockUser(
              userId,
              displayName: 'Người thuê',
              email: 'renter@example.com',
              phoneNumber: '0909000000',
            ),
          ),
          userProfileProvider.overrideWith((ref) => Stream.value(profile)),
          renterBookingsStreamProvider(
            userId,
          ).overrideWith((ref) => Stream.value([booking])),
        ],
        child: const MaterialApp(home: RenterBookingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final sendRoommatePost = find.text('Gửi tin ở ghép');
    expect(sendRoommatePost, findsOneWidget);
    await tester.tap(sendRoommatePost);
    await tester.pumpAndSettle();

    expect(find.text('Đăng tin tìm ở ghép'), findsOneWidget);
  });
}
