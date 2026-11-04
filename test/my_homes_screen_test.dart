import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/booking_service.dart';
import 'package:home_share/core/services/resident_service.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/renter/screens/my_homes_screen.dart';
import 'package:home_share/features/renter/screens/my_home_detail_screen.dart';

void main() {
  group('MyHomesScreen & PastRentalHomeItem Tests', () {
    test('PastRentalHomeItem constructs correctly with all details', () {
      final moveIn = DateTime(2026, 1, 10);
      final moveOut = DateTime(2026, 7, 10);

      final item = PastRentalHomeItem(
        id: 'CR_001',
        roomId: 'ROOM_302',
        roomTitle: 'Phòng 302 Dãy A',
        roomAddress: '123 Đường Điện Biên Phủ, Bình Thạnh',
        hostId: 'HOST_99',
        hostName: 'Nguyễn Văn Chủ',
        hostPhone: '0901234567',
        roomPrice: 3500000,
        depositAmount: 3500000,
        deductionAmount: 200000,
        refundAmount: 3300000,
        moveInDate: moveIn,
        moveOutDate: moveOut,
        status: 'Đã hoàn tất trả phòng',
        note: 'Bàn giao đầy đủ 2 chìa khóa, phòng sạch sẽ',
        finalElectricityMeter: 1420.5,
        finalWaterMeter: 85.0,
        hasCheckoutRecord: true,
      );

      expect(item.id, equals('CR_001'));
      expect(item.roomId, equals('ROOM_302'));
      expect(item.roomPrice, equals(3500000));
      expect(item.depositAmount, equals(3500000));
      expect(item.deductionAmount, equals(200000));
      expect(item.refundAmount, equals(3300000));
      expect(item.hasCheckoutRecord, isTrue);
      expect(item.finalElectricityMeter, equals(1420.5));
      expect(item.finalWaterMeter, equals(85.0));
      expect(item.moveOutDate, equals(moveOut));
    });

    test('BookingRequestModel isActive correctly segregates active vs past homes', () {
      final activeBooking = BookingRequestModel(
        id: 'BK_ACTIVE',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_1',
        roomTitle: 'Phòng đang ở',
        roomAddress: '123 Test St',
        roomPrice: 3000000,
        deposit: 3000000,
        status: 'active',
        moveInDate: DateTime.now(),
        createdAt: DateTime.now(),
        hostName: 'Chủ trọ A',
      );

      final completedBooking = BookingRequestModel(
        id: 'BK_PAST',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_2',
        roomTitle: 'Phòng đã ở trước đây',
        roomAddress: '456 Test St',
        roomPrice: 3200000,
        deposit: 3200000,
        status: 'completed',
        moveInDate: DateTime(2025, 5, 1),
        createdAt: DateTime(2025, 5, 1),
        hostName: 'Chủ trọ B',
      );

      final checkedOutBooking = BookingRequestModel(
        id: 'BK_CHECKED_OUT',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_3',
        roomTitle: 'Phòng đã check-out',
        roomAddress: '789 Test St',
        roomPrice: 4000000,
        deposit: 4000000,
        status: 'checked_out',
        moveInDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        hostName: 'Chủ trọ C',
      );

      expect(activeBooking.isActive, isTrue);
      expect(completedBooking.isActive, isFalse);
      expect(checkedOutBooking.isActive, isFalse);
      expect(checkedOutBooking.isCancelled, isFalse);
      expect(checkedOutBooking.isCheckedOut, isTrue);

      final allBookings = [activeBooking, completedBooking, checkedOutBooking];
      final activeHomes = allBookings.where((b) => b.isActive).toList();
      expect(activeHomes.length, equals(1));
      expect(activeHomes.first.id, equals('BK_ACTIVE'));

      final checkedOutHomes = allBookings.where((b) => b.isCheckedOut).toList();
      expect(checkedOutHomes.length, equals(2)); // BK_PAST (completed) và BK_CHECKED_OUT
      expect(checkedOutHomes.any((b) => b.id == 'BK_CHECKED_OUT'), isTrue);

      final cancelledHomes = allBookings.where((b) => b.isCancelled).toList();
      expect(cancelledHomes.length, equals(0)); // Không vào đã hủy
    });

    test('BookingRequestModel correctly classifies checkout and moved_out as isCheckedOut (Lịch sử đã ở, KHÔNG vào đã hủy)', () {
      final movedOutBooking = BookingRequestModel(
        id: 'BK_MOVED_OUT',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_4',
        roomTitle: 'Phòng đã dọn đi',
        roomAddress: '101 Test St',
        roomPrice: 3500000,
        deposit: 3500000,
        status: 'moved_out',
        moveInDate: DateTime.now().subtract(const Duration(days: 60)),
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        hostName: 'Chủ trọ D',
      );

      final daRoiBooking = BookingRequestModel(
        id: 'BK_DA_ROI',
        renterId: 'RENTER_1',
        renterName: 'Lê Văn Thuê',
        renterPhone: '0911222333',
        roomId: 'ROOM_5',
        roomTitle: 'Phòng đã rời',
        roomAddress: '102 Test St',
        roomPrice: 3000000,
        deposit: 3000000,
        status: 'daRoi',
        moveInDate: DateTime.now().subtract(const Duration(days: 90)),
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        hostName: 'Chủ trọ E',
      );

      expect(movedOutBooking.isActive, isFalse);
      expect(movedOutBooking.isCancelled, isFalse);
      expect(movedOutBooking.isCheckedOut, isTrue);
      expect(movedOutBooking.statusDisplayVi, equals('Đã trả phòng'));

      expect(daRoiBooking.isActive, isFalse);
      expect(daRoiBooking.isCancelled, isFalse);
      expect(daRoiBooking.isCheckedOut, isTrue);
      expect(daRoiBooking.statusDisplayVi, equals('Đã trả phòng'));
    });
  });

  group('Room Title Suffix Normalization & Live Hydration Tests', () {
    test(
      'booking đã hủy có roomTitle snapshot "Thiên thượng thiên hạ" nhưng live host_rooms title "QM08-01" thì tên hiển thị trả về "QM08-1"',
      () {
        final resolvedTitle = BookingService.resolveLiveRoomTitle(
          bookingTitle: 'Thiên thượng thiên hạ',
          roomData: {
            'id': 'NCQ3ZSCCEN34',
            'title': 'QM08-01',
          },
        );
        expect(resolvedTitle, equals('QM08-1'));
      },
    );

    test('fallback: nếu live title rỗng thì giữ booking title', () {
      final fallbackEmptyMap = BookingService.resolveLiveRoomTitle(
        bookingTitle: 'Thiên thượng thiên hạ',
        roomData: {
          'id': 'NCQ3ZSCCEN34',
          'title': '',
        },
      );
      expect(fallbackEmptyMap, equals('Thiên thượng thiên hạ'));

      final fallbackNullData = BookingService.resolveLiveRoomTitle(
        bookingTitle: 'Thiên thượng thiên hạ',
        roomData: null,
      );
      expect(fallbackNullData, equals('Thiên thượng thiên hạ'));

      final fallbackMissingKey = BookingService.resolveLiveRoomTitle(
        bookingTitle: 'Thiên thượng thiên hạ',
        roomData: {'id': 'NCQ3ZSCCEN34'},
      );
      expect(fallbackMissingKey, equals('Thiên thượng thiên hạ'));
    });

    test('các tên không có hậu tố số 0 đầu không bị đổi', () {
      expect(BookingService.formatRoomTitle('QM08-1'), equals('QM08-1'));
      expect(BookingService.formatRoomTitle('Phòng 101'), equals('Phòng 101'));
      expect(BookingService.formatRoomTitle('Phòng A-10'), equals('Phòng A-10'));
      expect(
        BookingService.formatRoomTitle('Thiên thượng thiên hạ'),
        equals('Thiên thượng thiên hạ'),
      );
      expect(
        BookingService.formatRoomTitle('Nhà trọ Hoa Mai'),
        equals('Nhà trọ Hoa Mai'),
      );
    });

    test(
      'chuẩn hóa riêng hậu tố số phòng dạng -01 thành -1 (và -002 thành -2), không đụng giữa chuỗi',
      () {
        expect(BookingService.formatRoomTitle('QM08-01'), equals('QM08-1'));
        expect(BookingService.formatRoomTitle('QM08-002'), equals('QM08-2'));
        expect(BookingService.formatRoomTitle('Phòng-09'), equals('Phòng-9'));
        expect(BookingService.formatRoomTitle('QM-08-01'), equals('QM-08-1'));
        expect(
          BookingService.formatRoomTitle('QM08-Phòng'),
          equals('QM08-Phòng'),
        );
      },
    );

    test(
      'booking model cho card Quản lý đơn thuê hiển thị đúng live title QM08-1 thay vì snapshot cũ',
      () {
        final cancelledBooking = BookingRequestModel(
          id: 'BK_NCQ3ZSCCEN34',
          renterId: 'RENTER_1',
          renterName: 'Khách thuê',
          renterPhone: '0901234567',
          roomId: 'NCQ3ZSCCEN34',
          roomTitle: 'Thiên thượng thiên hạ', // snapshot cũ trong bookings
          roomAddress: 'Địa chỉ phòng trọ',
          roomPrice: 3500000,
          deposit: 3500000,
          status: 'cancelled',
          moveInDate: DateTime.now(),
          createdAt: DateTime.now(),
          hostName: 'Chủ trọ',
        );

        final liveTitle = BookingService.resolveLiveRoomTitle(
          bookingTitle: cancelledBooking.roomTitle,
          roomData: {
            'id': 'NCQ3ZSCCEN34',
            'title': 'QM08-01',
          },
        );
        final displayBooking = cancelledBooking.copyWith(roomTitle: liveTitle);

        expect(displayBooking.roomTitle, equals('QM08-1'));
        expect(displayBooking.isCancelled, isTrue);
      },
    );
  });

  group('Resident Check-in & Đang ở (Active Stay) Synchronization Tests', () {
    test('BookingRequestModel.isActive returns true for all check-in and active statuses', () {
      final statuses = [
        'active',
        'dangO',
        'dang_o',
        'daNhanPhong',
        'da_nhan_phong',
        'checkin',
        'checked_in',
        'staying',
        'occupied',
      ];

      for (final s in statuses) {
        final b = BookingRequestModel(
          id: 'BK_$s',
          renterId: 'RENTER_1',
          renterName: 'Khách',
          renterPhone: '0901234567',
          roomId: 'ROOM_1',
          roomTitle: 'Phòng 1',
          roomAddress: 'Địa chỉ',
          roomPrice: 3000000,
          status: s,
          moveInDate: DateTime.now(),
          createdAt: DateTime.now(),
          hostName: 'Chủ trọ',
        );
        expect(b.isActive, isTrue, reason: 'Status $s must be active');
        expect(b.isCancelled, isFalse, reason: 'Status $s must not be cancelled');
      }
    });

    test('ResidentService.isActive recognizes checkin, danhanphong, dango, active', () {
      for (final s in ['dangO', 'active', 'checkin', 'checked_in', 'danhanphong', 'staying']) {
        final resident = ResidentModel(
          id: 'RES_$s',
          periodId: 'PERIOD_1',
          roomId: 'ROOM_1',
          userId: 'USER_1',
          fullName: 'Khách',
          statusId: s,
          moveInDate: DateTime.now(),
        );
        expect(ResidentService.isActive(resident), isTrue, reason: 'Status $s must be active resident');
      }
    });

    test('ResidentService.isActive returns false for checkout, moved_out, daRoi or past moveOutDate', () {
      final movedOutRes = ResidentModel(
        id: 'RES_MOVED_OUT',
        periodId: 'PERIOD_1',
        roomId: 'ROOM_1',
        userId: 'USER_1',
        fullName: 'Khách',
        statusId: 'daRoi',
        moveInDate: DateTime(2026, 1, 1),
        moveOutDate: DateTime(2026, 1, 15),
      );
      expect(ResidentService.isActive(movedOutRes), isFalse);

      final pastDateRes = ResidentModel(
        id: 'RES_PAST',
        periodId: 'PERIOD_2',
        roomId: 'ROOM_1',
        userId: 'USER_1',
        fullName: 'Khách',
        statusId: 'dangO',
        moveInDate: DateTime(2026, 1, 1),
        moveOutDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(ResidentService.isActive(pastDateRes), isFalse);
    });

    test('mergeRenterStayLists does not drop active resident stays when an old cancelled booking exists', () {
      final cancelledBooking = BookingRequestModel(
        id: 'BK_OLD_CANCELLED',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'PWFFQHMBU783',
        roomTitle: 'Phòng cũ đã hủy',
        roomAddress: 'Địa chỉ',
        roomPrice: 3000000,
        status: 'cancelled',
        moveInDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        hostName: 'Chủ trọ',
      );

      final activeStay = BookingRequestModel(
        id: 'RES_PWFFQHMBU783',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'PWFFQHMBU783',
        roomTitle: 'QM08-1',
        roomAddress: 'Địa chỉ',
        roomPrice: 3000000,
        status: 'dangO',
        moveInDate: DateTime.now(),
        createdAt: DateTime.now(),
        hostName: 'Chủ trọ',
      );

      final merged = BookingService.mergeRenterStayLists(
        bookings: [cancelledBooking],
        residentStays: [activeStay],
      );

      // Cả 2 đơn đều tồn tại: 1 đơn đã hủy và 1 đơn đang ở
      expect(merged.length, equals(2));
      final activeList = merged.where((b) => b.isActive).toList();
      expect(activeList.length, equals(1));
      expect(activeList.first.id, equals('RES_PWFFQHMBU783'));
      expect(activeList.first.roomTitle, equals('QM08-1'));
    });

    test('mergeRenterStayLists deduplicates when an active booking and active stay exist for the same room', () {
      final activeBooking = BookingRequestModel(
        id: 'BK_ACTIVE',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'ROOM_1',
        roomTitle: 'QM08-1',
        roomAddress: 'Địa chỉ',
        roomPrice: 3000000,
        status: 'dangO',
        moveInDate: DateTime.now(),
        createdAt: DateTime.now(),
        hostName: 'Chủ trọ',
      );

      final activeStay = BookingRequestModel(
        id: 'RES_ROOM_1',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'ROOM_1',
        roomTitle: 'QM08-1',
        roomAddress: 'Địa chỉ',
        roomPrice: 3000000,
        status: 'dangO',
        moveInDate: DateTime.now(),
        createdAt: DateTime.now(),
        hostName: 'Chủ trọ',
      );

      final merged = BookingService.mergeRenterStayLists(
        bookings: [activeBooking],
        residentStays: [activeStay],
      );

      // Trùng phòng đang ở thì chỉ giữ 1
      expect(merged.length, equals(1));
      expect(merged.first.id, equals('BK_ACTIVE'));
    });

    test('mergeRenterStayLists giữ lại đơn checkout (checked_out) từ resident vào lịch sử đã ở (không vào đã hủy)', () {
      final oldActiveBooking = BookingRequestModel(
        id: 'BK_PAST',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'ROOM_BOOKING_PAST',
        roomTitle: 'Phòng cũ',
        roomAddress: 'Địa chỉ',
        roomPrice: 3000000,
        status: 'completed',
        moveInDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        hostName: 'Chủ trọ',
      );

      final checkedOutStay = BookingRequestModel(
        id: 'RES_CHECKOUT',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'ROOM_RESIDENT_PAST',
        roomTitle: 'QM08-1',
        roomAddress: 'Địa chỉ',
        roomPrice: 3000000,
        status: 'checked_out',
        note: 'Đã hoàn tất trả phòng',
        moveInDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        hostName: 'Chủ trọ',
      );

      final merged = BookingService.mergeRenterStayLists(
        bookings: [oldActiveBooking],
        residentStays: [checkedOutStay],
      );

      expect(merged.length, equals(2));
      final checkedOutList = merged.where((b) => b.isCheckedOut).toList();
      expect(checkedOutList.length, equals(2));

      final cancelledList = merged.where((b) => b.isCancelled).toList();
      expect(cancelledList.length, equals(0)); // Không vào đã hủy
    });

    test('resolveLiveRoomTitle không lấy title của post mà lấy title/roomCode từ host_rooms', () {
      // Khi dữ liệu từ post (không phải host_rooms), không được lấy title bài đăng dài dòng
      final postData = {
        'id': 'POST_123',
        'title': 'Phòng trọ cao cấp gần trường ĐH giá rẻ',
        'roomCode': 'QM08-01',
        '_isHostRoom': false,
      };

      final titleFromPost = BookingService.resolveLiveRoomTitle(
        bookingTitle: 'Phòng trọ cao cấp gần trường ĐH giá rẻ',
        roomData: postData,
      );
      expect(titleFromPost, equals('QM08-1'));

      // Khi dữ liệu từ host_rooms, lấy title từ host_rooms
      final hostRoomData = {
        'id': 'NCQ3ZSCCEN34',
        'title': 'QM08-01',
        'propertyId': 'PROP_1',
        '_isHostRoom': true,
      };

      final titleFromHostRoom = BookingService.resolveLiveRoomTitle(
        bookingTitle: 'Thiên thượng thiên hạ',
        roomData: hostRoomData,
      );
      expect(titleFromHostRoom, equals('QM08-1'));
    });
  });

  group('MyHomeDetailScreen Tests', () {
    test('MyHomeDetailScreen initializes with active booking', () {
      final booking = BookingRequestModel(
        id: 'BK_TEST',
        renterId: 'RENTER_1',
        renterName: 'Khách thuê',
        renterPhone: '0901234567',
        roomId: 'ROOM_1',
        roomTitle: 'Phòng 101',
        roomAddress: '123 Đường số 1, Q.Bình Thạnh',
        roomPrice: 3500000,
        status: 'dangO',
        moveInDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        hostName: 'Chủ trọ Nguyễn Văn A',
        deposit: 3500000,
      );

      final widget = MyHomeDetailScreen(booking: booking);
      expect(widget.booking, isNotNull);
      expect(widget.pastItem, isNull);
      expect(widget.booking!.roomTitle, equals('Phòng 101'));
      expect(widget.booking!.roomPrice, equals(3500000));
    });

    test('MyHomeDetailScreen initializes with past rental home item', () {
      final pastItem = PastRentalHomeItem(
        id: 'PAST_1',
        roomId: 'ROOM_OLD',
        roomTitle: 'Phòng 202',
        roomAddress: '456 Lê Văn Sỹ, Q.3',
        hostId: 'HOST_2',
        hostName: 'Chủ nhà B',
        roomPrice: 4000000,
        moveInDate: DateTime(2025, 6, 1),
        moveOutDate: DateTime(2026, 1, 1),
        status: 'Đã hoàn tất trả phòng',
      );

      final widget = MyHomeDetailScreen(pastItem: pastItem);
      expect(widget.pastItem, isNotNull);
      expect(widget.booking, isNull);
      expect(widget.pastItem!.roomTitle, equals('Phòng 202'));
      expect(widget.pastItem!.status, equals('Đã hoàn tất trả phòng'));
    });
  });
}
