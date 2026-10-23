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
  String? get phoneNumber => null;
  @override
  String? get photoURL => null;

  _MockUser(this.uid, {this.displayName, this.email});
}

class _MockBookingService extends Fake implements BookingService {
  final List<String> cancelledBookingIds = [];
  final List<String> cancelReasons = [];

  @override
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    cancelledBookingIds.add(bookingId);
    if (reason != null) cancelReasons.add(reason);
  }
}

void main() {
  testWidgets('Đơn pending_payment hiển thị ở mục Đang xử lý kèm thời gian và nút Thanh toán', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const userId = 'renter-pending-user';
    final now = DateTime.now();
    // Tạo đơn 1 tiếng trước -> còn khoảng 5 tiếng
    final booking = BookingRequestModel(
      id: 'booking-pending-01',
      renterId: userId,
      renterName: 'Khách Chờ Thanh Toán',
      renterPhone: '0909111222',
      roomId: 'room-pending-01',
      roomTitle: 'Phòng Studio Quận 7',
      roomAddress: '123 Nguyễn Thị Thập, Quận 7, TP. HCM',
      roomPrice: 4000000,
      deposit: 1000000,
      totalAmount: 4000000,
      rentalMonths: 12,
      hostId: 'host-01',
      hostName: 'Chủ Trọ A',
      status: 'pending_payment',
      moveInDate: now.add(const Duration(days: 3)),
      createdAt: now.subtract(const Duration(hours: 1)),
    );

    final profile = UserProfile(
      uid: userId,
      displayName: 'Khách Chờ Thanh Toán',
      email: 'pending@example.com',
      phoneNumber: '0909111222',
    );

    final mockBookingService = _MockBookingService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => _MockUser(
              userId,
              displayName: 'Khách Chờ Thanh Toán',
              email: 'pending@example.com',
            ),
          ),
          userProfileProvider.overrideWith((ref) => Stream.value(profile)),
          bookingServiceProvider.overrideWithValue(mockBookingService),
          renterBookingsStreamProvider(
            userId,
          ).overrideWith((ref) => Stream.value([booking])),
        ],
        child: const MaterialApp(home: RenterBookingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Kiểm tra filter chip 'Đang xử lý' xuất hiện
    expect(find.text('Đang xử lý'), findsWidgets);

    // 2. Kiểm tra trạng thái đơn hiển thị 'Đang xử lý • Chờ thanh toán'
    expect(find.text('Đang xử lý • Chờ thanh toán'), findsOneWidget);

    // 3. Kiểm tra thông tin phòng hiển thị đúng
    expect(find.text('Phòng Studio Quận 7'), findsOneWidget);

    // 4. Kiểm tra có thời gian thanh toán còn lại (khoảng 4g 59p hoặc 5g)
    expect(find.textContaining('Thời gian thanh toán còn lại'), findsOneWidget);

    // 5. Kiểm tra có nút 'Thanh toán' và nút 'Hủy'
    expect(find.text('Thanh toán'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
  });

  testWidgets('Đơn pending_payment quá hạn 6 tiếng sẽ tự động gọi hủy đơn', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const userId = 'renter-expired-user';
    final now = DateTime.now();
    // Tạo đơn 7 tiếng trước -> đã quá hạn 6 tiếng
    final booking = BookingRequestModel(
      id: 'booking-expired-01',
      renterId: userId,
      renterName: 'Khách Quá Hạn',
      renterPhone: '0909333444',
      roomId: 'room-expired-01',
      roomTitle: 'Phòng Quá Hạn',
      roomAddress: '456 Lê Văn Việt, TP. Thủ Đức',
      roomPrice: 3500000,
      deposit: 1000000,
      totalAmount: 3500000,
      rentalMonths: 6,
      hostId: 'host-02',
      hostName: 'Chủ Trọ B',
      status: 'pending_payment',
      moveInDate: now.add(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(hours: 7)),
    );

    final profile = UserProfile(
      uid: userId,
      displayName: 'Khách Quá Hạn',
      email: 'expired@example.com',
      phoneNumber: '0909333444',
    );

    final mockBookingService = _MockBookingService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => _MockUser(userId, displayName: 'Khách Quá Hạn'),
          ),
          userProfileProvider.overrideWith((ref) => Stream.value(profile)),
          bookingServiceProvider.overrideWithValue(mockBookingService),
          renterBookingsStreamProvider(
            userId,
          ).overrideWith((ref) => Stream.value([booking])),
        ],
        child: const MaterialApp(home: RenterBookingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Kiểm tra hệ thống tự động gọi cancelBooking với ID của đơn và lý do 6 tiếng
    expect(mockBookingService.cancelledBookingIds, contains('booking-expired-01'));
    expect(
      mockBookingService.cancelReasons.first,
      contains('Tự động hủy do quá thời gian thanh toán 6 tiếng'),
    );
  });
}
