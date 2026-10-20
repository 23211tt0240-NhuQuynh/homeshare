import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/booking_model.dart';
<<<<<<< HEAD
import '../utils/id_generator.dart';
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

<<<<<<< HEAD
  // Gửi yêu cầu đặt thuê / hẹn xem phòng (Đơn đặt phòng, sinh Document ID chuẩn DP_...)
  Future<String> createBooking(BookingRequestModel booking) async {
    final bookingId = booking.id.isNotEmpty
        ? booking.id
        : IdGenerator.booking(
            renterCode: booking.renterUserCode,
            roomCode: booking.roomId,
          );
    await _firestore.collection('bookings').doc(bookingId).set({
      ...booking.toMap(),
      'id': bookingId,
      'bookingCode': bookingId,
    });
    return bookingId;
=======
  // Gửi yêu cầu đặt thuê / hẹn xem phòng (Đơn đặt phòng, trả về Document ID)
  Future<String> createBooking(BookingRequestModel booking) async {
    final docRef = await _firestore.collection('bookings').add(booking.toMap());
    return docRef.id;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }

  // Cập nhật trạng thái thanh toán hoặc trạng thái đơn đặt phòng
  Future<void> updateBookingStatus(String bookingId, String status) async {
    if (bookingId.isEmpty) return;
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
<<<<<<< HEAD
=======
      'trangThai': status == 'paid' ? 'daThanhToan' : status,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream danh sách đơn thuê của người thuê (an toàn, tránh lỗi composite index bằng in-memory sort)
  Stream<List<BookingRequestModel>> getRenterBookingsStream(String renterId) {
    if (renterId.isEmpty || renterId == 'guest') {
      return Stream.value([]);
    }

    return _firestore
        .collection('bookings')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
<<<<<<< HEAD
          final docRenterId = data['nguoiDungId'] ?? data['nguoiDung_Id'] ?? data['renterId'] ?? data['khachXemId'] ?? '';
=======
          final docRenterId = data['renterId'] ?? data['nguoiDung_Id'] ?? data['khachXemId'] ?? '';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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

  // Hủy đơn thuê (cập nhật cả status và trangThai)
  Future<void> cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
<<<<<<< HEAD
      'trangThai': 'daHuy',
      'ngayCapNhat': FieldValue.serverTimestamp(),
=======
      'status': 'cancelled',
      'trangThai': 'daHuy',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    });
  }
}

final bookingServiceProvider = Provider<BookingService>((ref) => BookingService());

final renterBookingsStreamProvider = StreamProvider.autoDispose.family<List<BookingRequestModel>, String>((ref, renterId) {
  final service = ref.watch(bookingServiceProvider);
  return service.getRenterBookingsStream(renterId);
});
