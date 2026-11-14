import '../../../core/services/booking_service.dart';
import '../../../core/services/resident_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/checkout_record_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/room_model.dart';

/// Mục cần xử lý Check-in hoặc Check-out
class CheckinCheckoutItem {
  final String id;
  final String bookingId;
  final String periodId;
  final String roomId;
  final String roomCode;
  final String renterId;
  final String renterName;
  final String renterPhone;
  final String propertyName;
  final int floor;
  final double deposit;
  final double roomPrice;
  final double totalAmount;
  final String paymentOption;
  final String roomTitle;
  final DateTime
  expectedDate; // Ngày vào (check-in) hoặc Ngày dự kiến trả (check-out)
  final String status; // 'choNhanPhong', 'dangO', 'daCheckout', 'daNhanPhong'
  final bool isCompleted;
  final DateTime? completedTime;
  final double? refundedDeposit;

  const CheckinCheckoutItem({
    required this.id,
    required this.bookingId,
    this.periodId = '',
    required this.roomId,
    required this.roomCode,
    required this.renterId,
    required this.renterName,
    this.renterPhone = '',
    required this.propertyName,
    this.floor = 1,
    required this.deposit,
    this.roomPrice = 0.0,
    this.totalAmount = 0.0,
    this.paymentOption = 'deposit',
    this.roomTitle = '',
    required this.expectedDate,
    required this.status,
    this.isCompleted = false,
    this.completedTime,
    this.refundedDeposit,
  });
}

class CheckinCheckoutRepository {
  final FirebaseFirestore _firestore;

  CheckinCheckoutRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  String _resolveCleanRoomCode(RoomModel room, int index) {
    final explicit = room.roomCode.trim();
    if (explicit.isNotEmpty &&
        !RoomModel.looksLikeOpaqueRoomId(explicit) &&
        !explicit.contains('...') &&
        !explicit.toLowerCase().contains('hồi') &&
        !explicit.toLowerCase().contains('hoi') &&
        explicit.length <= 8) {
      final digits = RegExp(r'\d{2,4}').firstMatch(explicit);
      if (digits != null) return digits.group(0)!;
      return explicit;
    }

    final rawTitle = room.title.trim();
    if (rawTitle.isNotEmpty &&
        !rawTitle.contains('...') &&
        !rawTitle.toLowerCase().contains('hồi') &&
        !rawTitle.toLowerCase().contains('hoi') &&
        !RoomModel.looksLikeOpaqueRoomId(rawTitle)) {
      final match = RegExp(
        r'(?:phòng|p\.?|room)?\s*([A-Za-z]?\d{2,4})',
        caseSensitive: false,
      ).firstMatch(rawTitle);
      if (match != null) {
        return match.group(1)!.toUpperCase();
      }
    }

    final fl = room.floor > 0 ? room.floor : 1;
    final num = (index + 1).toString().padLeft(2, '0');
    return '$fl$num';
  }

