import '../../data/models/room_model.dart';
import 'resident_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/resident_model.dart';
import '../constants/firestore_collections.dart';
import '../utils/id_generator.dart';
import '../utils/transfer_order_code.dart';
import 'host_index_service.dart';

class BookingService {
  final FirebaseFirestore _firestore;
  BookingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _activeBookingStatuses = {
    'pending',
    'pending_payment',
    'pending_confirmation',
    'approved',
    'deposit_paid',
    'dacoc',
    'paid',
    'completed',
    'active',
    'dango',
    'danhanphong',
    'chonhanphong',
    'reserved',
  };

  /// Một người không được thuê trùng cùng phòng vật lý qua bài đăng khác
  /// khi vẫn còn đơn đang hiệu lực (chưa hủy / chưa checkout).
  Future<void> assertNoActiveBookingForSameRoom({
    required String renterId,
    required String roomReference,
  }) async {
    final uid = renterId.trim();
    if (uid.isEmpty || uid == 'guest') return;
    final realRoomId =
        await _resolveRealRoomId(roomReference) ?? roomReference.trim();
    if (realRoomId.isEmpty) return;

    final snap = await _firestore
        .collection('bookings')
        .where('renterId', isEqualTo: uid)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (!_activeBookingStatuses.contains(status)) continue;
      if (data['daHuy'] == true) continue;
      final ref = (data['roomId'] ?? data['phongId'] ?? data['hostRoomId'] ?? '')
          .toString()
          .trim();
      if (ref.isEmpty) continue;
      final linked = await _resolveRealRoomId(ref) ?? ref;
      if (linked == realRoomId || ref == realRoomId) {
        throw StateError(
          'Bạn đang có đơn thuê cho phòng này (kể cả qua bài đăng khác). '
          'Hủy đơn cũ hoặc hoàn tất trả phòng trước khi đặt lại.',
        );
      }
    }
  }

  // Gửi yêu cầu đặt thuê / hẹn xem phòng (Đơn đặt phòng, sinh Document ID chuẩn DP_...)
  Future<String> createBooking(
    BookingRequestModel booking, {
    String? propertyId,
  }) async {
    await assertNoActiveBookingForSameRoom(
      renterId: booking.renterId,
      roomReference: booking.roomId,
    );

    final realRoomId =
        await _resolveRealRoomId(booking.roomId) ?? booking.roomId.trim();
    final bookingId = booking.id.isNotEmpty
        ? booking.id
        : IdGenerator.booking(
            renterCode: booking.renterUserCode,
            roomCode: realRoomId.isNotEmpty ? realRoomId : booking.roomId,
          );
    final now = DateTime.now();
    // Giai đoạn 1 (Hybrid): Quét mã QR giữ chỗ trong 15 phút (trước khi khách bấm xác nhận đã chuyển khoản)
    final expiresAt = (booking.createdAt.year > 2000)
        ? booking.createdAt.add(const Duration(minutes: 15))
        : now.add(const Duration(minutes: 15));
    final hostRoomTitle = await titleFromHostRooms(booking.roomId);
    var stored = hostRoomTitle.isNotEmpty
        ? booking.copyWith(roomTitle: hostRoomTitle)
        : booking;
    // Luôn neo roomId về phòng thật trên host_rooms để các bài đăng khác
    // cùng phòng không bị coi là phòng khác khi kiểm tra / giữ chỗ.
    if (realRoomId.isNotEmpty && realRoomId != stored.roomId) {
      stored = stored.copyWith(roomId: realRoomId);
    }

    // Nội dung CK ngắn: hostIndex + 4 ký tự cuối đơn → lưu orderCode & transferNote.
    String transferNote = (stored.transferNote ?? '').trim();
    var hostIndex = 0;
    final hostId = stored.hostId.trim();
    if (hostId.isNotEmpty) {
      try {
        hostIndex = await HostIndexService(firestore: _firestore)
            .ensureHostIndex(hostId);
      } catch (e) {
        debugPrint('Không lấy được hostIndex khi tạo đơn: $e');
      }
    }
    if (hostIndex > 0) {
      transferNote = TransferOrderCode.build(
        hostIndex: hostIndex,
        bookingId: bookingId,
      );
    } else if (transferNote.isEmpty) {
      transferNote = TransferOrderCode.build(
        hostIndex: 1,
        bookingId: bookingId,
      );
    }

    await _firestore.collection('bookings').doc(bookingId).set({
      ...stored.toMap(),
      if (propertyId != null && propertyId.isNotEmpty) 'propertyId': propertyId,
      'id': bookingId,
      'bookingCode': bookingId,
      'orderCode': transferNote,
      'transferNote': transferNote,
      if (hostIndex > 0) 'hostIndex': hostIndex,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'deadline': Timestamp.fromDate(expiresAt),
    });

    // Cập nhật trạng thái giữ phòng tạm thời 15 phút trên host_rooms (phòng thật)
    final holdRoomId = realRoomId.isNotEmpty ? realRoomId : booking.roomId;
    if (holdRoomId.isNotEmpty) {
      await _firestore.collection('host_rooms').doc(holdRoomId).set({
        'isHolding': true,
        'holdingBookingId': bookingId,
        'holdingRenterId': booking.renterId,
        'holdingExpiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }
    return bookingId;
  }

  static String _firstNonEmptyString(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
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
          final isPendingPayment = status == 'pending_payment';
          exp = Timestamp.fromDate(
            createdAt.toDate().add(Duration(minutes: isPendingPayment ? 15 : 360)),
          );
        }
      }
      if (exp != null && exp.toDate().isBefore(DateTime.now())) {
        final isPendingPayment = status == 'pending_payment';
        await cancelBooking(
          doc.id,
          reason: isPendingPayment
              ? 'Tự động hủy do quá thời gian quét mã QR giữ chỗ (15 phút)'
              : 'Tự động hủy do quá thời gian chờ xác nhận (6 tiếng)',
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

  /// Tìm đúng ID phòng thực tế từ collection host_rooms hoặc từ bài đăng.
  Future<String?> _resolveRealRoomId(String inputId) async {
    if (inputId.trim().isEmpty) return null;
    final cleanId = inputId.trim();

    // 1. Kiểm tra trực tiếp trong host_rooms
    try {
      final hostDoc =
          await _firestore.collection('host_rooms').doc(cleanId).get();
      if (hostDoc.exists) return cleanId;
    } catch (_) {}

    // 2. Nếu inputId là postId, tìm trường roomId / phongId từ document posts
    try {
      final postDoc = await _firestore.collection('posts').doc(cleanId).get();
      if (postDoc.exists && postDoc.data() != null) {
        final pData = postDoc.data()!;
        final linkedId = (pData['roomId'] ??
                pData['phongId'] ??
                pData['phong_tro_id'] ??
                '')
            .toString()
            .trim();
        if (linkedId.isNotEmpty && linkedId != cleanId) {
          final resolved = await _resolveRealRoomId(linkedId);
          if (resolved != null) return resolved;
        }
      }
    } catch (_) {}

    return null;
  }

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

  
  Future<void> confirmPayment(
    String bookingId,
    Map<String, dynamic> patch,
  ) async {
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final snapshot = await bookingRef.get();
    if (!snapshot.exists) throw StateError('Không tìm thấy đơn đặt phòng');
    final data = snapshot.data()!;
    final reference =
        (data['phongId'] ?? data['roomId'] ?? data['baiDangId'] ?? '')
            .toString();
    final roomId = await ResidentService(_firestore).resolveRoomId(reference);
    final roomRef = _firestore.collection('host_rooms').doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final booking = await transaction.get(bookingRef);
      final room = await transaction.get(roomRef);
      if (!booking.exists || !room.exists) {
        throw StateError('Không tìm thấy đơn đặt phòng hoặc phòng');
      }
      final status = (booking.data()?['status'] ?? '').toString().toLowerCase();
      if (const [
        'cancelled',
        'canceled',
        'dahuy',
        'expired',
        'rejected',
      ].contains(status)) {
        throw StateError('Không thể xác nhận cọc cho đơn đã hủy hoặc hết hạn.');
      }
      final owner = room.data()?['reservedBookingId'];
      if (owner != bookingId &&
          (owner != null || !RoomModel.fromFirestore(room).canBeListed)) {
        throw StateError(
          'Phòng đã được người khác đặt cọc hoặc không còn trống.',
        );
      }
      // Post creation also touches roomRef. A concurrent new listing forces
      // this transaction to retry and collect that listing before hiding it.
      final posts = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final collection in ['posts', 'bai_dang_cho_thue']) {
        for (final field in [
          'hostRoomId',
          'roomId',
          'phongId',
          'room_id',
          'phong_tro_id',
        ]) {
          for (final id in {roomId, reference}) {
            final result = await _firestore
                .collection(collection)
                .where(field, isEqualTo: id)
                .get();
            for (final doc in result.docs) {
              posts[doc.reference.path] = doc.reference;
            }
          }
        }
      }
      transaction.update(bookingRef, {...patch, 'isPaid': true});
      transaction.update(roomRef, {
        'status': room.data()?['status'] == 'occupied'
            ? 'occupied'
            : 'reserved',
        'isAvailable': false,
        'reservedBookingId': bookingId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final post in posts.values) {
        transaction.update(post, {
          'status': 'occupied',
          'isAvailable': FieldValue.delete(),
          'isPinned': FieldValue.delete(),
          'statusId': FieldValue.delete(),
          'trang_thai': FieldValue.delete(),
          'hiddenReason': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
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

    final approvedRoomId = await ResidentService(_firestore).resolveRoomId(
      (data['roomId'] ?? data['phongId'] ?? data['baiDangId'] ?? '').toString(),
    );
    if (approvedRoomId.isNotEmpty) {
      await markPostsOccupied(
        approvedRoomId,
        tenantName: renterName,
      );
    }

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
            'status': 'approved',
            'statusId': FieldValue.delete(),
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
    final renterName = (data['renterName'] ?? data['tenNguoiO'] ?? data['tenKhach'] ?? 'Khách thuê')
        .toString();
    final renterPhone = (data['renterPhone'] ?? data['sdtNguoiO'] ?? data['sdtKhach'] ?? '')
        .toString();
    final roomTitle = (data['roomTitle'] ?? data['tieuDePhong'] ?? data['tenPhong'] ?? 'Phòng trọ')
        .toString();
    final roomAddress = (data['roomAddress'] ?? data['diaChiPhong'] ?? data['diaChi'] ?? '').toString();
    final rentalPrice = data['rentalPrice'] ?? data['giaThue'] ?? data['giaPhong'];
    final depositAmount = data['depositAmount'] ?? data['tienCoc'] ?? data['deposit'];
    final totalPayment = data['totalPayment'] ?? data['tongPhaiTra'] ?? data['tongTien'];
    final rentalMonths = data['rentalMonths'] ?? data['soThangThue'];
    final paymentMethod = (data['paymentMethod'] ?? data['hinhThucThanhToan'] ?? data['phuongThucThanhToan'] ?? 'Chuyển khoản QR').toString();
    final roomCode = (data['roomCode'] ?? data['maPhong'] ?? '').toString();
    final hostIdFinal = (hostId ?? data['hostId'] ?? data['chuNhaId'] ?? '').toString();

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

    // Cập nhật booking sang chuẩn tiếng Anh và xóa sạch toàn bộ các trường tiếng Việt trùng lặp
    batch.set(_firestore.collection('bookings').doc(bookingId), {
      'status': 'active',
      'isCheckIn': true,
      'isCheckedIn': true,
      'roomId': finalRoomId,
      if (hostIdFinal.isNotEmpty) 'hostId': hostIdFinal,
      if (renterId.isNotEmpty) 'renterId': renterId,
      'renterName': renterName,
      'renterPhone': renterPhone,
      'roomTitle': roomTitle,
      if (roomAddress.isNotEmpty) 'roomAddress': roomAddress,
      'rentalPrice': ?rentalPrice,
      'depositAmount': ?depositAmount,
      'totalPayment': ?totalPayment,
      'rentalMonths': ?rentalMonths,
      'paymentMethod': paymentMethod,
      if (roomCode.isNotEmpty) 'roomCode': roomCode,
      'acceptedDate': Timestamp.fromDate(now),
      'checkedInAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (note != null && note.isNotEmpty) 'checkinNote': note,
      // Xóa toàn bộ trường tiếng Việt tồn đọng
      'phongId': FieldValue.delete(),
      'chuNhaId': FieldValue.delete(),
      'tenNguoiO': FieldValue.delete(),
      'sdtNguoiO': FieldValue.delete(),
      'tenKhach': FieldValue.delete(),
      'sdtKhach': FieldValue.delete(),
      'nguoiThueTen': FieldValue.delete(),
      'nguoiThueSdt': FieldValue.delete(),
      'tieuDePhong': FieldValue.delete(),
      'tenPhong': FieldValue.delete(),
      'diaChiPhong': FieldValue.delete(),
      'diaChi': FieldValue.delete(),
      'giaThue': FieldValue.delete(),
      'giaPhong': FieldValue.delete(),
      'tienCoc': FieldValue.delete(),
      'tongPhaiTra': FieldValue.delete(),
      'tongTien': FieldValue.delete(),
      'soThangThue': FieldValue.delete(),
      'hinhThucThanhToan': FieldValue.delete(),
      'phuongThucThanhToan': FieldValue.delete(),
      'maPhong': FieldValue.delete(),
      'ngayVao': FieldValue.delete(),
      'ngayNhanPhong': FieldValue.delete(),
      'ngayDonVao': FieldValue.delete(),
      'ngayTao': FieldValue.delete(),
      'ngayCapNhat': FieldValue.delete(),
      'daNhanPhong': FieldValue.delete(),
      'daThanhToan': FieldValue.delete(),
      'trangThai': FieldValue.delete(),
      'statusId': FieldValue.delete(),
      'subTag': FieldValue.delete(),
      'description': FieldValue.delete(),
      'ghiChu': FieldValue.delete(),
    }, SetOptions(merge: true));

    batch.set(_firestore.collection('host_rooms').doc(finalRoomId), {
      'status': 'occupied',
      'isAvailable': false,
      'contractId': periodId,
      'tenantName': renterName,
      'tenantPhone': renterPhone,
      'contractStart': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    final realRoomId = await _resolveRealRoomId(finalRoomId);
    if (realRoomId != null && realRoomId.isNotEmpty && realRoomId != finalRoomId) {
      batch.set(_firestore.collection('host_rooms').doc(realRoomId), {
        'status': 'occupied',
        'isAvailable': false,
        'contractId': periodId,
        'tenantName': renterName,
        'tenantPhone': renterPhone,
        'contractStart': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }
    await batch.commit();

    // Chỉ đổi trạng thái bài đăng sang đã có người ở — không ẩn bài.
    await markPostsOccupied(
      finalRoomId,
      tenantName: renterName,
      tenantPhone: renterPhone,
      contractId: periodId,
    );
    if (realRoomId != null &&
        realRoomId.isNotEmpty &&
        realRoomId != finalRoomId) {
      await markPostsOccupied(
        realRoomId,
        tenantName: renterName,
        tenantPhone: renterPhone,
        contractId: periodId,
      );
    }

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

    // Cập nhật thông báo của Chủ trọ sang tab "Đang ở" (staying)
    try {
      var hostNotifSnap = await _firestore
          .collection('notifications')
          .where('bookingId', isEqualTo: bookingId)
          .get();
      if (hostNotifSnap.docs.isEmpty) {
        hostNotifSnap = await _firestore
            .collection('notifications')
            .where('donDatPhongId', isEqualTo: bookingId)
            .get();
      }
      for (final doc in hostNotifSnap.docs) {
        final notifData = doc.data();
        final role = (notifData['recipientRole'] ?? notifData['role'] ?? '').toString();
        if (role != 'renter' && role != 'tenant') {
          await doc.reference.set({
            'notificationType': 'staying',
            'type': 'staying',
            'status': 'occupied',
            'statusId': FieldValue.delete(),
            'title': 'Khách đã nhận phòng và đang ở',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error updating host notification on checkin: $e');
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
      'daHuy': true,
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
      'trangThai': FieldValue.delete(),
      'ngayCapNhat': FieldValue.delete(),
    }, SetOptions(merge: true));

    // Giải phóng phòng về available ngay lập tức (không bắt người khác chờ 15 phút)
    final realRoomId = await _resolveRealRoomId(roomId);
    final targetRoomIds = <String>{
      if (realRoomId != null && realRoomId.isNotEmpty) realRoomId,
      if (roomId.isNotEmpty) roomId,
    };

    for (final rId in targetRoomIds) {
      await _firestore.collection('host_rooms').doc(rId).set({
        'status': 'available',
        'isAvailable': true,
        'bookingStatus': 'available',
        'isHolding': false,
        'holdingBookingId': FieldValue.delete(),
        'holdingRenterId': FieldValue.delete(),
        'holdingExpiresAt': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

    }

    // Quét sạch bất kỳ phòng nào đang giữ chỗ bởi đơn bookingId này
    try {
      final holdingQuery = await _firestore
          .collection('host_rooms')
          .where('holdingBookingId', isEqualTo: bookingId)
          .get();
      for (final d in holdingQuery.docs) {
        await d.reference.set({
          'status': 'available',
          'isAvailable': true,
          'bookingStatus': 'available',
          'isHolding': false,
          'holdingBookingId': FieldValue.delete(),
          'holdingRenterId': FieldValue.delete(),
          'holdingExpiresAt': FieldValue.delete(),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
    if (roomId.isNotEmpty) {
      await restorePostOnCancelledBooking(roomId);
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

  /// Người thuê yêu cầu thay đổi / dời ngày dọn vào ở (Move-in Date)
  Future<void> updateMoveInDate({
    required String bookingId,
    required DateTime newMoveInDate,
    String? reason,
    BookingRequestModel? booking,
  }) async {
    if (bookingId.isEmpty) return;
    final now = DateTime.now();

    final docSnap =
        await _firestore.collection('bookings').doc(bookingId).get();
    final data = docSnap.data() ?? {};
    final renterId = (booking?.renterId.isNotEmpty == true
            ? booking!.renterId
            : (data['renterId'] ?? data['nguoiDungId'] ?? ''))
        .toString();
    final renterName = (booking?.renterName.isNotEmpty == true
            ? booking!.renterName
            : (data['renterName'] ?? data['tenNguoiO'] ?? 'Khách thuê'))
        .toString();
    final hostId = (booking?.hostId.isNotEmpty == true
            ? booking!.hostId
            : (data['hostId'] ?? data['chuNhaId'] ?? ''))
        .toString();
    final roomId = (booking?.roomId.isNotEmpty == true
            ? booking!.roomId
            : (data['roomId'] ?? data['phongId'] ?? ''))
        .toString();
    final roomTitle = (booking?.roomTitle.isNotEmpty == true
            ? booking!.roomTitle
            : (data['roomTitle'] ?? data['tieuDePhong'] ?? 'Phòng trọ'))
        .toString();
    final oldDate = booking?.moveInDate ??
        ((data['moveInDate'] is Timestamp)
            ? (data['moveInDate'] as Timestamp).toDate()
            : ((data['ngayVao'] is Timestamp)
                ? (data['ngayVao'] as Timestamp).toDate()
                : null));

    final oldDateStr =
        oldDate != null ? DateFormat('dd/MM/yyyy').format(oldDate) : '';
    final newDateStr = DateFormat('dd/MM/yyyy').format(newMoveInDate);
    final cleanReason = reason?.trim();

    final bookingCode = (data['bookingCode'] ?? data['maDon'] ?? '').toString();
    final roomCode = (data['roomCode'] ?? data['maPhong'] ?? '').toString();
    final renterAvatarUrl = (data['renterAvatarUrl'] ?? data['anhKhach'] ?? '').toString();
    final rawAmt = data['depositAmount'] ?? data['amount'] ?? data['tienCoc'];
    final amount = (rawAmt is num) ? rawAmt.toDouble() : 0.0;
    final paymentMethod = (data['paymentMethod'] ?? 'Chuyển khoản QR').toString();

    // 1. Cập nhật booking document trong collection 'bookings'
    await _firestore.collection('bookings').doc(bookingId).set({
      'moveInDate': Timestamp.fromDate(newMoveInDate),
      'ngayVao': Timestamp.fromDate(newMoveInDate),
      'thoiDiem': Timestamp.fromDate(newMoveInDate),
      'checkInDate': Timestamp.fromDate(newMoveInDate),
      if (oldDate != null) 'oldMoveInDate': Timestamp.fromDate(oldDate),
      if (cleanReason != null && cleanReason.isNotEmpty) ...{
        'adjustmentReason': cleanReason,
        'changeDateReason': cleanReason,
      },
      'adjustmentStatus': 'updated_by_renter',
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    // 2. Gửi thông báo đến chủ trọ (Host) trong collection 'notifications'
    if (hostId.isNotEmpty && hostId != 'guest') {
      final hostNotifId = IdGenerator.notification();
      final reasonPart = cleanReason != null && cleanReason.isNotEmpty
          ? '\nLý do: $cleanReason'
          : '';
      final oldPart = oldDateStr.isNotEmpty ? ' (cũ: $oldDateStr)' : '';
      await _firestore.collection('notifications').doc(hostNotifId).set({
        'id': hostNotifId,
        'notificationId': hostNotifId,
        'receiverId': hostId,
        'senderId': renterId,
        'recipientRole': 'host',
        'title': 'Khách thuê dời ngày dọn vào',
        'message':
            'Khách thuê $renterName đã dời ngày dọn vào phòng "$roomTitle" sang ngày $newDateStr$oldPart.$reasonPart',
        'notificationType': 'booking_adjustment',
        'type': 'booking_adjustment',
        'bookingId': bookingId,
        'bookingCode': bookingCode,
        'roomId': roomId,
        'roomCode': roomCode,
        'roomTitle': roomTitle,
        'renterName': renterName,
        'renterAvatarUrl': renterAvatarUrl,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'adjustmentReason': cleanReason ?? '',
        if (oldDate != null) 'oldCheckInDate': Timestamp.fromDate(oldDate),
        'newCheckInDate': Timestamp.fromDate(newMoveInDate),
        'checkInDate': Timestamp.fromDate(newMoveInDate),
        'status': 'pending',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Gửi thông báo xác nhận đến người thuê (Renter) trong collection 'notification_user'
    if (renterId.isNotEmpty && renterId != 'guest') {
      final renterNotifId = IdGenerator.notification();
      final reasonPart = cleanReason != null && cleanReason.isNotEmpty
          ? ' (Lý do: $cleanReason)'
          : '';
      await _firestore
          .collection(FirestoreCollections.notificationUser)
          .doc(renterNotifId)
          .set({
            'id': renterNotifId,
            'recipientId': renterId,
            'receiverId': renterId,
            'senderId': hostId,
            'userId': renterId,
            'recipientRole': 'renter',
            'title': 'Thay đổi ngày dọn vào thành công ✓',
            'message':
                'Bạn đã dời ngày dọn vào phòng "$roomTitle" sang ngày $newDateStr thành công.$reasonPart',
            'notificationType': 'booking_adjustment',
            'type': 'booking_adjustment',
            'bookingId': bookingId,
            'bookingCode': bookingCode,
            'roomId': roomId,
            'roomCode': roomCode,
            'roomTitle': roomTitle,
            'amount': amount,
            if (oldDate != null) 'oldCheckInDate': Timestamp.fromDate(oldDate),
            'newCheckInDate': Timestamp.fromDate(newMoveInDate),
            'checkInDate': Timestamp.fromDate(newMoveInDate),
            'status': 'pending',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    }

    // 4. Ghi audit log
    await _firestore.collection('audit_logs').add({
      'action': 'Đổi ngày dọn vào',
      'actor': 'Người thuê ($renterName)',
      'bookingId': bookingId,
      'oldDate': oldDateStr,
      'newDate': newDateStr,
      'reason': cleanReason ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
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

  /// Đánh dấu bài đăng đã có người ở (không ẩn bài — chỉ đổi trạng thái).
  Future<void> markPostsOccupied(
    String roomId, {
    String? tenantName,
    String? tenantPhone,
    String? contractId,
  }) async {
    if (roomId.isEmpty) return;
    try {
      final now = DateTime.now();
      final postsRef = _firestore.collection('posts');
      final payload = <String, dynamic>{
        'status': 'occupied',
        'isAvailable': FieldValue.delete(),
        'isPinned': FieldValue.delete(),
        'statusId': FieldValue.delete(),
        'trang_thai': FieldValue.delete(),
        'hiddenReason': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(now),
        if (tenantName != null && tenantName.trim().isNotEmpty)
          'tenantName': tenantName.trim(),
        if (tenantPhone != null && tenantPhone.trim().isNotEmpty)
          'tenantPhone': tenantPhone.trim(),
        if (contractId != null && contractId.trim().isNotEmpty)
          'contractId': contractId.trim(),
      };

      Future<void> apply(DocumentReference<Map<String, dynamic>> ref) async {
        final snap = await ref.get();
        if (!snap.exists) return;
        await ref.set(payload, SetOptions(merge: true));
      }

      try {
        await apply(postsRef.doc(roomId));
      } catch (e) {
        debugPrint('Error marking post occupied directDoc $roomId: $e');
      }

      for (final field in const [
        'roomId',
        'phongId',
        'id',
        'hostRoomId',
        'phong_tro_id',
        'room_id',
      ]) {
        try {
          final snap = await postsRef.where(field, isEqualTo: roomId).get();
          for (final doc in snap.docs) {
            await apply(doc.reference);
          }
        } catch (e) {
          debugPrint('Error marking posts occupied by $field $roomId: $e');
        }
      }

      final realRoomId = await _resolveRealRoomId(roomId);
      if (realRoomId != null && realRoomId.isNotEmpty) {
        final roomPayload = <String, dynamic>{
          'isAvailable': false,
          'status': 'occupied',
          'updatedAt': Timestamp.fromDate(now),
          if (tenantName != null && tenantName.trim().isNotEmpty)
            'tenantName': tenantName.trim(),
          if (tenantPhone != null && tenantPhone.trim().isNotEmpty)
            'tenantPhone': tenantPhone.trim(),
          if (contractId != null && contractId.trim().isNotEmpty)
            'contractId': contractId.trim(),
        };
        try {
          await _firestore
              .collection('host_rooms')
              .doc(realRoomId)
              .set(roomPayload, SetOptions(merge: true));
        } catch (_) {}
      }

      debugPrint('Đã đánh dấu bài đăng phòng $roomId: đã có người ở');
    } catch (e) {
      debugPrint('Lỗi markPostsOccupied $roomId: $e');
    }
  }

  /// 5. ẨN BÀI ĐĂNG KHI CÓ YÊU CẦU ĐẶT PHÒNG ĐANG CHỜ XỬ LÝ
  Future<void> hidePostOnPendingBooking(String roomId, {String? reason}) async {
    // Giữ API cũ nhưng không ẩn bài — chỉ đổi trạng thái còn trống.
    await markPostsOccupied(roomId);
  }

  /// 6. KHÔI PHỤC BÀI ĐĂNG KHI YÊU CẦU ĐẶT PHÒNG BỊ HỦY / HẾT HẠN
  Future<void> restorePostOnCancelledBooking(
    String roomId, {
    bool syncRoomDocuments = true,
  }) async {
    if (roomId.isEmpty) return;
    try {
      final now = DateTime.now();
      final postsRef = _firestore.collection('posts');

      Future<void> restoreDoc(DocumentReference ref) async {
        await ref.set({
          'status': 'active',
          'isAvailable': FieldValue.delete(),
          'isPinned': FieldValue.delete(),
          'hiddenReason': FieldValue.delete(),
          'tenantName': FieldValue.delete(),
          'tenantPhone': FieldValue.delete(),
          'contractId': FieldValue.delete(),
          'updatedAt': Timestamp.fromDate(now),
          // Dọn sạch hoàn toàn các trường trạng thái thừa/cũ trên Firestore
          'statusId': FieldValue.delete(),
          'trang_thai': FieldValue.delete(),
          'trangThai': FieldValue.delete(),
          'trangThai_id': FieldValue.delete(),
        }, SetOptions(merge: true));
      }

      bool needsRestore(Map<String, dynamic> data) {
        final status = (data['status'] ?? data['statusId'] ?? data['trang_thai'] ?? '')
            .toString()
            .toLowerCase();
        return data['isAvailable'] == false ||
            data['hiddenReason'] != null ||
            status == 'hidden' ||
            status == 'occupied';
      }

      // 1. Khôi phục trực tiếp theo doc ID == roomId
      try {
        final directDoc = await postsRef.doc(roomId).get();
        if (directDoc.exists) {
          final data = directDoc.data() ?? {};
          if (needsRestore(data)) {
            await restoreDoc(postsRef.doc(roomId));
          }
        }
      } catch (_) {}

      // 2. Khôi phục theo trường 'roomId' == roomId
      try {
        final queryByRoomId =
            await postsRef.where('roomId', isEqualTo: roomId).get();
        for (final doc in queryByRoomId.docs) {
          if (needsRestore(doc.data())) {
            await restoreDoc(doc.reference);
          }
        }
      } catch (_) {}

      // 3. Khôi phục theo trường 'phongId' == roomId
      try {
        final queryByPhongId =
            await postsRef.where('phongId', isEqualTo: roomId).get();
        for (final doc in queryByPhongId.docs) {
          if (needsRestore(doc.data())) {
            await restoreDoc(doc.reference);
          }
        }
      } catch (_) {}

      // 4. Khôi phục theo trường 'id' == roomId
      try {
        final queryById =
            await postsRef.where('id', isEqualTo: roomId).get();
        for (final doc in queryById.docs) {
          if (needsRestore(doc.data())) {
            await restoreDoc(doc.reference);
          }
        }
      } catch (_) {}

      // 5. Luồng hủy booking vẫn đồng bộ phòng như cũ. Checkout tắt bước này
      // để không tạo lại trường isAvailable legacy trên room documents.
      if (syncRoomDocuments) {
        final realRoomId = await _resolveRealRoomId(roomId);
        if (realRoomId != null && realRoomId.isNotEmpty) {
          try {
            await _firestore.collection('host_rooms').doc(realRoomId).set({
              'status': 'available',
              'isAvailable': true,
              'bookingStatus': 'available',
              'tenantName': '',
              'tenantPhone': '',
              'tenantAvatar': '',
              'contractId': '',
              'contractStart': null,
              'contractEnd': null,
              'reservedBookingId': FieldValue.delete(),
              'isHolding': false,
              'holdingBookingId': FieldValue.delete(),
              'holdingRenterId': FieldValue.delete(),
              'holdingExpiresAt': FieldValue.delete(),
              'updatedAt': Timestamp.fromDate(now),
            }, SetOptions(merge: true));
          } catch (_) {}

        }
      }

      // Khôi phục thêm theo hostRoomId nếu roomId là mã phòng thật.
      try {
        final byHostRoom = await postsRef
            .where('hostRoomId', isEqualTo: roomId)
            .get();
        for (final doc in byHostRoom.docs) {
          if (needsRestore(doc.data())) {
            await restoreDoc(doc.reference);
          }
        }
      } catch (_) {}

      debugPrint('Đã khôi phục bài đăng thành công cho phòng: $roomId');
    } catch (e) {
      debugPrint('Lỗi khi restorePostOnCancelledBooking $roomId: $e');
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

  /// Trích xuất tiêu đề phòng thật (live title) từ host_rooms/posts,
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

    // 2. Nếu không có trong host_rooms, roomId có thể là ID bài đăng.
    for (final collection in ['posts']) {
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
    final checkedOutRoomAt = <String, DateTime>{};
    final residentRoomForBooking = <String, String>{};
    final residentService = ResidentService(_firestore);
    final bookingRawById = <String, Map<String, dynamic>>{
      for (final doc in bookingSnap.docs) doc.id: doc.data(),
    };

    for (final doc in residentSnap.docs) {
      try {
        final r = ResidentModel.fromFirestore(doc);
        if (r.userId != renterId) continue;
        final roomId = r.roomId.trim();
        final rawDocId = doc.id.trim();

        // Thu thập các candidate ID liên kết từ periodId và resident doc id
        final candidateBookingIds = <String>{};
        if (r.periodId.isNotEmpty) {
          candidateBookingIds.add(r.periodId);
          if (r.periodId.startsWith('checkin_')) {
            candidateBookingIds.add(r.periodId.substring('checkin_'.length));
          }
        }
        if (rawDocId.isNotEmpty) {
          candidateBookingIds.add(rawDocId);
          if (rawDocId.startsWith('checkin_')) {
            candidateBookingIds.add(rawDocId.substring('checkin_'.length));
          }
          if (rawDocId.contains('_${r.userId}')) {
            candidateBookingIds.add(rawDocId.replaceAll('_${r.userId}', ''));
            if (rawDocId.startsWith('checkin_')) {
              candidateBookingIds.add(rawDocId.substring('checkin_'.length).replaceAll('_${r.userId}', ''));
            }
          }
        }

        for (final cid in candidateBookingIds) {
          if (roomId.isNotEmpty && cid.isNotEmpty) {
            residentRoomForBooking[cid] = roomId;
          }
        }

        if (ResidentService.isActive(r)) {
          if (roomId.isNotEmpty) {
            activeResidentRooms.add(roomId);
            try {
              activeResidentRooms.add(await residentService.resolveRoomId(roomId));
            } catch (_) {}
          }
          activeResidentBookingIds.addAll(candidateBookingIds);
        } else {
          // Resident đã rời phòng (status == 'moved_out' || statusId == 'daRoi' || isMovedOut)
          final moveOutAt = r.moveOutDate ?? r.moveInDate;
          void rememberCheckoutRoom(String id) {
            if (id.isEmpty) return;
            checkedOutRooms.add(id);
            final prev = checkedOutRoomAt[id];
            if (prev == null || moveOutAt.isAfter(prev)) {
              checkedOutRoomAt[id] = moveOutAt;
            }
          }

          if (roomId.isNotEmpty) {
            rememberCheckoutRoom(roomId);
            try {
              final canonical = await residentService.resolveRoomId(roomId);
              rememberCheckoutRoom(canonical);
            } catch (_) {}
          }
          checkedOutBookingIds.addAll(candidateBookingIds);
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

      final statusLower = booking.status.toLowerCase().trim();
      final isPendingLike = const {
        'pending',
        'pending_payment',
        'pending_confirmation',
        'choduyet',
        'cho_duyet',
        'choxacnhan',
        'dangxuly',
      }.contains(statusLower);

      // Chỉ gắn checkout theo đúng bookingId (không fuzzy, không đè đơn mới cùng phòng).
      final matchedByBookingId = checkedOutBookingIds.contains(booking.id);
      final roomCheckoutAt =
          checkedOutRoomAt[canonicalRoomId] ?? checkedOutRoomAt[roomId];
      final createdAfterRoomCheckout = roomCheckoutAt != null &&
          !booking.createdAt.isBefore(roomCheckoutAt);
      final matchedByPriorStay = !isPendingLike &&
          !matchedByBookingId &&
          !createdAfterRoomCheckout &&
          (booking.isApproved || booking.isActive) &&
          (checkedOutRooms.contains(roomId) ||
              checkedOutRooms.contains(canonicalRoomId)) &&
          !activeResidentRooms.contains(roomId) &&
          !activeResidentRooms.contains(canonicalRoomId);

      var isExplicitlyCheckedOut = matchedByBookingId || matchedByPriorStay;

      // Hồi phục đơn mới bị ghi nhầm status=checked_out vì checkout phòng cũ.
      // Không bao giờ tự nâng lên approved chỉ vì isPaid — phải có approvedAt (admin duyệt).
      final raw = bookingRawById[booking.id] ?? const <String, dynamic>{};
      final hasCheckoutRecord =
          (raw['checkoutRecordId'] ?? '').toString().trim().isNotEmpty;
      final hasAdminApproval = raw['approvedAt'] != null && raw['isPaid'] == true;
      final awaitingAdminConfirm = raw['confirmationDeadline'] != null ||
          raw['confirmedAt'] != null;
      final falselyCheckedOut = booking.isCheckedOut &&
          !matchedByBookingId &&
          !hasCheckoutRecord &&
          (createdAfterRoomCheckout ||
              isPendingLike ||
              awaitingAdminConfirm ||
              raw['expiresAt'] != null ||
              raw['deadline'] != null);
      if (falselyCheckedOut) {
        final String restoredStatus;
        if (hasAdminApproval) {
          restoredStatus = 'approved';
        } else if (awaitingAdminConfirm) {
          restoredStatus = 'pending_confirmation';
        } else if (raw['expiresAt'] != null || raw['deadline'] != null) {
          restoredStatus = 'pending_payment';
        } else {
          restoredStatus = 'pending';
        }
        booking = booking.copyWith(
          status: restoredStatus,
          isPaid: hasAdminApproval,
          note: booking.note == 'Đã hoàn tất trả phòng' ? '' : booking.note,
        );
        unawaited(_firestore.collection('bookings').doc(booking.id).set({
          'status': restoredStatus,
          if (!hasAdminApproval) 'isPaid': false,
          'subTag': FieldValue.delete(),
          'description': FieldValue.delete(),
          'trangThai': FieldValue.delete(),
          'checkoutAt': FieldValue.delete(),
          'checkoutRecordId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
        isExplicitlyCheckedOut = false;
      }

      // Đơn khách đã bấm CK nhưng bị nâng nhầm lên approved/paid trước khi admin duyệt.
      final prematurelyApproved = !isExplicitlyCheckedOut &&
          booking.isApproved &&
          !hasAdminApproval &&
          awaitingAdminConfirm &&
          raw['isPaid'] != true;
      if (prematurelyApproved) {
        booking = booking.copyWith(
          status: 'pending_confirmation',
          isPaid: false,
          approvedAt: null,
        );
        unawaited(_firestore.collection('bookings').doc(booking.id).set({
          'status': 'pending_confirmation',
          'isPaid': false,
          'approvedAt': FieldValue.delete(),
          'subTag': FieldValue.delete(),
          'description': 'Chờ xác nhận',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
      }

      final isActiveInResident = !isExplicitlyCheckedOut &&
          (activeResidentBookingIds.contains(booking.id) ||
              (!isPendingLike &&
                  (booking.isApproved || booking.isActive) &&
                  (activeResidentRooms.contains(roomId) ||
                      (canonicalRoomId.isNotEmpty &&
                          activeResidentRooms.contains(canonicalRoomId)))));

      if (isActiveInResident) {
        // Cư dân đã check-in trong bảng residents -> đơn thuê chuyển sang 'dangO' (Đang ở)
        booking = booking.copyWith(
          status: 'dangO',
        );
        if (roomId.isNotEmpty) activeRoomsCovered.add(roomId);
        if (canonicalRoomId.isNotEmpty) activeRoomsCovered.add(canonicalRoomId);
      } else if (isExplicitlyCheckedOut && !booking.isCheckedOut && !booking.isCancelled) {
        // Chỉ đánh dấu trả phòng cho đúng đơn đã ở / đã duyệt trước checkout.
        booking = booking.copyWith(
          status: 'checked_out',
          note: booking.note.isNotEmpty ? booking.note : 'Đã hoàn tất trả phòng',
        );

        if (matchedByBookingId) {
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
      final checkedOutBookingIds = <String>{};
      final checkedOutRoomAt = <String, DateTime>{};
      final activeResidentRoomIds = <String>{};
      for (final r in residents) {
        final roomId = r.roomId.trim();
        if (ResidentService.isActive(r)) {
          if (roomId.isNotEmpty) activeResidentRoomIds.add(roomId);
          continue;
        }
        final moveOutAt = r.moveOutDate ?? r.moveInDate;
        if (roomId.isNotEmpty) {
          final prev = checkedOutRoomAt[roomId];
          if (prev == null || moveOutAt.isAfter(prev)) {
            checkedOutRoomAt[roomId] = moveOutAt;
          }
        }
        if (r.periodId.isNotEmpty) {
          checkedOutBookingIds.add(r.periodId);
          if (r.periodId.startsWith('checkin_')) {
            checkedOutBookingIds.add(r.periodId.substring('checkin_'.length));
          }
        }
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_bookingOwnerId(data) != renterId) continue;
        final booking = BookingRequestModel.fromFirestore(doc);
        final bRoom = booking.roomId.trim();
        final matchedByBookingId = checkedOutBookingIds.contains(booking.id);
        final roomCheckoutAt = checkedOutRoomAt[bRoom];
        final createdAfterRoomCheckout = roomCheckoutAt != null &&
            !booking.createdAt.isBefore(roomCheckoutAt);
        final isCheckedOut = matchedByBookingId ||
            (booking.isCheckedOut &&
                (data['checkoutRecordId'] ?? '').toString().trim().isNotEmpty) ||
            ((booking.isApproved || booking.isActive) &&
                roomCheckoutAt != null &&
                !createdAfterRoomCheckout &&
                !activeResidentRoomIds.contains(bRoom));

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
