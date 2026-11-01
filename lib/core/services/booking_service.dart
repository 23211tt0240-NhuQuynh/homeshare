import 'resident_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/resident_model.dart';
import '../utils/id_generator.dart';

class BookingService {
  final FirebaseFirestore _firestore;
  BookingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Gửi yêu cầu đặt thuê / hẹn xem phòng (Đơn đặt phòng, sinh Document ID chuẩn DP_...)
  Future<String> createBooking(
    BookingRequestModel booking, {
    String? propertyId,
  }) async {
    final bookingId = booking.id.isNotEmpty
        ? booking.id
        : IdGenerator.booking(
            renterCode: booking.renterUserCode,
            roomCode: booking.roomId,
          );
    final now = DateTime.now();
    final expiresAt = (booking.createdAt.year > 2000)
        ? booking.createdAt.add(const Duration(hours: 6))
        : now.add(const Duration(hours: 6));
    final hostRoomTitle = await titleFromHostRooms(booking.roomId);
    final stored = hostRoomTitle.isNotEmpty
        ? booking.copyWith(roomTitle: hostRoomTitle)
        : booking;
    await _firestore.collection('bookings').doc(bookingId).set({
      ...stored.toMap(),
      if (propertyId != null && propertyId.isNotEmpty) 'propertyId': propertyId,
      'id': bookingId,
      'bookingCode': bookingId,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'deadline': Timestamp.fromDate(expiresAt),
    });
    return bookingId;
  }

  /// Tự động hủy 1 đơn đặt phòng nếu đã quá hạn thanh toán 6 tiếng
  Future<void> autoCancelIfExpired(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'pending' && status != 'pending_payment') return;

