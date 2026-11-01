import 'resident_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/resident_model.dart';
import '../constants/firestore_collections.dart';
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
    await _firestore.collection('bookings').doc(bookingId).set({
      ...booking.toMap(),
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
      return BookingRequestModel.fromFirestore(doc);
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
      await _firestore.collection(FirestoreCollections.notificationUser).doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'receiverId': renterId,
        'userId': renterId,
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
      await _firestore.collection(FirestoreCollections.notificationUser).doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'receiverId': renterId,
        'userId': renterId,
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
      await _firestore.collection(FirestoreCollections.notificationUser).doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'receiverId': renterId,
        'userId': renterId,
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
    final existingBookingIds = {for (final booking in bookings) booking.id};
    final activeBookedRooms = <String>{
      for (final booking in bookings)
        if (booking.isActive && booking.roomId.trim().isNotEmpty)
          booking.roomId.trim(),
    };

    final merged = [...bookings];
    for (final stay in residentStays) {
      if (existingBookingIds.contains(stay.id)) continue;
      final roomId = stay.roomId.trim();
      if (roomId.isEmpty) continue;
      if (stay.isActive) {
        if (activeBookedRooms.contains(roomId)) continue;
        activeBookedRooms.add(roomId);
        merged.add(stay);
      } else {
        // Stay đã check out từ residents (vào lịch sử đã ở, không vào đã hủy):
        // Nếu trong bookings chưa có đơn nào đã check out cho phòng này thì giữ lại stay
        final hasCheckedOutBooking = bookings.any(
          (b) => b.isCheckedOut && (b.roomId.trim() == roomId),
        );
        if (!hasCheckedOutBooking) {
          merged.add(stay);
        }
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// Chuẩn hóa riêng hậu tố số phòng dạng -01 thành -1 (và -002 thành -2).
  /// Không đụng phần giữa chuỗi, không đổi các tên không có hậu tố số 0 đầu.
  static String formatRoomTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceFirstMapped(
      RegExp(r'-0+([1-9]\d*)$'),
      (match) => '-${match[1]}',
    );
  }

  /// Trích xuất tiêu đề phòng thật (live title) từ host_rooms/rooms/posts,
  /// ưu tiên host_rooms title/roomTitle, chuẩn hóa hậu tố và fallback về bookingTitle.
  @visibleForTesting
  static String resolveLiveRoomTitle({
    required String bookingTitle,
    Map<String, dynamic>? roomData,
  }) {
    String pick(List<dynamic> values) {
      for (final v in values) {
        final s = (v ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    // Nếu dữ liệu đến từ post/room (không phải host_rooms),
    // TUYỆT ĐỐI KHÔNG lấy title bài đăng dài dòng của post!
    final isExplicitPost = roomData?['_isHostRoom'] == false;

    if (!isExplicitPost) {
      final live = pick([
        roomData?['title'],
        roomData?['roomTitle'],
        roomData?['tieuDe'],
        roomData?['roomCode'],
        roomData?['maPhong'],
      ]);
      if (live.isNotEmpty) return formatRoomTitle(live);
    }

    // Nếu là dữ liệu từ post, chỉ lấy mã phòng (roomCode / maPhong), không lấy post title:
    final roomCodeOnly = pick([
      roomData?['roomCode'],
      roomData?['maPhong'],
    ]);
    if (roomCodeOnly.isNotEmpty) {
      return formatRoomTitle(roomCodeOnly);
    }

    final rawTitle = bookingTitle.trim();
    return formatRoomTitle(rawTitle);
  }

  Future<Map<String, dynamic>> _loadRoomData(
    String roomId,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final cached = cache[roomId];
    if (cached != null) return cached;

    // 1. Luôn ưu tiên tra cứu trực tiếp trong collection host_rooms
    try {
      final doc = await _firestore.collection('host_rooms').doc(roomId).get();
      if (doc.exists && doc.data() != null) {
        final data = {'id': doc.id, ...doc.data()!, '_isHostRoom': true};
        cache[roomId] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Error loading host_rooms/$roomId: $e');
    }

    // 2. Nếu không có trong host_rooms, có thể roomId là ID bài đăng trong 'posts' hoặc 'rooms'
    for (final collection in ['posts', 'rooms']) {
      try {
        final doc = await _firestore.collection(collection).doc(roomId).get();
        if (doc.exists && doc.data() != null) {
          final postData = doc.data()!;
          // Tìm xem bài đăng có liên kết tới host_rooms ID không
          for (final key in [
            'hostRoomId',
            'phongId',
            'roomId',
            'room_id',
            'host_room_id',
          ]) {
            final linkedId = (postData[key] ?? '').toString().trim();
            if (linkedId.isNotEmpty && linkedId != roomId) {
              try {
                final hostDoc = await _firestore
                    .collection('host_rooms')
                    .doc(linkedId)
                    .get();
                if (hostDoc.exists && hostDoc.data() != null) {
                  final data = {
                    'id': hostDoc.id,
                    ...hostDoc.data()!,
                    '_isHostRoom': true,
                  };
                  cache[roomId] = data;
                  cache[linkedId] = data;
                  return data;
                }
              } catch (_) {}
            }
          }

          // Tìm theo roomCode / maPhong trong host_rooms
          final rCode =
              (postData['roomCode'] ?? postData['maPhong'] ?? '').toString().trim();
          if (rCode.isNotEmpty) {
            try {
              final q = await _firestore
                  .collection('host_rooms')
                  .where('roomCode', isEqualTo: rCode)
                  .limit(1)
                  .get();
              if (q.docs.isNotEmpty) {
                final hostDoc = q.docs.first;
                final data = {
                  'id': hostDoc.id,
                  ...hostDoc.data(),
                  '_isHostRoom': true,
                };
                cache[roomId] = data;
                return data;
              }
            } catch (_) {}
          }

          // Không tìm thấy host_rooms -> đánh dấu _isHostRoom: false, chỉ giữ roomCode, bỏ post title
          final data = {
            'id': doc.id,
            ...postData,
            '_isHostRoom': false,
            'postTitle': postData['title'] ?? '',
          };
          cache[roomId] = data;
          return data;
        }
      } catch (e) {
        debugPrint('Error loading $collection/$roomId: $e');
      }
    }

    final empty = <String, dynamic>{'id': roomId, '_isHostRoom': false};
    cache[roomId] = empty;
    return empty;
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

    final rawRoomTitle = pickString([
      roomData['title'],
      roomData['tieuDe'],
      roomData['roomTitle'],
      roomData['roomCode'],
      primaryBooking['roomTitle'],
      primaryBooking['tieuDePhong'],
      roomId,
    ], roomId);
    final roomTitle = formatRoomTitle(rawRoomTitle);
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
      note: resident.formId == 'oGhep' ? 'Ở ghép' : (resident.formId.isNotEmpty ? resident.formId : 'Đã hoàn tất trả phòng'),
      cancelReason: null,
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
    final rawBookings = _bookingsForRenter(bookingSnap, renterId);

    // Thu thập trạng thái cư dân từ bảng residents
    final activeResidentRooms = <String>{};
    final activeResidentBookingIds = <String>{};
    final checkedOutBookingIds = <String>{};
    final checkedOutRooms = <String>{};
    final residentRoomForBooking = <String, String>{};
    final residentService = ResidentService(_firestore);

    for (final doc in residentSnap.docs) {
      try {
        final r = ResidentModel.fromFirestore(doc);
        if (r.userId != renterId) continue;
        final roomId = r.roomId.trim();
        String? bId;
        if (r.periodId.isNotEmpty) {
          bId = r.periodId.startsWith('checkin_')
              ? r.periodId.substring('checkin_'.length)
              : r.periodId;
          if (bId.contains('_')) {
            bId = bId.split('_').first;
          }
          if (roomId.isNotEmpty && bId.isNotEmpty) {
            residentRoomForBooking[bId] = roomId;
          }
        }
        if (ResidentService.isActive(r)) {
          if (roomId.isNotEmpty) {
            activeResidentRooms.add(roomId);
            try {
              activeResidentRooms.add(await residentService.resolveRoomId(roomId));
            } catch (_) {}
          }
          if (bId != null && bId.isNotEmpty) activeResidentBookingIds.add(bId);
          if (r.periodId.isNotEmpty) activeResidentBookingIds.add(r.periodId);
        } else {
          if (roomId.isNotEmpty) {
            checkedOutRooms.add(roomId);
            try {
              final canonical = await residentService.resolveRoomId(roomId);
              if (canonical.isNotEmpty) checkedOutRooms.add(canonical);
            } catch (_) {}
          }
          if (r.periodId.isNotEmpty) {
            if (r.periodId.startsWith('checkin_')) {
              checkedOutBookingIds.add(r.periodId.substring('checkin_'.length));
            }
            checkedOutBookingIds.add(r.periodId);
            if (bId != null && bId.isNotEmpty) checkedOutBookingIds.add(bId);
          }
        }
      } catch (e) {
        debugPrint('Error parsing resident for stay list: $e');
      }
    }

    final roomCache = <String, Map<String, dynamic>>{};
    final bookings = <BookingRequestModel>[];
    final activeRoomsCovered = <String>{};

    for (var booking in rawBookings) {
      final roomId = booking.roomId.trim();
      var canonicalRoomId = roomId;
      if (roomId.isNotEmpty) {
        try {
          final resolved = await residentService.resolveRoomId(roomId);
          if (resolved.isNotEmpty) canonicalRoomId = resolved;
        } catch (_) {}
      }

      final isActiveInResident = activeResidentBookingIds.contains(booking.id) ||
          activeResidentRooms.contains(roomId) ||
          (canonicalRoomId.isNotEmpty && activeResidentRooms.contains(canonicalRoomId));

      final isMatchingCheckout = !isActiveInResident && (
          checkedOutBookingIds.contains(booking.id) ||
          ((checkedOutRooms.contains(roomId) || checkedOutRooms.contains(canonicalRoomId)) &&
              !activeResidentRooms.contains(roomId) &&
              !activeResidentRooms.contains(canonicalRoomId)));

      if (isActiveInResident) {
        // Cư dân đã check-in trong bảng residents -> đơn thuê chuyển sang 'dangO' (Đang ở)
        booking = booking.copyWith(
          status: 'dangO',
        );
        if (roomId.isNotEmpty) activeRoomsCovered.add(roomId);
        if (canonicalRoomId.isNotEmpty) activeRoomsCovered.add(canonicalRoomId);
      } else if (isMatchingCheckout && !booking.isCheckedOut && !booking.isCancelled) {
        // Cư dân đã check out trong bảng residents -> chuyển đơn thuê sang hoàn tất/checked_out (vào lịch sử đã ở, KHÔNG vào đã hủy)
        booking = booking.copyWith(
          status: 'checked_out',
          note: booking.note.isNotEmpty ? booking.note : 'Đã hoàn tất trả phòng',
        );

        // Đồng bộ cập nhật lên Firestore bookings doc
        unawaited(_firestore.collection('bookings').doc(booking.id).set({
          'status': 'checked_out',
          'subTag': 'Đã trả phòng',
          'description': 'Đã hoàn tất trả phòng',
          'trangThai': 'daKetThuc',
          'isCheckIn': false,
          'daNhanPhong': false,
          'checkoutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
      }

      // Luôn phân giải tiêu đề phòng thật từ host_rooms cho mọi đơn thuê (thay vì lấy snapshot cũ hoặc post title):
      var targetRoomId = residentRoomForBooking[booking.id] ?? roomId;
      if (targetRoomId.isNotEmpty) {
        try {
          final resolved = await residentService.resolveRoomId(targetRoomId);
          if (resolved.isNotEmpty) targetRoomId = resolved;
        } catch (_) {}

        final roomData = await _loadRoomData(targetRoomId, roomCache);
        final liveTitle = resolveLiveRoomTitle(
          bookingTitle: booking.roomTitle,
          roomData: roomData,
        );
        if (liveTitle.isNotEmpty) {
          booking = booking.copyWith(roomTitle: liveTitle);
        }
      } else {
        booking = booking.copyWith(
          roomTitle: formatRoomTitle(booking.roomTitle),
        );
      }

      if (booking.isActive) {
        if (roomId.isNotEmpty) activeRoomsCovered.add(roomId);
        if (canonicalRoomId.isNotEmpty) activeRoomsCovered.add(canonicalRoomId);
      }

      bookings.add(booking);
    }

    final residentStays = <BookingRequestModel>[];
    for (final doc in residentSnap.docs) {
      try {
        final resident = ResidentModel.fromFirestore(doc);
        if (resident.userId != renterId) continue;
        final isActiveResident = ResidentService.isActive(resident);
        final stay = await stayFromResident(resident, roomCache: roomCache);
        if (stay == null) continue;

        final stayRoom = stay.roomId.trim();
        final resRoom = resident.roomId.trim();
        if (isActiveResident) {
          if (!stay.isActive) continue;
          if (activeRoomsCovered.contains(stayRoom) || activeRoomsCovered.contains(resRoom)) {
            continue;
          }
          if (stayRoom.isNotEmpty) activeRoomsCovered.add(stayRoom);
          if (resRoom.isNotEmpty) activeRoomsCovered.add(resRoom);
          residentStays.add(stay);
        } else {
          // Resident đã check out nhưng không có đơn bookings riêng
          if (activeRoomsCovered.contains(stayRoom) || activeRoomsCovered.contains(resRoom)) {
            continue;
          }
          if (stayRoom.isNotEmpty) activeRoomsCovered.add(stayRoom);
          residentStays.add(stay.copyWith(
            status: 'checked_out',
            note: stay.note.isNotEmpty ? stay.note : 'Đã hoàn tất trả phòng',
          ));
        }
      } catch (e) {
        debugPrint('Error mapping resident ${doc.id}: $e');
      }
    }

    return mergeRenterStayLists(bookings: bookings, residentStays: residentStays);
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
      final residents = await ResidentService(_firestore).forUser(renterId);
      final checkedOutRoomIds = residents
          .where((r) => !ResidentService.isActive(r))
          .map((r) => r.roomId.trim())
          .toSet();
      final activeResidentRoomIds = residents
          .where(ResidentService.isActive)
          .map((r) => r.roomId.trim())
          .toSet();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_bookingOwnerId(data) != renterId) continue;
        final booking = BookingRequestModel.fromFirestore(doc);
        final bRoom = booking.roomId.trim();
        final isCheckedOut = checkedOutRoomIds.contains(bRoom) &&
            !activeResidentRoomIds.contains(bRoom);

        if (booking.isActive && !isCheckedOut) return booking;
        if (approved == null && booking.isApproved && !isCheckedOut) {
          approved = booking;
        }
      }
      final residentStays = await loadResidentStays(renterId, activeOnly: true);
      if (residentStays.isNotEmpty) return residentStays.first;
      return approved;
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
