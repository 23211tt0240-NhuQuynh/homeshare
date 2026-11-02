import '../../../core/services/resident_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// Thực hiện Check-out và Hoàn cọc
  Future<void> performCheckout({
    required String roomId,
    required String periodId,
    required String renterId,
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

    // 2. Cập nhật period sang daKetThuc
    if (periodId.isNotEmpty && !periodId.startsWith('room_')) {
      final periodRef = _firestore
          .collection(FirestoreCollections.periods)
          .doc(periodId);
      batch.update(periodRef, {
        'status': 'daKetThuc',
        'endDate': FieldValue.serverTimestamp(),
      });

      // Cập nhật cư dân trong period
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
        batch.update(d.reference, {
          'statusId': 'daRoi',
          'status': 'moved_out',
          'moveOutDate': FieldValue.serverTimestamp(),
        });
      }
    }

    // 3. Cập nhật phòng host_rooms sang available / còn phòng
    final roomRef = _firestore
        .collection(FirestoreCollections.hostRooms)
        .doc(roomId);
    batch.update(roomRef, {
      'status': 'available',
      'isAvailable': true,
      'tenantName': '',
      'tenantPhone': '',
      'contractId': '',
      'contractStart': null,
      'contractEnd': null,
      'bookingStatus': 'available',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4. Cập nhật đơn đặt phòng sang Đã hủy / Trả phòng
    final checkoutBookingIds = <String>{};
    if (periodId.isNotEmpty && !periodId.startsWith('room_')) {
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
          if (bId.isNotEmpty) checkoutBookingIds.add(bId);
        }
      } catch (_) {}
    }

    try {
      final bQuery = await _firestore
          .collection('bookings')
          .get();
      for (final bDoc in bQuery.docs) {
        final bData = bDoc.data();
        final bRenter =
            (bData['renterId'] ?? bData['nguoiDungId'] ?? bData['userId'] ?? '').toString();
        final bRoom =
            (bData['roomId'] ?? bData['phongId'] ?? '').toString();
        final bStatus = (bData['status'] ?? '').toString().toLowerCase();

        if (checkoutBookingIds.contains(bDoc.id)) {
          checkoutBookingIds.add(bDoc.id);
        } else if (bRenter == renterId && bRenter.isNotEmpty) {
          if (bRoom == roomId || bRoom.isEmpty) {
            checkoutBookingIds.add(bDoc.id);
          } else if (bStatus != 'cancelled' && bStatus != 'dahuy') {
            try {
              final postDoc = await _firestore.collection('posts').doc(bRoom).get();
              if (postDoc.exists) {
                final pData = postDoc.data() ?? {};
                final linked = (pData['hostRoomId'] ?? pData['roomId'] ?? pData['phongId'] ?? '').toString();
                if (linked == roomId) {
                  checkoutBookingIds.add(bDoc.id);
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    for (final bId in checkoutBookingIds) {
      if (bId.isEmpty) continue;
      batch.set(
        _firestore.collection('bookings').doc(bId),
        {
          'status': 'checked_out',
          'subTag': 'Đã trả phòng',
          'description': 'Đã hoàn tất trả phòng / Kết thúc đơn thuê',
          'trangThai': 'daKetThuc',
          'isCheckIn': false,
          'daNhanPhong': false,
          'checkoutRecordId': recordRef.id,
          'checkoutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (note.isNotEmpty) 'checkoutNote': note,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // 5. Đồng bộ giải phóng phòng sang collection rooms (nếu tồn tại)
    try {
      await _firestore.collection('rooms').doc(roomId).set({
        'status': 'available',
        'isAvailable': true,
        'tenantName': '',
        'tenantPhone': '',
        'contractId': '',
        'contractStart': null,
        'contractEnd': null,
        'bookingStatus': 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // 6. Tự động khôi phục bài đăng sang trạng thái hiển thị (approved / daDuyet)
    try {
      final postsRef = _firestore.collection('posts');
      final now = DateTime.now();

      Future<void> restorePostDoc(DocumentReference ref) async {
        await ref.set({
          'status': 'approved',
          'statusId': 'approved',
          'trangThai': 'daDuyet',
          'trangThai_id': 'daDuyet',
          'isAvailable': true,
          'hiddenReason': FieldValue.delete(),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      }

      // 6.1. Khôi phục trực tiếp theo doc ID == roomId
      try {
        final directDoc = await postsRef.doc(roomId).get();
        if (directDoc.exists) {
          await restorePostDoc(directDoc.reference);
        }
      } catch (_) {}

      // 6.2. Khôi phục theo trường 'roomId' == roomId
      try {
        final qRoomId = await postsRef.where('roomId', isEqualTo: roomId).get();
        for (final doc in qRoomId.docs) {
          await restorePostDoc(doc.reference);
        }
      } catch (_) {}

      // 6.3. Khôi phục theo trường 'phongId' == roomId
      try {
        final qPhongId = await postsRef.where('phongId', isEqualTo: roomId).get();
        for (final doc in qPhongId.docs) {
          await restorePostDoc(doc.reference);
        }
      } catch (_) {}

      // 6.4. Khôi phục theo trường 'hostRoomId' == roomId
      try {
        final qHostRoomId =
            await postsRef.where('hostRoomId', isEqualTo: roomId).get();
        for (final doc in qHostRoomId.docs) {
          await restorePostDoc(doc.reference);
        }
      } catch (_) {}

      // 6.5. Khôi phục theo trường 'id' == roomId
      try {
        final qId = await postsRef.where('id', isEqualTo: roomId).get();
        for (final doc in qId.docs) {
          await restorePostDoc(doc.reference);
        }
      } catch (_) {}

      debugPrint(
        'Đã tự động khôi phục bài đăng về trạng thái hiển thị cho phòng $roomId sau khi checkout',
      );
    } catch (e) {
      debugPrint('Lỗi khi khôi phục bài đăng sau checkout: $e');
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