      Timestamp? exp =
          data['expiresAt'] as Timestamp? ?? data['deadline'] as Timestamp?;
      if (exp == null) {
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          exp = Timestamp.fromDate(
            createdAt.toDate().add(const Duration(hours: 6)),
          );
        }
      }
      if (exp != null && exp.toDate().isBefore(DateTime.now())) {
        await cancelBooking(
          doc.id,
          reason: 'Tự động hủy do quá thời gian thanh toán 6 tiếng',
        );
      }
    } catch (e) {
      debugPrint('Error auto-cancelling expired booking ${doc.id}: $e');
    }
  }

  // Lấy chi tiết 1 đơn thuê theo bookingId (có tự động kiểm tra hết hạn 6 tiếng)
  Future<BookingRequestModel?> getBookingById(String bookingId) async {
    if (bookingId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return null;
      await autoCancelIfExpired(doc);
      return _withHostRoomTitle(
        BookingRequestModel.fromFirestore(doc),
        {},
      );
    } catch (e) {
      debugPrint('Error getting booking $bookingId: $e');
      return null;
    }
  }

  // Cập nhật trạng thái đơn đặt phòng đơn giản
  Future<void> updateBookingStatus(String bookingId, String status) async {
    if (bookingId.isEmpty) return;
    await _firestore.collection('bookings').doc(bookingId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 1. DUYỆT ĐƠN (Chuyển sang Đã duyệt / approved)
  Future<void> approveBooking(String bookingId, {String? note}) async {
    if (bookingId.isEmpty) return;
    final now = DateTime.now();

    final docSnap = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    final data = docSnap.data() ?? {};
    final renterId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
    final hostId = (data['hostId'] ?? data['chuNhaId'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ')
        .toString();
    final renterName = (data['renterName'] ?? data['tenNguoiO'] ?? 'Khách thuê')
        .toString();

    await _firestore.collection('bookings').doc(bookingId).set({
      'status': 'approved',
      'subTag': 'Đã duyệt',
      'description': 'Đã duyệt cọc giữ phòng',
      'isPaid': true,
      'approvedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (note != null && note.isNotEmpty) 'approvalNote': note,
      'trangThai': FieldValue.delete(),
    }, SetOptions(merge: true));

    // Gửi thông báo đến người thuê
    if (renterId.isNotEmpty && renterId != 'guest') {
      final notifId = IdGenerator.notification();
      await _firestore.collection('notifications').doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'recipientRole': 'renter',
        'title': 'Đơn thuê phòng đã được duyệt ✓',
        'message':
            'Đơn đặt phòng "$roomTitle" đã được duyệt thành công! Bạn có thể mở mã QR nhận phòng để chuẩn bị dọn vào.',
        'notificationType': 'booking',
        'bookingId': bookingId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Gửi / Cập nhật thông báo đến chủ trọ
    if (hostId.isNotEmpty && hostId != 'guest') {
      final hostNotifQuery = await _firestore
          .collection('notifications')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      bool hostNotifFound = false;
      for (final doc in hostNotifQuery.docs) {
        final dData = doc.data();
        final rRole = (dData['recipientRole'] ?? '').toString().toLowerCase();
        final recId = (dData['receiverId'] ?? '').toString();
        if (rRole == 'host' ||
            recId == hostId ||
            dData.containsKey('roomFloorInfo')) {
          await doc.reference.set({
            'notificationType': 'deposit',
            'type': 'deposit',
            'statusId': 'deposited',
            'status': 'approved',
            'title': 'Đơn thuê phòng đã được duyệt',
            'message':
                'Khách $renterName đã được duyệt cọc cho phòng "$roomTitle". Sẵn sàng tiếp nhận check-in nhận phòng.',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          hostNotifFound = true;
        }
      }

      if (!hostNotifFound) {
        final hostNotifId = IdGenerator.notification();
        await _firestore.collection('notifications').doc(hostNotifId).set({
          'id': hostNotifId,
          'notificationId': hostNotifId,
          'receiverId': hostId,
          'recipientRole': 'host',
          'title': 'Đơn thuê phòng đã được duyệt',
          'message':
              'Khách $renterName đã được duyệt cọc cho phòng "$roomTitle". Sẵn sàng tiếp nhận check-in nhận phòng.',
          'notificationType': 'deposit',
          'type': 'deposit',
          'bookingId': bookingId,
          'statusId': 'deposited',
          'status': 'approved',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Ghi audit log
    await _firestore.collection('audit_logs').add({
      'action': 'Duyệt đơn thuê',
      'actor': 'Hệ thống / Admin',
      'category': 'quanLyDon',
      'target': 'Đơn $bookingId',
      'details':
          'Đã duyệt đơn $bookingId cho phòng $roomTitle của khách $renterName',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. NHẬN PHÒNG (Chuyển sang Đang ở / dangO)
  Future<void> checkinBooking(
    String bookingId, {
    String? roomId,
    String? hostId,
    String? note,
  }) async {
    if (bookingId.isEmpty) return;
    final now = DateTime.now();

    final docSnap = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    final data = docSnap.data() ?? {};
    if (!docSnap.exists) throw StateError('Không tìm thấy đơn đặt phòng');
    final residentService = ResidentService(_firestore);
    final finalRoomId = await residentService.resolveRoomId(
      roomId ?? (data['roomId'] ?? data['phongId'] ?? '').toString(),
    );
    final renterId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
    final renterName = (data['renterName'] ?? data['tenNguoiO'] ?? 'Khách thuê')
        .toString();
    final renterPhone = (data['renterPhone'] ?? data['sdtNguoiO'] ?? '')
        .toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ')
        .toString();

    final batch = _firestore.batch();
    final periodId = await residentService.preparePrimary(
      batch: batch,
      bookingId: bookingId,
      roomId: finalRoomId,
      userId: renterId,
      fullName: renterName,
      phone: renterPhone,
      now: now,
    );

    // Cập nhật booking sang trạng thái 'dangO'
    batch.set(_firestore.collection('bookings').doc(bookingId), {
      'status': 'dangO',
      'subTag': 'Đang ở',
      'description': 'Đang ở (Đã bàn giao phòng)',
      'isCheckIn': true,
      'daNhanPhong': true,
      'acceptedDate': Timestamp.fromDate(now),
      'checkedInAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (note != null && note.isNotEmpty) 'checkinNote': note,
      'trangThai': FieldValue.delete(),
    }, SetOptions(merge: true));

    batch.update(_firestore.collection('host_rooms').doc(finalRoomId), {
      'status': 'occupied',
      'contractId': periodId,
      'contractStart': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    await batch.commit();

    // Thông báo cho người thuê
    if (renterId.isNotEmpty && renterId != 'guest') {
      final notifId = IdGenerator.notification();
      await _firestore.collection('notifications').doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'recipientRole': 'renter',
        'title': 'Nhận phòng thành công! 🎉',
        'message':
            'Chủ trọ đã xác nhận bàn giao phòng "$roomTitle". Chúc bạn có khoảng thời gian sinh sống tiện nghi và thoải mái!',
        'notificationType': 'booking',
        'bookingId': bookingId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Ghi audit log
    await _firestore.collection('audit_logs').add({
      'action': 'Xác nhận nhận phòng',
      'actor': hostId ?? 'Chủ trọ',
      'category': 'nhanPhong',
      'target': 'Đơn $bookingId',
      'details':
          'Khách $renterName đã nhận phòng $roomTitle thành công qua mã QR',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. HỦY ĐƠN (Chuyển sang Đã hủy / cancelled)
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    if (bookingId.isEmpty) return;
    final now = DateTime.now();

    final docSnap = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    final data = docSnap.data() ?? {};
    final renterId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
    final hostId = (data['hostId'] ?? data['chuNhaId'] ?? '').toString();
    final roomId = (data['roomId'] ?? data['phongId'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ')
        .toString();

    await _firestore.collection('bookings').doc(bookingId).set({
      'status': 'cancelled',
      'subTag': 'Đã hủy',
      'description': 'Đã hủy yêu cầu',
      'cancelledAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
      'trangThai': FieldValue.delete(),
      'ngayCapNhat': FieldValue.delete(),
    }, SetOptions(merge: true));

    // Giải phóng phòng về available nếu phòng đang bị lock
    if (roomId.isNotEmpty) {
      await _firestore.collection('host_rooms').doc(roomId).set({
        'status': 'available',
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    // Thông báo cho các bên
    if (renterId.isNotEmpty && renterId != 'guest') {
      final notifId = IdGenerator.notification();
      await _firestore.collection('notifications').doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'recipientRole': 'renter',
        'title': 'Đơn thuê phòng đã bị hủy',
        'message':
            'Đơn đặt phòng "$roomTitle" đã được hủy.${reason != null && reason.isNotEmpty ? " Lý do: $reason" : ""}',
        'notificationType': 'booking',
        'bookingId': bookingId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (hostId.isNotEmpty && hostId != 'guest') {
      final hostNotifId = IdGenerator.notification();
      await _firestore.collection('notifications').doc(hostNotifId).set({
        'id': hostNotifId,
        'receiverId': hostId,
        'recipientRole': 'host',
        'title': 'Đơn đặt phòng đã bị hủy',
        'message':
            'Đơn phòng "$roomTitle" đã chuyển sang trạng thái đã hủy.${reason != null && reason.isNotEmpty ? " Lý do: $reason" : ""}',
        'notificationType': 'booking',
        'bookingId': bookingId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // 4. CHUYỂN TRẠNG THÁI TỔNG QUÁT (choDuyet, daDuyet, dangO, daHuy)
  Future<void> transitionStatus(
    String bookingId,
    String targetStatus, {
    String? reason,
    String? roomId,
    String? hostId,
  }) async {
    final s = targetStatus.toLowerCase();
    if (s == 'daduyet' || s == 'approved' || s == 'deposit_paid') {
      await approveBooking(bookingId, note: reason);
    } else if (s == 'dango' || s == 'active' || s == 'danhanphong') {
      await checkinBooking(
        bookingId,
        roomId: roomId,
        hostId: hostId,
        note: reason,
      );
    } else if (s == 'dahuy' || s == 'cancelled' || s == 'rejected') {
      await cancelBooking(bookingId, reason: reason);
    } else {
      // Chờ duyệt
      await _firestore.collection('bookings').doc(bookingId).set({
        'status': 'pending',
        'subTag': 'Chờ duyệt',
        'description': 'Chờ duyệt đơn',
        'updatedAt': FieldValue.serverTimestamp(),
        if (reason != null && reason.isNotEmpty) 'note': reason,
      }, SetOptions(merge: true));
    }
  }

  static String? _bookingOwnerId(Map<String, dynamic> data) {
    final owner =
        data['nguoiDungId'] ??
        data['nguoiDung_Id'] ??
        data['renterId'] ??
        data['khachXemId'] ??
        '';
    final value = owner.toString();
    return value.isEmpty ? null : value;
  }

  List<BookingRequestModel> _bookingsForRenter(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String renterId,
  ) {
    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data();
            if (_bookingOwnerId(data) != renterId) return null;

            final status = (data['status'] ?? '').toString().toLowerCase();
            if (status == 'pending' || status == 'pending_payment') {
              final exp =
                  data['expiresAt'] as Timestamp? ??
                  data['deadline'] as Timestamp?;
              if (exp != null && exp.toDate().isBefore(DateTime.now())) {
                unawaited(autoCancelIfExpired(doc));
              }
            }

            return BookingRequestModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing booking ${doc.id}: $e');
            return null;
          }
        })
        .whereType<BookingRequestModel>()
        .toList();
  }

  /// Gộp đơn `bookings` với chỗ ở lấy từ `residents` (người ở ghép không có đơn riêng).
  @visibleForTesting
  static List<BookingRequestModel> mergeRenterStayLists({
    required List<BookingRequestModel> bookings,
    required List<BookingRequestModel> residentStays,
  }) {
    final covered = <String>{
      for (final booking in bookings)
        if (booking.roomId.trim().isNotEmpty) booking.roomId.trim(),
    };
    final merged = [...bookings];
    for (final stay in residentStays) {
      final roomId = stay.roomId.trim();
      if (roomId.isEmpty || covered.contains(roomId)) continue;
      covered.add(roomId);
      merged.add(stay);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// Thời điểm bắt đầu kỳ ở hiện tại: lúc nhận phòng, không dùng ngày dọn vào dự kiến.
  @visibleForTesting
  static DateTime stayStartedAt(BookingRequestModel stay) {
    return stay.acceptedDate ?? stay.createdAt;
  }

  /// Checkout cũ không được đè lên lần nhận phòng mới hơn.
  /// Cùng giây vẫn tính là đã trả phòng (nhận rồi đá ngay).
  @visibleForTesting
  static bool checkoutAppliesToStay({
    required DateTime checkoutAt,
    required DateTime stayStartedAt,
  }) {
    return !checkoutAt.isBefore(stayStartedAt);
  }

  /// Overlay `checkout_records` lên một đơn: chỉ kết thúc kỳ ở nếu checkout
  /// sau lần nhận phòng này; khôi phục `dangO` nếu đơn bị heal nhầm.
  @visibleForTesting
  static BookingRequestModel applyCheckoutOverlayToStay({
    required BookingRequestModel stay,
    DateTime? latestCheckoutAt,
  }) {
    if (latestCheckoutAt == null) return stay;
    final applies = checkoutAppliesToStay(
      checkoutAt: latestCheckoutAt,
      stayStartedAt: stayStartedAt(stay),
    );
    if (stay.isActive) {
      return applies ? stay.copyWith(status: 'checked_out') : stay;
    }
    if (stay.isEnded && !applies) {
      return stay.copyWith(status: 'dangO');
    }
    return stay;
  }

  /// Occupancy (`residents.dangO`) thắng biên bản trả phòng cũ.
  /// Host đọc bảng này, nên đơn thuê phải cùng trạng thái khi còn cư dân đang ở.
  @visibleForTesting
  static BookingRequestModel reconcileStayWithOccupancy({
    required BookingRequestModel stay,
    required bool hasActiveResident,
    DateTime? latestCheckoutAt,
  }) {
    if (hasActiveResident) {
      return stay.isActive ? stay : stay.copyWith(status: 'dangO');
    }
    return applyCheckoutOverlayToStay(
      stay: stay,
      latestCheckoutAt: latestCheckoutAt,
    );
  }

  Future<Map<String, dynamic>> _loadRoomData(
    String roomId,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final cached = cache[roomId];
    if (cached != null) return cached;
    for (final collection in ['host_rooms', 'rooms', 'posts']) {
      try {
        final doc = await _firestore.collection(collection).doc(roomId).get();
        if (doc.exists && doc.data() != null) {
          final data = {'id': doc.id, ...doc.data()!};
          cache[roomId] = data;
          return data;
        }
      } catch (e) {
        debugPrint('Error loading $collection/$roomId: $e');
      }
    }
    final empty = <String, dynamic>{'id': roomId};
    cache[roomId] = empty;
    return empty;
  }

  static String _firstNonEmptyString(
    List<dynamic> values, [
    String fallback = '',
  ]) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// Title phòng thật từ `host_rooms`, không lấy title bài đăng (`posts`).
  /// `roomId` trên đơn thường là ID bài đăng; theo FK `roomId`/`hostRoomId`.
  Future<String> titleFromHostRooms(
    String reference, {
    Map<String, Map<String, dynamic>>? cache,
  }) async {
    final roomId = reference.trim();
    if (roomId.isEmpty) return '';
    final roomCache = cache ?? <String, Map<String, dynamic>>{};
    final ids = <String>[];

    Future<void> addLinkedFrom(String collection) async {
      try {
        final linked = await _firestore.collection(collection).doc(roomId).get();
        final data = linked.data() ?? {};
        for (final key in [
          'hostRoomId',
          'roomId',
          'room_id',
          'phongId',
          'phong_tro_id',
        ]) {
          final value = (data[key] ?? '').toString().trim();
          if (value.isNotEmpty) {
            ids.add(value);
            return;
          }
        }
      } catch (e) {
        debugPrint('Error reading $collection/$roomId for host room title: $e');
      }
    }

    await addLinkedFrom('posts');
    await addLinkedFrom('rooms');
    ids.add(roomId);

    final seen = <String>{};
    for (final id in ids) {
      if (id.isEmpty || !seen.add(id)) continue;
      final cacheKey = 'host_rooms:$id';
      var data = roomCache[cacheKey];
      if (data == null) {
        try {
          final doc = await _firestore.collection('host_rooms').doc(id).get();
          if (doc.exists && doc.data() != null) {
            final hostData = {'id': doc.id, ...doc.data()!};
            data = hostData;
            roomCache[cacheKey] = hostData;
            roomCache.putIfAbsent(id, () => hostData);
          } else {
            roomCache[cacheKey] = {'id': id};
          }
        } catch (e) {
          debugPrint('Error loading host_rooms/$id: $e');
        }
      }
      if (data == null) continue;
      final title = _firstNonEmptyString([
        data['title'],
        data['tieuDe'],
        data['roomTitle'],
      ]);
      if (title.isNotEmpty) return title;
    }
    return '';
  }

  Future<BookingRequestModel> _withHostRoomTitle(
    BookingRequestModel booking,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final title = await titleFromHostRooms(booking.roomId, cache: cache);
    if (title.isEmpty || title == booking.roomTitle) return booking;
    return booking.copyWith(roomTitle: title);
  }

  Future<BookingRequestModel?> stayFromResident(
    ResidentModel resident, {
    Map<String, Map<String, dynamic>>? roomCache,
  }) async {
    final cache = roomCache ?? <String, Map<String, dynamic>>{};
    var roomId = resident.roomId.trim();
    if (roomId.isEmpty) return null;
    try {
      roomId = await ResidentService(_firestore).resolveRoomId(roomId);
    } catch (e) {
      debugPrint('Error resolving resident room $roomId: $e');
    }

    final roomData = await _loadRoomData(roomId, cache);
    if (resident.roomId.trim().isNotEmpty && resident.roomId.trim() != roomId) {
      await _loadRoomData(resident.roomId.trim(), cache);
    }

    Map<String, dynamic> periodData = const {};
    if (resident.periodId.isNotEmpty) {
      try {
        final period = await _firestore
            .collection('periods')
            .doc(resident.periodId)
            .get();
        periodData = period.data() ?? const {};
      } catch (e) {
        debugPrint('Error loading period ${resident.periodId}: $e');
      }
    }

    Map<String, dynamic> primaryBooking = const {};
    final primaryBookingId =
        (periodData['bookingId'] ?? periodData['donId'] ?? '').toString();
    if (primaryBookingId.isNotEmpty) {
      try {
        final bookingDoc = await _firestore
            .collection('bookings')
            .doc(primaryBookingId)
            .get();
        primaryBooking = bookingDoc.data() ?? const {};
      } catch (e) {
        debugPrint('Error loading primary booking $primaryBookingId: $e');
      }
    }

    String pickString(List<dynamic> values, [String fallback = '']) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    double pickDouble(List<dynamic> values) {
      for (final value in values) {
        if (value is num) return value.toDouble();
      }
      return 0;
    }

    final hostRoomTitle = await titleFromHostRooms(
      resident.roomId,
      cache: cache,
    );
    final roomTitle = pickString([
      hostRoomTitle,
      roomData['title'],
      roomData['tieuDe'],
      roomData['roomTitle'],
      roomData['roomCode'],
      primaryBooking['roomTitle'],
      primaryBooking['tieuDePhong'],
      roomId,
    ], roomId);
    final isActiveStay = ResidentService.isActive(resident);
    final periodStatus = (periodData['status'] ?? periodData['trangThai'] ?? '')
        .toString()
        .toLowerCase();
    final periodEnded = const [
      'daketthuc',
      'ended',
      'checked_out',
    ].contains(periodStatus);

    return BookingRequestModel(
      id: resident.id,
      renterId: resident.userId,
      renterName: pickString([resident.fullName], 'Người ở ghép'),
      renterPhone: resident.phone,
      roomId: roomId,
      roomCode: pickString([
        roomData['roomCode'],
        roomData['maPhong'],
        primaryBooking['roomCode'],
        primaryBooking['maPhong'],
      ]),
      roomTitle: roomTitle,
      roomAddress: pickString([
        roomData['address'],
        roomData['diaChi'],
        primaryBooking['roomAddress'],
        primaryBooking['diaChiPhong'],
      ]),
      roomPrice: pickDouble([
        roomData['price'],
        roomData['roomPrice'],
        roomData['giaThue'],
        roomData['giaThueThang'],
        primaryBooking['roomPrice'],
        primaryBooking['giaThue'],
        primaryBooking['rentalPrice'],
      ]),
      deposit: pickDouble([
        roomData['deposit'],
        roomData['tienCoc'],
        roomData['depositAmount'],
        primaryBooking['deposit'],
        primaryBooking['tienCoc'],
        primaryBooking['depositAmount'],
      ]),
      hostId: pickString([
        roomData['hostId'],
        roomData['chuNhaId'],
        primaryBooking['hostId'],
        primaryBooking['chuNhaId'],
      ]),
      hostName: pickString([
        roomData['hostName'],
        roomData['tenChuNha'],
        primaryBooking['hostName'],
        primaryBooking['tenChuNha'],
      ]),
      status: isActiveStay && !periodEnded ? 'dangO' : 'checked_out',
      moveInDate: resident.moveInDate,
      moveOutDate: resident.moveOutDate,
      acceptedDate: resident.moveInDate,
      note: resident.formId == 'oGhep' ? 'Ở ghép' : resident.formId,
      createdAt: resident.moveInDate,
    );
  }

  Future<List<BookingRequestModel>> loadResidentStays(
    String renterId, {
    bool activeOnly = true,
  }) async {
    if (renterId.isEmpty || renterId == 'guest') return [];
    final residents = await ResidentService(_firestore).forUser(renterId);
    return _staysFromResidents(residents, activeOnly: activeOnly);
  }

  Future<List<BookingRequestModel>> _staysFromResidents(
    Iterable<ResidentModel> residents, {
    required bool activeOnly,
  }) async {
    final cache = <String, Map<String, dynamic>>{};
    final stays = <BookingRequestModel>[];
    final coveredRooms = <String>{};
    for (final resident in residents) {
      final active = ResidentService.isActive(resident);
      if (activeOnly && !active) continue;
      if (!activeOnly && active) continue;
      final stay = await stayFromResident(resident, roomCache: cache);
      if (stay == null) continue;
      if (coveredRooms.contains(stay.roomId)) continue;
      coveredRooms.add(stay.roomId);
      stays.add(stay);
    }
    return stays;
  }

  Future<List<BookingRequestModel>> _buildRenterStayList({
    required String renterId,
    required QuerySnapshot<Map<String, dynamic>> bookingSnap,
    required QuerySnapshot<Map<String, dynamic>> residentSnap,
  }) async {
    final bookings = _bookingsForRenter(bookingSnap, renterId);
    final coveredRooms = <String>{};
    final residentService = ResidentService(_firestore);
    for (final booking in bookings) {
      final roomId = booking.roomId.trim();
      if (roomId.isEmpty) continue;
      coveredRooms.add(roomId);
      try {
        coveredRooms.add(await residentService.resolveRoomId(roomId));
      } catch (_) {}
    }

    final cache = <String, Map<String, dynamic>>{};
    final residentStays = <BookingRequestModel>[];
    final activeResidentRoomIds = <String>{};
    for (final doc in residentSnap.docs) {
      try {
        final resident = ResidentModel.fromFirestore(doc);
        if (resident.userId != renterId) continue;
        if (!ResidentService.isActive(resident)) continue;
        final rawRoomId = resident.roomId.trim();
        if (rawRoomId.isNotEmpty) {
          activeResidentRoomIds.add(rawRoomId);
          try {
            activeResidentRoomIds.add(
              await residentService.resolveRoomId(rawRoomId),
            );
          } catch (_) {}
        }
        final stay = await stayFromResident(resident, roomCache: cache);
        if (stay == null) continue;
        if (stay.status != 'dangO') continue;
        if (stay.roomId.trim().isNotEmpty) {
          activeResidentRoomIds.add(stay.roomId.trim());
        }
        if (coveredRooms.contains(stay.roomId) ||
            coveredRooms.contains(resident.roomId.trim())) {
          continue;
        }
        coveredRooms.add(stay.roomId);
        residentStays.add(stay);
      } catch (e) {
        debugPrint('Error mapping resident ${doc.id}: $e');
      }
    }

    final merged = mergeRenterStayLists(
      bookings: bookings,
      residentStays: residentStays,
    );
    final titled = <BookingRequestModel>[];
    for (final stay in merged) {
      titled.add(await _withHostRoomTitle(stay, cache));
    }
    return _applyCheckoutRecords(
      renterId,
      titled,
      activeResidentRoomIds: activeResidentRoomIds,
    );
  }

  DateTime? _parseCheckoutTime(Map<String, dynamic> data) {
    for (final key in [
      'checkoutTime',
      'thoiGianCheckout',
      'ngayCheckout',
      'createdAt',
    ]) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return null;
  }

  void _putLatestCheckout(
    Map<String, DateTime> latest,
    String roomId,
    DateTime checkoutAt,
  ) {
    final id = roomId.trim();
    if (id.isEmpty) return;
    final prev = latest[id];
    if (prev == null || checkoutAt.isAfter(prev)) {
      latest[id] = checkoutAt;
    }
  }

  /// roomId (kể cả id đã resolve) → lần checkout mới nhất của người thuê đó.
  Future<Map<String, DateTime>> _latestCheckoutByRoom(String renterId) async {
    final latest = <String, DateTime>{};
    try {
      final snap = await _firestore
          .collection('checkout_records')
          .where('renterId', isEqualTo: renterId)
          .get();
      final residentService = ResidentService(_firestore);
      for (final doc in snap.docs) {
        final data = doc.data();
        final roomId = (data['roomId'] ?? data['phongId'] ?? '')
            .toString()
            .trim();
        if (roomId.isEmpty) continue;
        final checkoutAt = _parseCheckoutTime(data);
        if (checkoutAt == null) continue;
        _putLatestCheckout(latest, roomId, checkoutAt);
        try {
          _putLatestCheckout(
            latest,
            await residentService.resolveRoomId(roomId),
            checkoutAt,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error loading checkout_records for $renterId: $e');
    }
    return latest;
  }

  Future<void> _healCheckedOutBooking(String bookingId) async {
    if (bookingId.isEmpty) return;
    try {
      final ref = _firestore.collection('bookings').doc(bookingId);
      final doc = await ref.get();
      if (!doc.exists) return;
      final status = (doc.data()?['status'] ?? doc.data()?['trangThai'] ?? '')
          .toString()
          .toLowerCase();
      if (status == 'checked_out' ||
          status == 'checkout' ||
          status == 'traphong' ||
          status == 'daketthuc' ||
          status == 'daroi' ||
          status == 'ended' ||
          status == 'moved_out') {
        return;
      }
      if (status != 'active' &&
          status != 'dango' &&
          status != 'dang_o' &&
          status != 'danhanphong') {
        return;
      }
      await ref.set({
        'status': 'checked_out',
        'subTag': 'Đã trả phòng',
        'description': 'Đã check-out / trả phòng',
        'moveOutDate': FieldValue.serverTimestamp(),
        'checkedOutAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error healing checked-out booking $bookingId: $e');
    }
  }

  Future<void> _healActiveBooking(String bookingId) async {
    if (bookingId.isEmpty) return;
    try {
      final ref = _firestore.collection('bookings').doc(bookingId);
      final doc = await ref.get();
      if (!doc.exists) return;
      final status = (doc.data()?['status'] ?? doc.data()?['trangThai'] ?? '')
          .toString()
          .toLowerCase();
      const ended = {
        'checked_out',
        'checkout',
        'traphong',
        'daketthuc',
        'daroi',
        'ended',
        'moved_out',
      };
      if (!ended.contains(status)) return;
      await ref.set({
        'status': 'dangO',
        'subTag': 'Đang ở',
        'description': 'Đang ở (Đã bàn giao phòng)',
        'moveOutDate': FieldValue.delete(),
        'checkedOutAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error restoring active booking $bookingId: $e');
    }
  }

  Future<List<BookingRequestModel>> _applyCheckoutRecords(
    String renterId,
    List<BookingRequestModel> stays, {
    Set<String> activeResidentRoomIds = const {},
  }) async {
    if (stays.isEmpty) return stays;
    final latestByRoom = await _latestCheckoutByRoom(renterId);
    if (latestByRoom.isEmpty && activeResidentRoomIds.isEmpty) return stays;

    final residentService = ResidentService(_firestore);
    final result = <BookingRequestModel>[];
    for (final stay in stays) {
      var roomId = stay.roomId.trim();
      try {
        if (roomId.isNotEmpty) {
          roomId = await residentService.resolveRoomId(roomId);
        }
      } catch (_) {}
      final hasActiveResident =
          activeResidentRoomIds.contains(stay.roomId.trim()) ||
          (roomId.isNotEmpty && activeResidentRoomIds.contains(roomId));
      DateTime? latestCheckoutAt;
      for (final id in [stay.roomId.trim(), roomId]) {
        if (id.isEmpty) continue;
        final time = latestByRoom[id];
        if (time == null) continue;
        if (latestCheckoutAt == null || time.isAfter(latestCheckoutAt)) {
          latestCheckoutAt = time;
        }
      }
      final overlaid = reconcileStayWithOccupancy(
        stay: stay,
        hasActiveResident: hasActiveResident,
        latestCheckoutAt: latestCheckoutAt,
      );
      if (stay.isActive && overlaid.isEnded) {
        unawaited(_healCheckedOutBooking(stay.id));
      } else if (stay.isEnded && overlaid.isActive) {
        unawaited(_healActiveBooking(stay.id));
      }
      result.add(overlaid);
    }
    return result;
  }

  // Stream danh sách đơn thuê của người thuê: bookings + residents đang ở
  Stream<List<BookingRequestModel>> getRenterBookingsStream(String renterId) {
    if (renterId.isEmpty || renterId == 'guest') {
      return Stream.value([]);
    }

    final bookingsStream = _firestore.collection('bookings').snapshots();
    final residentsStream = ResidentService(_firestore).watchUserDocs(renterId);
    return _combineLatest2(bookingsStream, residentsStream).asyncMap((pair) {
      return _buildRenterStayList(
        renterId: renterId,
        bookingSnap: pair.$1,
        residentSnap: pair.$2,
      );
    });
  }

  // Stream danh sách đơn thuê của chủ trọ
  Stream<List<BookingRequestModel>> getHostBookingsStream(String hostId) {
    if (hostId.isEmpty || hostId == 'guest') {
      return Stream.value([]);
    }

    return _firestore.collection('bookings').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              final docHostId = data['hostId'] ?? data['chuNhaId'] ?? '';
              if (docHostId != hostId) return null;

              // Tự động hủy nếu đơn quá hạn 6 tiếng
              final status = (data['status'] ?? '').toString().toLowerCase();
              if (status == 'pending' || status == 'pending_payment') {
                final exp =
                    data['expiresAt'] as Timestamp? ??
                    data['deadline'] as Timestamp?;
                if (exp != null && exp.toDate().isBefore(DateTime.now())) {
                  unawaited(autoCancelIfExpired(doc));
                }
              }

              return BookingRequestModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing host booking ${doc.id}: $e');
              return null;
            }
          })
          .whereType<BookingRequestModel>()
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Đơn thuê đang ở hoặc đã duyệt của khách, dùng khi đăng tin ở ghép đã có phòng.
  Future<BookingRequestModel?> findActiveBookingForRenter(
    String renterId,
  ) async {
    if (renterId.isEmpty || renterId == 'guest') return null;
    try {
      final snapshot = await _firestore.collection('bookings').get();
      BookingRequestModel? approved;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_bookingOwnerId(data) != renterId) continue;
        final booking = await _withHostRoomTitle(
          BookingRequestModel.fromFirestore(doc),
          {},
        );
        if (booking.isActive) return booking;
        if (approved == null && booking.isApproved) approved = booking;
      }
      final residentStays = await loadResidentStays(renterId, activeOnly: true);
      if (residentStays.isNotEmpty) return residentStays.first;
      return approved == null
          ? null
          : _withHostRoomTitle(approved, {});
    } catch (e) {
      debugPrint('Error finding active booking for $renterId: $e');
      return null;
    }
  }
}

Stream<(A, B)> _combineLatest2<A, B>(Stream<A> streamA, Stream<B> streamB) {
  late final StreamController<(A, B)> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (!hasA || !hasB || controller.isClosed) return;
    controller.add((latestA as A, latestB as B));
  }

  controller = StreamController<(A, B)>(
    onListen: () {
      subA = streamA.listen(
        (value) {
          latestA = value;
          hasA = true;
          emit();
        },
        onError: controller.addError,
      );
      subB = streamB.listen(
        (value) {
          latestB = value;
          hasB = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}

final bookingServiceProvider = Provider<BookingService>(
  (ref) => BookingService(),
);

final renterBookingsStreamProvider = StreamProvider.autoDispose
    .family<List<BookingRequestModel>, String>((ref, renterId) {
      final service = ref.watch(bookingServiceProvider);
      return service.getRenterBookingsStream(renterId);
    });

final hostBookingsStreamProvider = StreamProvider.autoDispose
    .family<List<BookingRequestModel>, String>((ref, hostId) {
      final service = ref.watch(bookingServiceProvider);
      return service.getHostBookingsStream(hostId);
    });
