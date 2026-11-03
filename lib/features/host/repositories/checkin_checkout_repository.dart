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

            if (isPending) {
              items.add(
                CheckinCheckoutItem(
                  id: booking.id,
                  bookingId: booking.id,
                  roomId: room.id,
                  roomCode: room.roomCode.isNotEmpty
                      ? room.roomCode
                      : room.title,
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
                  roomCode: room.roomCode.isNotEmpty
                      ? room.roomCode
                      : room.title,
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

          // 1. Các kỳ ở đang ở (dangO) -> Danh sách cần xử lý Check-out
          final periodsSnap = await _firestore
              .collection(FirestoreCollections.periods)
              .where('status', isEqualTo: 'dangO')
              .get();

          for (final doc in periodsSnap.docs) {
            final period = PeriodModel.fromFirestore(doc);
            final room = roomMap[period.roomId];
            if (room == null) continue;

            final propName =
                propertyNames[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            // Tính ngày dự kiến trả phòng (1 năm sau ngày bắt đầu hoặc contractEnd)
            final expectedOut =
                room.contractEnd ??
                period.endDate ??
                period.startDate.add(const Duration(days: 365));

            items.add(
              CheckinCheckoutItem(
                id: period.id,
                bookingId: period.bookingId,
                periodId: period.id,
                roomId: room.id,
                roomCode: room.roomCode.isNotEmpty ? room.roomCode : room.title,
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

          // 2. Các phòng có trạng thái occupied nhưng chưa có period
          for (final room in hostRooms) {
            final alreadyInList = items.any((i) => i.roomId == room.id);
            if (!alreadyInList &&
                room.tenantName.isNotEmpty &&
                (room.status == 'occupied' ||
                    room.status == 'daThue' ||
                    room.status == 'dangO')) {
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
                  roomCode: room.roomCode.isNotEmpty
                      ? room.roomCode
                      : room.title,
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
              final propName =
                  propertyNames[room.propertyId] ??
                  (room.address.isNotEmpty ? room.address : 'Nhà trọ');

              items.add(
                CheckinCheckoutItem(
                  id: record.id,
                  bookingId: '',
                  periodId: record.periodId,
                  roomId: record.roomId,
                  roomCode: room.roomCode.isNotEmpty
                      ? room.roomCode
                      : room.title,
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

  bool _isCheckoutPeriodId(String periodId) =>
      periodId.isNotEmpty && !periodId.startsWith('room_');

  bool _isActiveStayStatus(dynamic status) {
    final s = (status ?? '').toString().toLowerCase().trim();
    return s == 'active' ||
        s == 'dango' ||
        s == 'dang_o' ||
        s == 'danhanphong';
  }

  Future<Set<String>> _canonicalRoomIds(String roomId) async {
    final ids = <String>{if (roomId.trim().isNotEmpty) roomId.trim()};
    if (roomId.trim().isEmpty) return ids;
    try {
      ids.add(await ResidentService(_firestore).resolveRoomId(roomId.trim()));
    } catch (_) {}
    return ids;
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _checkoutBookingRefs({
    required String bookingId,
    required String periodId,
    required String roomId,
    required String renterId,
  }) async {
    final refs = <String, DocumentReference<Map<String, dynamic>>>{};
    final bookings = _firestore.collection(FirestoreCollections.bookings);

    Future<void> addDoc(String id) async {
      final clean = id.trim();
      if (clean.isEmpty || clean.startsWith('room_') || refs.containsKey(clean)) {
        return;
      }
      final doc = await bookings.doc(clean).get();
      if (doc.exists) refs[clean] = doc.reference;
    }

    await addDoc(bookingId);
    if (_isCheckoutPeriodId(periodId)) {
      try {
        final period = await _firestore
            .collection(FirestoreCollections.periods)
            .doc(periodId)
            .get();
        final data = period.data() ?? {};
        await addDoc((data['bookingId'] ?? data['donId'] ?? '').toString());
      } catch (_) {}
    }

    if (refs.isNotEmpty) return refs.values.toList();

    final roomIds = await _canonicalRoomIds(roomId);
    QuerySnapshot<Map<String, dynamic>> snap;
    if (renterId.trim().isNotEmpty) {
      snap = await bookings.where('renterId', isEqualTo: renterId.trim()).get();
    } else if (roomId.trim().isNotEmpty) {
      snap = await bookings.where('roomId', isEqualTo: roomId.trim()).get();
    } else {
      return const [];
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_isActiveStayStatus(data['status'] ?? data['trangThai'])) continue;
      final bookingRoom = (data['roomId'] ?? data['phongId'] ?? '').toString();
      if (bookingRoom.isEmpty) continue;
      if (roomIds.contains(bookingRoom)) {
        refs[doc.id] = doc.reference;
        continue;
      }
      try {
        if (roomIds.contains(
          await ResidentService(_firestore).resolveRoomId(bookingRoom),
        )) {
          refs[doc.id] = doc.reference;
        }
      } catch (_) {}
    }
    return refs.values.toList();
  }

  Future<void> _markResidentsMovedOut(
    WriteBatch batch, {
    required String roomId,
    required String periodId,
  }) async {
    final seen = <String>{};
    void apply(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final status = (doc.data()['statusId'] ??
                doc.data()['status'] ??
                doc.data()['trangThai_id'] ??
                '')
            .toString()
            .toLowerCase();
        if (doc.data()['moveOutDate'] != null ||
            status == 'daroi' ||
            status == 'moved_out') {
          continue;
        }
        batch.update(doc.reference, {
          'statusId': 'daRoi',
          'status': 'moved_out',
          'moveOutDate': FieldValue.serverTimestamp(),
        });
      }
    }

    if (_isCheckoutPeriodId(periodId)) {
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
      apply(resSnap);
    }

    final roomIds = await _canonicalRoomIds(roomId);
    for (final id in roomIds) {
      for (final field in const ['roomId', 'phongId', 'phongTroId']) {
        final snap = await _firestore
            .collection(FirestoreCollections.residents)
            .where(field, isEqualTo: id)
            .get();
        apply(snap);
      }
    }
  }

  /// Thực hiện Check-out và Hoàn cọc
  Future<void> performCheckout({
    required String roomId,
    required String periodId,
    required String renterId,
    String bookingId = '',
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

    // 2. Kết thúc kỳ ở
    if (_isCheckoutPeriodId(periodId)) {
      final periodRef = _firestore
          .collection(FirestoreCollections.periods)
          .doc(periodId);
      final periodSnap = await periodRef.get();
      if (periodSnap.exists) {
        batch.update(periodRef, {
          'status': 'daKetThuc',
          'endDate': FieldValue.serverTimestamp(),
        });
      }
    }

    // 3. Cư dân phòng này → đã rời
    await _markResidentsMovedOut(
      batch,
      roomId: roomId,
      periodId: periodId,
    );

    // 4. Đơn thuê phải rời Đang ở, nếu không màn người thuê vẫn hiện cư trú / đánh giá được
    final bookingRefs = await _checkoutBookingRefs(
      bookingId: bookingId,
      periodId: periodId,
      roomId: roomId,
      renterId: renterId,
    );
    for (final bookingRef in bookingRefs) {
      batch.set(bookingRef, {
        'status': 'checked_out',
        'subTag': 'Đã trả phòng',
        'description': 'Đã check-out / trả phòng',
        'moveOutDate': FieldValue.serverTimestamp(),
        'checkedOutAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'trangThai': FieldValue.delete(),
      }, SetOptions(merge: true));
    }

    // 5. Phòng host_rooms sang available
    final roomRef = _firestore
        .collection(FirestoreCollections.hostRooms)
        .doc(roomId);
    batch.update(roomRef, {
      'status': 'available',
      'contractId': '',
      'contractStart': null,
      'contractEnd': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
