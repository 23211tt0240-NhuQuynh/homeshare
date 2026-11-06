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
  final String residentId;
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
    this.residentId = '',
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

          // Mỗi cư dân đang ở là một mục checkout độc lập.
          for (final room in hostRooms) {
            final members = await ResidentService(_firestore).forRoom(room.id);
            for (final member in members) {
              final periodDoc = member.periodId.isEmpty
                  ? null
                  : await _firestore
                        .collection(FirestoreCollections.periods)
                        .doc(member.periodId)
                        .get();
              final period = periodDoc != null && periodDoc.exists
                  ? PeriodModel.fromFirestore(periodDoc)
                  : null;
              items.add(
                CheckinCheckoutItem(
                  id: member.id,
                  residentId: member.id,
                  bookingId: period?.bookingId ?? '',
                  periodId: member.periodId,
                  roomId: room.id,
                  roomCode: room.roomCode.isNotEmpty
                      ? room.roomCode
                      : room.title,
                  renterId: member.userId,
                  renterName: member.fullName,
                  renterPhone: member.phone,
                  propertyName: propertyNames[room.propertyId] ?? 'Nhà trọ',
                  floor: room.floor > 0 ? room.floor : 1,
                  deposit: member.formId == 'chinh' ? room.deposit : 0,
                  expectedDate:
                      room.contractEnd ??
                      period?.endDate ??
                      member.moveInDate.add(const Duration(days: 365)),
                  status: 'Đang ở',
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
            final residentDoc = record.residentId.isEmpty
                ? null
                : await _firestore
                      .collection(FirestoreCollections.residents)
                      .doc(record.residentId)
                      .get();
            final residentName =
                residentDoc?.data()?['fullName']?.toString() ?? '';
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
                  renterName: residentName.isNotEmpty
                      ? residentName
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
    String residentId = '',
    required double initialDeposit,
    required double deductionAmount,
    required String note,
  }) async {
    final members = await ResidentService(_firestore).forRoom(roomId);
    final selected = members
        .where(
          (r) => residentId.isNotEmpty
              ? r.id == residentId && r.userId == renterId
              : renterId.isNotEmpty && r.userId == renterId,
        )
        .toList();
    if (selected.length != 1) {
      throw StateError(
        'Không tìm thấy người đang ở cần checkout. Vui lòng tải lại danh sách.',
      );
    }
    final member = selected.single;
    if (member.periodId != periodId) {
      throw StateError('Kỳ thuê đã thay đổi. Vui lòng tải lại danh sách.');
    }
    final remaining = members.where((r) => r.id != member.id).toList();
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
      renterId: member.userId,
      residentId: member.id,
      checkoutTime: DateTime.now(),
      depositAmount: initialDeposit,
      deductionAmount: deductionAmount,
      refundAmount: refundAmount,
      status: 'daCheckout',
      note: note,
    );
    batch.set(recordRef, record.toMap());

    batch.update(
      _firestore.collection(FirestoreCollections.residents).doc(member.id),
      {
        'statusId': 'daRoi',
        'status': 'moved_out',
        'moveOutDate': FieldValue.serverTimestamp(),
      },
    );

    // Kỳ thuê dùng chung chỉ kết thúc khi người cuối cùng trong kỳ rời đi.
    if (periodId.isNotEmpty && !remaining.any((r) => r.periodId == periodId)) {
      final periodRef = _firestore
          .collection(FirestoreCollections.periods)
          .doc(periodId);
      if ((await periodRef.get()).exists) {
        batch.update(periodRef, {
          'status': 'daKetThuc',
          'endDate': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.update(
      _firestore.collection(FirestoreCollections.hostRooms).doc(roomId),
      {
        'status': remaining.isEmpty ? 'available' : 'occupied',
        if (remaining.isEmpty) ...{
          'contractId': '',
          'contractStart': null,
          'contractEnd': null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

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
