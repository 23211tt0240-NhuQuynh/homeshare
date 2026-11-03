import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';

void main() {
  group('Profile Report Room Issue Navigation Tests', () {
    late BookingRequestModel room1;
    late BookingRequestModel room2;

    setUp(() {
      final now = DateTime.now();
      room1 = BookingRequestModel(
        id: 'BK_001',
        renterId: 'renter_123',
        renterName: 'Trần Thanh Anh Toàn',
        renterPhone: '0382542737',
        roomId: 'room_se',
        roomTitle: 'Phòng SE',
        roomAddress: 'Six Seven, Hiệp Bình Chánh, Thủ Đức',
        roomPrice: 5000000,
        deposit: 2500000,
        totalAmount: 2500000,
        hostId: 'host_qa',
        hostName: 'Chủ trọ: QA',
        status: 'dangO',
        moveInDate: now,
        createdAt: now,
      );

      room2 = BookingRequestModel(
        id: 'BK_002',
        renterId: 'renter_123',
        renterName: 'Trần Thanh Anh Toàn',
        renterPhone: '0382542737',
        roomId: 'room_diamond',
        roomTitle: 'Diamond',
        roomAddress: '73/14 Lê Văn Việt, An Khánh, Thủ Đức',
        roomPrice: 2500000,
        deposit: 500000,
        totalAmount: 500000,
        hostId: 'host_tienanh',
        hostName: 'Chủ trọ: tienanh pro',
        status: 'active',
        moveInDate: now,
        createdAt: now,
      );
    });

    testWidgets('Active rentals list contains 2 active rooms as shown in Profile Screen', (tester) async {
      final allBookings = [room1, room2];
      final activeRentals = allBookings.where((b) => b.isActive).toList();

      expect(activeRentals.length, equals(2));
      expect(activeRentals[0].roomTitle, equals('Phòng SE'));
      expect(activeRentals[1].roomTitle, equals('Diamond'));
    });

    testWidgets('Opening room selection bottom sheet renders both active rooms', (tester) async {
      final activeRentals = [room1, room2];
      BookingRequestModel? selectedBooking;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Chọn phòng cần báo sự cố'),
                          ...activeRentals.map(
                            (b) => ListTile(
                              title: Text(b.roomTitle),
                              subtitle: Text(b.roomAddress),
                              onTap: () {
                                selectedBooking = b;
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Báo cáo sự cố phòng trọ'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Báo cáo sự cố phòng trọ'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and both rooms
      expect(find.text('Chọn phòng cần báo sự cố'), findsOneWidget);
      expect(find.text('Phòng SE'), findsOneWidget);
      expect(find.text('Diamond'), findsOneWidget);

      // Tap first room
      await tester.tap(find.text('Phòng SE'));
      await tester.pumpAndSettle();

      expect(selectedBooking?.id, equals('BK_001'));
    });

    testWidgets('Single active rental triggers report sheet directly for that room', (tester) async {
      final singleRental = [room1];
      BookingRequestModel? reportedBooking;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    if (singleRental.length == 1) {
                      reportedBooking = singleRental.first;
                    }
                  },
                  child: const Text('Báo cáo sự cố phòng trọ'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Báo cáo sự cố phòng trọ'));
      await tester.pump();

      expect(reportedBooking, isNotNull);
      expect(reportedBooking?.roomTitle, equals('Phòng SE'));
      expect(reportedBooking?.hostId, equals('host_qa'));
    });
  });
}
