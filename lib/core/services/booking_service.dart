import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/booking_model.dart';
import '../utils/id_generator.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Lấy chi tiết 1 đơn thuê theo bookingId
  Future<BookingRequestModel?> getBookingById(String bookingId) async {
    if (bookingId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return null;
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

    final docSnap = await _firestore.collection('bookings').doc(bookingId).get();
    final data = docSnap.data() ?? {};
    final renterId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
    final hostId = (data['hostId'] ?? data['chuNhaId'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ').toString();
    final renterName = (data['renterName'] ?? data['tenNguoiO'] ?? 'Khách thuê').toString();

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
        'message': 'Đơn đặt phòng "$roomTitle" đã được duyệt thành công! Bạn có thể mở mã QR nhận phòng để chuẩn bị dọn vào.',
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
        if (rRole == 'host' || recId == hostId || dData.containsKey('roomFloorInfo')) {
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
      'details': 'Đã duyệt đơn $bookingId cho phòng $roomTitle của khách $renterName',
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

    final docSnap = await _firestore.collection('bookings').doc(bookingId).get();
    final data = docSnap.data() ?? {};
    final finalRoomId = roomId ?? (data['roomId'] ?? data['phongId'] ?? '').toString();
    final renterId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
    final renterName = (data['renterName'] ?? data['tenNguoiO'] ?? 'Khách thuê').toString();
    final renterPhone = (data['renterPhone'] ?? data['sdtNguoiO'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ').toString();

    // Cập nhật booking sang trạng thái 'dangO'
    await _firestore.collection('bookings').doc(bookingId).set({
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

    // Cập nhật phòng sang trạng thái 'occupied' (đang thuê)
    if (finalRoomId.isNotEmpty) {
      await _firestore.collection('host_rooms').doc(finalRoomId).set({
        'status': 'occupied',
        'tenantName': renterName,
        'tenantPhone': renterPhone,
        'contractStart': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    // Thông báo cho người thuê
    if (renterId.isNotEmpty && renterId != 'guest') {
      final notifId = IdGenerator.notification();
      await _firestore.collection('notifications').doc(notifId).set({
        'id': notifId,
        'recipientId': renterId,
        'recipientRole': 'renter',
        'title': 'Nhận phòng thành công! 🎉',
        'message': 'Chủ trọ đã xác nhận bàn giao phòng "$roomTitle". Chúc bạn có khoảng thời gian sinh sống tiện nghi và thoải mái!',
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
      'details': 'Khách $renterName đã nhận phòng $roomTitle thành công qua mã QR',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. HỦY ĐƠN (Chuyển sang Đã hủy / cancelled)
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    if (bookingId.isEmpty) return;
    final now = DateTime.now();

    final docSnap = await _firestore.collection('bookings').doc(bookingId).get();
    final data = docSnap.data() ?? {};
    final renterId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
    final hostId = (data['hostId'] ?? data['chuNhaId'] ?? '').toString();
    final roomId = (data['roomId'] ?? data['phongId'] ?? '').toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ').toString();

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
        'message': 'Đơn đặt phòng "$roomTitle" đã được hủy.${reason != null && reason.isNotEmpty ? " Lý do: $reason" : ""}',
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
        'message': 'Đơn phòng "$roomTitle" đã chuyển sang trạng thái đã hủy.${reason != null && reason.isNotEmpty ? " Lý do: $reason" : ""}',
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
      await checkinBooking(bookingId, roomId: roomId, hostId: hostId, note: reason);
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

  // Stream danh sách đơn thuê của người thuê (an toàn, tránh lỗi composite index bằng in-memory sort)
  Stream<List<BookingRequestModel>> getRenterBookingsStream(String renterId) {
    if (renterId.isEmpty || renterId == 'guest') {
      return Stream.value([]);
    }

    return _firestore.collection('bookings').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final docRenterId = data['nguoiDungId'] ??
              data['nguoiDung_Id'] ??
              data['renterId'] ??
              data['khachXemId'] ??
              '';
          if (docRenterId != renterId) return null;
          return BookingRequestModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error parsing booking ${doc.id}: $e');
          return null;
        }
      }).whereType<BookingRequestModel>().toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Stream danh sách đơn thuê của chủ trọ
  Stream<List<BookingRequestModel>> getHostBookingsStream(String hostId) {
    if (hostId.isEmpty || hostId == 'guest') {
      return Stream.value([]);
    }

    return _firestore.collection('bookings').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final docHostId = data['hostId'] ?? data['chuNhaId'] ?? '';
          if (docHostId != hostId) return null;
          return BookingRequestModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error parsing host booking ${doc.id}: $e');
          return null;
        }
      }).whereType<BookingRequestModel>().toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Đơn thuê đang ở hoặc đã duyệt của khách, dùng khi đăng tin ở ghép đã có phòng.
  Future<BookingRequestModel?> findActiveBookingForRenter(String renterId) async {
    if (renterId.isEmpty || renterId == 'guest') return null;
    try {
      final snapshot = await _firestore.collection('bookings').get();
      BookingRequestModel? approved;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docRenterId = data['nguoiDungId'] ??
            data['nguoiDung_Id'] ??
            data['renterId'] ??
            data['khachXemId'] ??
            '';
        if (docRenterId != renterId) continue;
        final booking = BookingRequestModel.fromFirestore(doc);
        if (booking.isActive) return booking;
        if (approved == null && booking.isApproved) approved = booking;
      }
      return approved;
    } catch (e) {
      debugPrint('Error finding active booking for $renterId: $e');
      return null;
    }
  }
}

final bookingServiceProvider = Provider<BookingService>((ref) => BookingService());

final renterBookingsStreamProvider = StreamProvider.autoDispose.family<List<BookingRequestModel>, String>((ref, renterId) {
  final service = ref.watch(bookingServiceProvider);
  return service.getRenterBookingsStream(renterId);
});

final hostBookingsStreamProvider = StreamProvider.autoDispose.family<List<BookingRequestModel>, String>((ref, hostId) {
  final service = ref.watch(bookingServiceProvider);
  return service.getHostBookingsStream(hostId);
});