  /// Lắng nghe danh sách phòng cần Check-in của chủ trọ
  Stream<List<CheckinCheckoutItem>> watchCheckinItems(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .asyncMap((roomSnap) async {
          final hostRooms = await Future.wait(
            roomSnap.docs
                .map(RoomModel.fromFirestore)
                .where((r) => r.status != 'deleted')
                .map(ResidentService(_firestore).hydrateRoom),
          );

          if (hostRooms.isEmpty) return <CheckinCheckoutItem>[];
          final roomMap = {for (var r in hostRooms) r.id: r};

          // Tìm tên properties
          final propertyNames = await _getPropertyNames(hostRooms);

          // 1. Bookings chờ nhận phòng (chờ duyệt hoặc đã duyệt nhưng chưa sang 'dangO')
          final bookingsSnap = await _firestore
              .collection(FirestoreCollections.bookings)
              .where('hostId', isEqualTo: hostId)
              .get();

          final items = <CheckinCheckoutItem>[];

          for (final doc in bookingsSnap.docs) {
            final booking = BookingRequestModel.fromFirestore(doc);
            final room = roomMap[booking.roomId];
            if (room == null) continue;

            final isPending =
                booking.status == 'pending' ||
                booking.status == 'choDuyet' ||
                booking.status == 'approved' ||
                booking.status == 'daDuyet' ||
                booking.status == 'choNhanPhong' ||
                booking.status == 'daCoc' ||
                booking.status == 'deposit_paid' ||
                booking.status == 'completed' ||
                booking.status == 'daThanhToan';

            final isDone =
                booking.status == 'dangO' || booking.status == 'active';

            final propName =
                propertyNames[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            final calculatedPrice = booking.roomPrice > 0
                ? booking.roomPrice
                : room.price;
            final isFull =
                booking.paymentOption == 'full' ||
                booking.paymentOption == 'toanbo';
            final calculatedTotal = booking.totalAmount > 0
                ? booking.totalAmount
                : (isFull
                      ? calculatedPrice
                      : (booking.deposit > 0 ? booking.deposit : room.deposit));

            final cleanCode = _resolveCleanRoomCode(room, items.length);

            if (isPending) {
              items.add(
                CheckinCheckoutItem(
                  id: booking.id,
                  bookingId: booking.id,
                  roomId: room.id,
                  roomCode: cleanCode,
                  renterId: booking.renterId,
                  renterName: booking.renterName,
                  renterPhone: booking.renterPhone,
                  propertyName: propName,
                  floor: room.floor > 0 ? room.floor : 1,
                  deposit: booking.deposit > 0 ? booking.deposit : room.deposit,
                  roomPrice: calculatedPrice,
                  totalAmount: calculatedTotal,
                  paymentOption: booking.paymentOption,
                  roomTitle: room.title.isNotEmpty ? room.title : propName,
                  expectedDate: booking.moveInDate,
                  status: 'Chờ nhận phòng',
                  isCompleted: false,
                ),
              );
            } else if (isDone) {
              items.add(
                CheckinCheckoutItem(
                  id: booking.id,
                  bookingId: booking.id,
                  roomId: room.id,
                  roomCode: cleanCode,
                  renterId: booking.renterId,
                  renterName: booking.renterName,
                  renterPhone: booking.renterPhone,
                  propertyName: propName,
                  floor: room.floor > 0 ? room.floor : 1,
                  deposit: booking.deposit > 0 ? booking.deposit : room.deposit,
                  roomPrice: calculatedPrice,
                  totalAmount: calculatedTotal,
                  paymentOption: booking.paymentOption,
                  roomTitle: room.title.isNotEmpty ? room.title : propName,
                  expectedDate: booking.moveInDate,
                  status: 'Đã nhận phòng',
                  isCompleted: true,
                  completedTime: booking.acceptedDate ?? booking.createdAt,
                  refundedDeposit: booking.deposit,
                ),
              );
            }
          }

          return items;
        });
  }

  /// Lắng nghe danh sách phòng cần Check-out & Đã check-out của chủ trọ
  Stream<List<CheckinCheckoutItem>> watchCheckoutItems(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .asyncMap((roomSnap) async {
          final hostRooms = await Future.wait(
            roomSnap.docs
                .map(RoomModel.fromFirestore)
                .where((r) => r.status != 'deleted')
                .map(ResidentService(_firestore).hydrateRoom),
          );

          if (hostRooms.isEmpty) return <CheckinCheckoutItem>[];
          final roomMap = {for (var r in hostRooms) r.id: r};
          final propertyNames = await _getPropertyNames(hostRooms);

          final items = <CheckinCheckoutItem>[];

          // 1. Các kỳ ở đang ở (dangO / active) -> Danh sách cần xử lý Check-out
          final periodsSnap = await _firestore
              .collection(FirestoreCollections.periods)
              .get();

          final resService = ResidentService(_firestore);

          for (final doc in periodsSnap.docs) {
            final period = PeriodModel.fromFirestore(doc);
            final pStatus = (period.status).trim().toLowerCase();
            if (pStatus != 'dango' && pStatus != 'active') continue;

            final room = roomMap[period.roomId];
            if (room == null) continue;

            final cleanCode = _resolveCleanRoomCode(room, items.length);

            // Tự động dọn sạch title rác "người theo đạo Hồi...." trên Firestore nếu có
            if (room.title.contains('đạo Hồi') ||
                room.title.contains('dao Hoi') ||
                room.title.contains('...')) {
              _firestore.collection(FirestoreCollections.hostRooms).doc(room.id).set({
                'title': 'Phòng $cleanCode',
                'roomCode': cleanCode,
                'maPhong': cleanCode,
              }, SetOptions(merge: true)).catchError((_) {});
            }

            final propName =
                propertyNames[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            // Tính ngày dự kiến trả phòng (1 năm sau ngày bắt đầu hoặc contractEnd)
            final expectedOut =
                room.contractEnd ??
                period.endDate ??
                period.startDate.add(const Duration(days: 365));

            // Lấy danh sách từng cư dân trong phòng (hỗ trợ hiển thị và checkout từng người)
            final residents = await resService.forRoom(room.id, periodId: period.id);

            if (residents.isNotEmpty) {
              for (final res in residents) {
                final isPrimary = res.formId == 'chinh' || res.userId == period.renterId;
                items.add(
                  CheckinCheckoutItem(
                    id: res.id,
                    bookingId: period.bookingId,
                    periodId: period.id,
                    roomId: room.id,
                    roomCode: cleanCode,
                    renterId: res.userId.isNotEmpty ? res.userId : res.id,
                    renterName: res.fullName.isNotEmpty
                        ? res.fullName
                        : (room.tenantName.isNotEmpty
                            ? room.tenantName
                            : 'Khách thuê'),
                    renterPhone: res.phone.isNotEmpty
                        ? res.phone
                        : room.tenantPhone,
                    propertyName: propName,
                    floor: room.floor > 0 ? room.floor : 1,
                    deposit: isPrimary ? room.deposit : 0.0,
                    expectedDate: expectedOut,
                    status: isPrimary ? 'Đang ở' : 'Ở ghép',
                    isCompleted: false,
                  ),
                );
              }
            } else {
              items.add(
                CheckinCheckoutItem(
                  id: period.id,
                  bookingId: period.bookingId,
                  periodId: period.id,
                  roomId: room.id,
                  roomCode: cleanCode,
                  renterId: period.renterId,
                  renterName: room.tenantName.isNotEmpty
                      ? room.tenantName
                      : 'Khách thuê',
                  renterPhone: room.tenantPhone,
                  propertyName: propName,
                  floor: room.floor > 0 ? room.floor : 1,
                  deposit: room.deposit,
                  expectedDate: expectedOut,
                  status: 'Đang ở',
                  isCompleted: false,
                ),
              );
            }
          }

          // 2. Các phòng có trạng thái occupied nhưng chưa có period
          for (final room in hostRooms) {
            final alreadyInList = items.any((i) => i.roomId == room.id);
            if (!alreadyInList &&
                room.tenantName.isNotEmpty &&
                (room.status == 'occupied' ||
                    room.status == 'daThue' ||
                    room.status == 'dangO')) {
              final cleanCode = _resolveCleanRoomCode(room, items.length);
              final propName =
                  propertyNames[room.propertyId] ??
                  (room.address.isNotEmpty ? room.address : 'Nhà trọ');

              final expectedOut =
                  room.contractEnd ??
                  (room.contractStart?.add(const Duration(days: 365)) ??
                      DateTime.now().add(const Duration(days: 30)));

              items.add(
                CheckinCheckoutItem(
                  id: 'room_${room.id}',
                  bookingId: room.contractId,
                  roomId: room.id,
                  roomCode: cleanCode,
                  renterId: '',
                  renterName: room.tenantName,
                  renterPhone: room.tenantPhone,
                  propertyName: propName,
                  floor: room.floor > 0 ? room.floor : 1,
                  deposit: room.deposit,
                  expectedDate: expectedOut,
                  status: 'Đang ở',
                  isCompleted: false,
                ),
              );
            }
          }

          // 3. Các biên bản trả phòng (checkout_records) đã hoàn tất
          final checkoutRecordsSnap = await _firestore
              .collection(FirestoreCollections.checkoutRecords)
              .get();

          for (final doc in checkoutRecordsSnap.docs) {
            final record = CheckoutRecordModel.fromFirestore(doc);
            final room = roomMap[record.roomId];
            // Hiển thị nếu thuộc phòng của chủ nhà này
            if (room != null) {
              final cleanCode = _resolveCleanRoomCode(room, items.length);
              final propName =
                  propertyNames[room.propertyId] ??
                  (room.address.isNotEmpty ? room.address : 'Nhà trọ');

              items.add(
                CheckinCheckoutItem(
                  id: record.id,
                  bookingId: '',
                  periodId: record.periodId,
                  roomId: record.roomId,
                  roomCode: cleanCode,
                  renterId: record.renterId,
                  renterName: room.tenantName.isNotEmpty
                      ? room.tenantName
                      : 'Khách thuê',
                  propertyName: propName,
                  floor: room.floor > 0 ? room.floor : 1,
                  deposit: record.depositAmount,
                  expectedDate: record.checkoutTime,
                  status: 'Đã Check-out',
                  isCompleted: true,
                  completedTime: record.checkoutTime,
                  refundedDeposit: record.refundAmount,
                ),
              );
            }
          }

          return items;
        });
  }

  /// Thực hiện Check-out và Hoàn cọc
  Future<void> performCheckout({
    required String roomId,
    required String periodId,
    required String renterId,
    String? bookingId,
    required double initialDeposit,
    required double deductionAmount,
    required String note,
  }) async {
    final batch = _firestore.batch();
    final refundAmount = (initialDeposit - deductionAmount).clamp(
      0.0,
      double.infinity,
    );

    // 1. Tạo checkout_record
    final recordRef = _firestore
        .collection(FirestoreCollections.checkoutRecords)
        .doc();
    final record = CheckoutRecordModel(
      id: recordRef.id,
      periodId: periodId,
      roomId: roomId,
      renterId: renterId,
      checkoutTime: DateTime.now(),
      depositAmount: initialDeposit,
      deductionAmount: deductionAmount,
      refundAmount: refundAmount,
      status: 'daCheckout',
      note: note,
    );
    batch.set(recordRef, record.toMap());

    // 2. Cập nhật cụ thể cư dân được checkout (ở ghép không đuổi cả phòng)
    final resService = ResidentService(_firestore);
    final canonicalRoomId = await resService.resolveRoomId(roomId);
    final allActiveResidents = await resService.forRoom(canonicalRoomId, periodId: periodId);

    // Xác định cư dân còn lại trong phòng (loại trừ người đang thực hiện checkout)
    final remainingActiveResidents = allActiveResidents
        .where((r) => r.userId != renterId && r.id != renterId && ResidentService.isActive(r))
        .toList();
    final hasOtherActiveResidents = remainingActiveResidents.isNotEmpty;

    // Đánh dấu moved_out cho cư dân mục tiêu trên collection residents
    if (periodId.isNotEmpty && !periodId.startsWith('room_')) {
      var resSnap = await _firestore
          .collection(FirestoreCollections.residents)
          .where('periodId', isEqualTo: periodId)
          .get();
      if (resSnap.docs.isEmpty) {
        resSnap = await _firestore
            .collection(FirestoreCollections.residents)
            .where('kyThue_id', isEqualTo: periodId)
            .get();
      }
      for (final d in resSnap.docs) {
        final rData = d.data();
        final rUserId = (rData['userId'] ?? rData['nguoiDungId'] ?? d.id).toString();
        final isTarget = rUserId == renterId || d.id == renterId;
        if (isTarget) {
          batch.update(d.reference, {
            'status': 'moved_out',
            'statusId': FieldValue.delete(),
            'moveOutDate': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // Tra cứu thêm theo roomId / canonicalRoomId để đánh dấu moved_out chính xác cho cư dân này
    try {
      final userResSnap = await _firestore
          .collection(FirestoreCollections.residents)
          .where('userId', isEqualTo: renterId)
          .get();
      for (final d in userResSnap.docs) {
        final rData = d.data();
        final rRoom = (rData['roomId'] ?? '').toString();
        if (rRoom == roomId || rRoom == canonicalRoomId || rData['periodId'] == periodId) {
          batch.update(d.reference, {
            'status': 'moved_out',
            'statusId': FieldValue.delete(),
            'moveOutDate': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}

    // Chỉ đóng kỳ thuê (period) khi KHÔNG CÒN cư dân nào khác ở trong phòng
    if (!hasOtherActiveResidents && periodId.isNotEmpty && !periodId.startsWith('room_')) {
      final periodRef = _firestore
          .collection(FirestoreCollections.periods)
          .doc(periodId);
      batch.update(periodRef, {
        'status': 'daKetThuc',
        'endDate': FieldValue.serverTimestamp(),
      });
    }

    // 3. Cập nhật phòng host_rooms:
    // Nếu vẫn còn người ở ghép: GIỮ NGUYÊN phòng ở trạng thái occupied, cập nhật tên người ở còn lại.
    // Nếu đã hết người: chuyển phòng sang available để cho thuê lại.
    final roomRef = _firestore
        .collection(FirestoreCollections.hostRooms)
        .doc(roomId);

    if (hasOtherActiveResidents) {
      final primaryRemaining = remainingActiveResidents.firstWhere(
        (r) => r.formId == 'chinh',
        orElse: () => remainingActiveResidents.first,
      );
      batch.set(roomRef, {
        'status': 'occupied',
        'isAvailable': false,
        'tenantName': primaryRemaining.fullName,
        'tenantPhone': primaryRemaining.phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.set(roomRef, {
        'status': 'available',
        'isAvailable': true,
        'bookingStatus': 'available',
        'contractId': '',
        'contractStart': null,
        'contractEnd': null,
        'tenantName': '',
        'tenantPhone': '',
        'tenantAvatar': '',
        'reservedBookingId': FieldValue.delete(),
        'isHolding': false,
        'holdingBookingId': FieldValue.delete(),
        'holdingRenterId': FieldValue.delete(),
        'holdingExpiresAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 4. Cập nhật đơn đặt phòng sang Đã trả phòng (CHỈ áp dụng cho đơn của người rời đi)
    final checkoutBookingIds = <String>{};

    // 4.1 Đơn đặt phòng truyền trực tiếp (chỉ checkout nếu đúng của renterId hoặc phòng đã trả hết)
    final directBookingId = bookingId;
    if (directBookingId != null && directBookingId.isNotEmpty) {
      try {
        final bDoc = await _firestore.collection('bookings').doc(directBookingId).get();
        if (bDoc.exists && bDoc.data() != null) {
          final bData = bDoc.data()!;
          final bRenter = (bData['renterId'] ?? bData['nguoiDungId'] ?? bData['userId'] ?? '').toString();
          if (bRenter == renterId || !hasOtherActiveResidents) {
            checkoutBookingIds.add(directBookingId);
          }
        }
      } catch (_) {}
    }

    // 4.2 Tra cứu các đơn đặt phòng thuộc phòng này của chính người checkout
    try {
      final bQuery = await _firestore
          .collection('bookings')
          .where('roomId', isEqualTo: canonicalRoomId)
          .get();
      for (final bDoc in bQuery.docs) {
        final bData = bDoc.data();
        final bRenter =
            (bData['renterId'] ?? bData['nguoiDungId'] ?? bData['userId'] ?? '').toString();
        if (bRenter == renterId && bRenter.isNotEmpty) {
          checkoutBookingIds.add(bDoc.id);
        }
      }
    } catch (_) {}

    // 4.3 CHỈ KHI CẢ PHÒNG ĐÃ TRẢ HẾT (không còn ai) thì mới checkout đơn gốc của period
    if (!hasOtherActiveResidents && periodId.isNotEmpty && !periodId.startsWith('room_')) {
      if (periodId.startsWith('checkin_')) {
        checkoutBookingIds.add(periodId.substring('checkin_'.length));
      }
      try {
        final periodDoc = await _firestore
            .collection(FirestoreCollections.periods)
            .doc(periodId)
            .get();
        if (periodDoc.exists) {
          final pData = periodDoc.data();
          final bId =
              (pData?['bookingId'] ?? pData?['donId'] ?? '').toString();
          if (bId.isNotEmpty) {
            checkoutBookingIds.add(bId);
          }
        }
      } catch (_) {}
    }

    for (final bId in checkoutBookingIds) {
      if (bId.isEmpty) continue;
      batch.set(
        _firestore.collection('bookings').doc(bId),
        {
          'status': 'checked_out',
          'isCheckIn': false,
          'isCheckedIn': false,
          'checkoutRecordId': recordRef.id,
          'checkoutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (note.isNotEmpty) 'checkoutNote': note,
          'subTag': FieldValue.delete(),
          'description': FieldValue.delete(),
          'daNhanPhong': FieldValue.delete(),
          'trangThai': FieldValue.delete(),
          'statusId': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Chỉ mở lại bài đăng / phòng khi toàn bộ cư dân đã rời đi
    if (!hasOtherActiveResidents) {
      try {
        await BookingService(firestore: _firestore)
            .restorePostOnCancelledBooking(roomId);
      } catch (_) {}
      try {
        await _firestore.collection('rooms').doc(roomId).set({
          'status': 'available',
          'isAvailable': true,
          'bookingStatus': 'available',
          'tenantName': '',
          'tenantPhone': '',
          'contractId': '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<Map<String, String>> _getPropertyNames(List<RoomModel> rooms) async {
    final map = <String, String>{};
    final propIds = rooms
        .map((r) => r.propertyId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final pid in propIds) {
      try {
        final doc = await _firestore
            .collection(FirestoreCollections.hostProperties)
            .doc(pid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          map[pid] =
              data?['name'] ?? data?['tenNha'] ?? data?['title'] ?? 'Nhà trọ';
        }
      } catch (_) {}
    }
    return map;
  }
}
