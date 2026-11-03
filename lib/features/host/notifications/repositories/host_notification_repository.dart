import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../repositories/tenant_repository.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';

/// Repository quản lý toàn bộ truy vấn Firestore cho thông báo chủ trọ
/// Tuân thủ nguyên tắc: Đây là nơi duy nhất tương tác trực tiếp với Cloud Firestore.
class HostNotificationRepository {
  final FirebaseFirestore? _customFirestore;

  HostNotificationRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _notificationsCol =>
      _firestore?.collection(FirestoreCollections.notifications);

  CollectionReference<Map<String, dynamic>>? get _bookingsCol =>
      _firestore?.collection(FirestoreCollections.bookings);

  /// Hai tab thanh toán chỉ hiển thị một thẻ cho mỗi đơn/phòng.
  /// Thông báo phát sinh từ luồng người ở ghép không phải là đơn đặt cọc.
  List<HostNotificationModel> _normalizePaymentNotifications(
    List<HostNotificationModel> items,
    HostNotificationType type,
  ) {
    if (type != HostNotificationType.deposit &&
        type != HostNotificationType.paymentCompleted) {
      return items;
    }

    final unique = <String, HostNotificationModel>{};
    for (final item in items) {
      if (item.isRoommateApproval || item.newRoommateId.isNotEmpty) continue;
      final key = item.bookingId.trim().isNotEmpty
          ? 'booking:${item.bookingId.trim()}'
          : item.roomId.trim().isNotEmpty
          ? 'room:${item.roomId.trim()}'
          : 'notification:${item.id}';
      // Danh sách đã sắp xếp mới nhất trước nên giữ bản ghi đầu tiên.
      unique.putIfAbsent(key, () => item);
    }
    return unique.values.toList();
  }

  /// Đồng bộ và giải quyết trạng thái thông báo với bảng bookings để đảm bảo
  /// khi đơn đã được duyệt cọc/thanh toán, thẻ thông báo lập tức chuyển từ "Đang xử lý"
  /// sang "Đã cọc" hoặc "Đã thanh toán hết" và tự động chuẩn hóa bản ghi Firestore.
  Future<List<HostNotificationModel>> _resolveNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String hostId,
  ) async {
    final bookingIds = <String>{};
    for (final doc in snapshot.docs) {
      final bId =
          (doc.data()[NotificationFields.bookingId] ??
                  doc.data()['bookingId'] ??
                  doc.data()['donDatPhongId'] ??
                  '')
              .toString()
              .trim();
      if (bId.isNotEmpty) bookingIds.add(bId);
    }

    final Map<String, Map<String, dynamic>> bookingDataMap = {};
    if (bookingIds.isNotEmpty && _bookingsCol != null) {
      try {
        final bSnap = await _bookingsCol!
            .where('hostId', isEqualTo: hostId)
            .get();
        for (final bDoc in bSnap.docs) {
          bookingDataMap[bDoc.id] = bDoc.data();
        }
      } catch (_) {}

      // Dự phòng trường hợp bookingId chưa có trong kết quả lọc theo hostId
      final missingIds = bookingIds
          .where((id) => !bookingDataMap.containsKey(id))
          .take(15);
      for (final id in missingIds) {
        try {
          final doc = await _bookingsCol!.doc(id).get();
          if (doc.exists && doc.data() != null) {
            bookingDataMap[id] = doc.data()!;
          }
        } catch (_) {}
      }
    }

    final list = <HostNotificationModel>[];
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final bId =
          (data[NotificationFields.bookingId] ??
                  data['bookingId'] ??
                  data['donDatPhongId'] ??
                  '')
              .toString()
              .trim();

      if (bId.isNotEmpty && bookingDataMap.containsKey(bId)) {
        final bData = bookingDataMap[bId]!;
        final bStatus = (bData['status'] ?? '').toString().toLowerCase();
        final isPaid = bData['isPaid'] == true;
        final paymentOption = (bData['paymentOption'] ?? '')
            .toString()
            .toLowerCase();
        final isFull =
            paymentOption == 'full' ||
            paymentOption == 'toanbo' ||
            bData['isFullPayment'] == true ||
            bStatus == 'paid';

        if (bStatus == 'dango' ||
            bStatus == 'active' ||
            bStatus == 'danhanphong') {
          data['statusId'] = 'approved';
          data['status'] = 'dango';
          data[NotificationFields.notificationType] =
              HostNotificationType.staying.code;
        } else if (bStatus == 'approved' ||
            bStatus == 'daduyet' ||
            bStatus == 'dacoc' ||
            bStatus == 'deposit_paid' ||
            bStatus == 'paid' ||
            bStatus == 'completed' ||
            isPaid) {
          final targetType = isFull
              ? HostNotificationType.paymentCompleted
              : HostNotificationType.deposit;
          final targetStatus = isFull ? 'completed' : 'deposited';

          data['statusId'] = targetStatus;
          data['status'] = bStatus;
          data['isPaid'] = true;
          data['isFullPayment'] = isFull;
          data[NotificationFields.notificationType] = targetType.code;

          // Tự động chuẩn hóa bản ghi trên Firestore nếu còn sót 'pendingAction' hoặc 'booking'
          final curNotifType =
              (doc.data()[NotificationFields.notificationType] ??
                      doc.data()['type'] ??
                      '')
                  .toString();
          if (curNotifType == 'pendingAction' || curNotifType == 'booking') {
            doc.reference
                .set({
                  NotificationFields.notificationType: targetType.code,
                  NotificationFields.statusId: targetStatus,
                  'status': bStatus,
                  'title': isFull
                      ? 'Khách đã thanh toán đủ toàn bộ'
                      : 'Đã duyệt tiền cọc thành công',
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true))
                .catchError((_) {});
          }
        }
      }

      list.add(HostNotificationModel.fromMap(data, doc.id));
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Lắng nghe danh sách thông báo theo loại thông báo và ID chủ trọ (Realtime)
  Stream<List<HostNotificationModel>> watchByType({
    required String hostId,
    required HostNotificationType type,
  }) {
    if (hostId.isEmpty || _notificationsCol == null) {
      return Stream.value(const []);
    }

    try {
      return _notificationsCol!
          .where(NotificationFields.receiverId, isEqualTo: hostId)
          .snapshots()
          .asyncMap((snapshot) async {
            final all = await _resolveNotifications(snapshot, hostId);
            final filtered = all.where((item) => item.type == type).toList();
            return _normalizePaymentNotifications(filtered, type);
          })
          .handleError((_) {
            return <HostNotificationModel>[];
          });
    } catch (_) {
      return Stream.value(const []);
    }
  }

  /// Đếm số lượng thông báo theo từng loại (phục vụ badge trên thanh filter chip)
  Stream<Map<HostNotificationType, int>> watchCounts(String hostId) {
    Map<HostNotificationType, int> calcCounts(
      List<HostNotificationModel> items,
    ) {
      final res = <HostNotificationType, int>{
        HostNotificationType.pendingAction: 0,
        HostNotificationType.staying: 0,
        HostNotificationType.deposit: 0,
        HostNotificationType.paymentCompleted: 0,
      };
      for (final it in items) {
        res[it.type] = (res[it.type] ?? 0) + 1;
      }
      return res;
    }

    if (hostId.isEmpty || _notificationsCol == null) {
      return Stream.value(calcCounts([]));
    }

    try {
      return _notificationsCol!
          .where(NotificationFields.receiverId, isEqualTo: hostId)
          .snapshots()
          .asyncMap((snapshot) async {
            final list = await _resolveNotifications(snapshot, hostId);
            final normalized = <HostNotificationModel>[
              ...list.where(
                (item) =>
                    item.type != HostNotificationType.deposit &&
                    item.type != HostNotificationType.paymentCompleted,
              ),
              ..._normalizePaymentNotifications(
                list
                    .where((item) => item.type == HostNotificationType.deposit)
                    .toList(),
                HostNotificationType.deposit,
              ),
              ..._normalizePaymentNotifications(
                list
                    .where(
                      (item) =>
                          item.type == HostNotificationType.paymentCompleted,
                    )
                    .toList(),
                HostNotificationType.paymentCompleted,
              ),
            ];
            return calcCounts(normalized);
          })
          .handleError((_) => calcCounts([]));
    } catch (_) {
      return Stream.value(calcCounts([]));
    }
  }

  /// Đánh dấu một thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty || _notificationsCol == null) return;
    try {
      final docRef = _notificationsCol!.doc(notificationId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({
          NotificationFields.isRead: true,
          NotificationFields.legacyIsRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
          NotificationFields.legacyUpdatedAt: FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  /// Đánh dấu tất cả thông báo của chủ trọ là đã đọc
  Future<void> markAllAsRead(String hostId) async {
    if (hostId.isEmpty || _notificationsCol == null || _firestore == null) {
      return;
    }
    try {
      final query = await _notificationsCol!
          .where(NotificationFields.receiverId, isEqualTo: hostId)
          .where(NotificationFields.isRead, isEqualTo: false)
          .get();

      final batch = _firestore!.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          NotificationFields.isRead: true,
          NotificationFields.legacyIsRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Lấy số lượng thông báo chưa đọc của chủ nhà
  Stream<int> getUnreadCount(String hostId) {
    if (hostId.isEmpty || _notificationsCol == null) return Stream.value(0);
    return _notificationsCol!
        .where(NotificationFields.receiverId, isEqualTo: hostId)
        .where(NotificationFields.isRead, isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  }

  /// Cập nhật điều chỉnh cọc (Đổi phòng, đổi ngày Check-in, lý do) từ Modal Thao tác chủ nhà
  Future<void> updateDepositAdjustment({
    required String notificationId,
    required String bookingId,
    required String newRoomId,
    required String newRoomTitle,
    required DateTime newCheckInDate,
    required String adjustmentReason,
    String? hostId,
  }) async {
    final fs = _firestore;
    final bCol = _bookingsCol;
    final nCol = _notificationsCol;
    if (fs == null || bCol == null || nCol == null) return;
    final batch = fs.batch();

    // 1. Cập nhật booking gốc
    String renterId = '';
    String currentRoomCode = '';
    if (bookingId.isNotEmpty) {
      final bookingRef = bCol.doc(bookingId);
      try {
        final bDoc = await bookingRef.get();
        if (bDoc.exists && bDoc.data() != null) {
          final bData = bDoc.data()!;
          renterId =
              (bData['userId'] ??
                      bData['renterId'] ??
                      bData['nguoiThueId'] ??
                      '')
                  .toString();
          currentRoomCode = (bData['roomCode'] ?? bData['maPhong'] ?? '')
              .toString();
        }
      } catch (_) {}

      batch.set(bookingRef, {
        'newRoomId': newRoomId,
        'newRoomTitle': newRoomTitle,
        'newCheckInDate': Timestamp.fromDate(newCheckInDate),
        'adjustmentReason': adjustmentReason,
        'status': 'choXacNhanThayDoi',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 2. Cập nhật document notification của chủ trọ
    if (notificationId.isNotEmpty) {
      final notifRef = nCol.doc(notificationId);
      batch.set(notifRef, {
        NotificationFields.newRoomId: newRoomId,
        'newRoomTitle': newRoomTitle,
        NotificationFields.newCheckInDate: Timestamp.fromDate(newCheckInDate),
        NotificationFields.adjustmentReason: adjustmentReason,
        NotificationFields.statusId: 'choXacNhanThayDoi',
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Gửi thông báo đến chuông người thuê (Renter) để người thuê có thể Đồng ý hoặc Từ chối
    if (renterId.isNotEmpty) {
      final dateStr = DateFormat('dd/MM/yyyy').format(newCheckInDate);
      final renterNotifRef = nCol.doc();
      batch.set(renterNotifRef, {
        'id': renterNotifRef.id,
        'receiverId': renterId,
        'recipientRole': 'renter',
        'title': 'Chủ trọ yêu cầu đổi lịch dọn vào',
        'message':
            'Chủ trọ đề xuất chuyển ngày nhận phòng sang $dateStr.${adjustmentReason.isNotEmpty ? " Lý do: $adjustmentReason" : ""}',
        'notificationType': 'booking_adjustment',
        'type': 'booking_adjustment',
        'bookingId': bookingId,
        'hostNotificationId': notificationId,
        'roomId': newRoomId,
        'roomTitle': newRoomTitle,
        'roomCode': currentRoomCode,
        'newCheckInDate': Timestamp.fromDate(newCheckInDate),
        'adjustmentReason': adjustmentReason,
        'status': 'pending',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Admin duyệt xác nhận đã nhận tiền (cọc hoặc thanh toán hết):
  /// - Khi khách đặt phòng -> thông báo tạo ở "Đang xử lý" (Chờ xác nhận cọc).
  /// - Khách chuyển tiền cho bên Admin xác nhận.
  /// - Khi Admin duyệt đã nhận:
  ///   + Nếu duyệt cọc (isFullPayment = false): chuyển trạng thái sang "Đã cọc" (HostNotificationType.deposit).
  ///   + Nếu duyệt thanh toán đủ (isFullPayment = true): chuyển sang "Đã thanh toán hết" (HostNotificationType.paymentCompleted).
  Future<void> adminVerifyAndApprovePayment({
    required String bookingId,
    required String notificationId,
    bool isFullPayment = false,
  }) async {
    final targetType = isFullPayment
        ? HostNotificationType.paymentCompleted
        : HostNotificationType.deposit;
    final targetStatus = isFullPayment ? 'completed' : 'deposited';
    final bookingStatus = isFullPayment ? 'daThanhToanHet' : 'daCoc';

    try {
      if (_firestore == null ||
          _bookingsCol == null ||
          _notificationsCol == null) {
        return;
      }
      final batch = _firestore!.batch();
      if (bookingId.isNotEmpty) {
        batch.set(_bookingsCol!.doc(bookingId), {
          'status': bookingStatus,
          'statusId': targetStatus,
          'adminVerified': true,
          'adminVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (notificationId.isNotEmpty) {
        batch.set(_notificationsCol!.doc(notificationId), {
          NotificationFields.notificationType: targetType.code,
          NotificationFields.statusId: targetStatus,
          NotificationFields.isRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Duyệt xác nhận cọc của khách thuê
  Future<void> approveDeposit({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null ||
        _bookingsCol == null ||
        _notificationsCol == null) {
      return;
    }
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(_bookingsCol!.doc(bookingId), {
        'status': 'daCoc',
        'statusId': 'deposited',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (notificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(notificationId), {
        NotificationFields.notificationType: HostNotificationType.deposit.code,
        NotificationFields.statusId: 'deposited',
        NotificationFields.isRead: true,
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Xác nhận duyệt người ở ghép vào phòng (Từ Role Chủ Trọ)
  Future<void> approveRoommateRequest({
    required String notificationId,
    required String roomId,
    required String primaryTenantId,
    required String primaryTenantName,
    required String newRoommateId,
    required String newRoommateName,
    String roomTitle = 'Phòng trọ',
    String roomCode = '',
    String userNotificationId = '',
  }) async {
    if (_firestore == null || _notificationsCol == null) {
      throw StateError('Chưa kết nối Firebase');
    }
    if (roomId.isEmpty) {
      throw StateError('Yêu cầu ở ghép chưa liên kết với phòng');
    }

    final batch = _firestore!.batch();

    // 1. Thực hiện thêm người ở ghép vào phòng chính thức
    final tenantRepo = TenantRepository(firestore: _firestore);
    await tenantRepo.addRoommateToRoom(
      roomId: roomId,
      primaryTenantId: primaryTenantId,
      primaryTenantName: primaryTenantName,
      newRoommateId: newRoommateId,
      newRoommateName: newRoommateName,
      batch: batch,
    );

    // 2. Cập nhật thông báo của Chủ trọ thành approved và chuyển loại sang "Đang ở" (staying)
    if (notificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(notificationId), {
        NotificationFields.notificationType: HostNotificationType.staying.code,
        'legacyNotificationType': HostNotificationType.staying.code,
        'type': HostNotificationType.staying.code,
        NotificationFields.statusId: 'approved',
        'status': 'approved',
        NotificationFields.isRead: true,
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Cập nhật thông báo lời mời của người được mời thành accepted
    if (userNotificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(userNotificationId), {
        'status': 'accepted',
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 4. Gửi thông báo đến chuông của người ở ghép mới
    if (newRoommateId.isNotEmpty) {
      final notifNew = _notificationsCol!.doc();
      batch.set(notifNew, {
        'id': notifNew.id,
        'receiverId': newRoommateId,
        'recipientRole': 'renter',
        'title': 'Chủ trọ đã duyệt vào phòng! 🎉',
        'message':
            'Chủ trọ đã xác nhận duyệt bạn vào ở ghép cùng $primaryTenantName tại phòng $roomTitle ($roomCode). Chúc bạn có thời gian sinh sống vui vẻ!',
        'notificationType': 'roommate_approved',
        'roomId': roomId,
        'roomCode': roomCode,
        'status': 'approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 5. Gửi thông báo đến chuông của người thuê chính
    if (primaryTenantId.isNotEmpty) {
      final notifPrimary = _notificationsCol!.doc();
      batch.set(notifPrimary, {
        'id': notifPrimary.id,
        'receiverId': primaryTenantId,
        'recipientRole': 'renter',
        'title': 'Chủ trọ đã duyệt bạn cùng phòng! 🎉',
        'message':
            'Chủ trọ đã xác nhận cho phép $newRoommateName vào ở ghép cùng bạn tại phòng $roomTitle ($roomCode).',
        'notificationType': 'roommate_approved',
        'roomId': roomId,
        'roomCode': roomCode,
        'status': 'approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    await tenantRepo.closeFullRoommatePosts(
      roomId: roomId,
      primaryTenantId: primaryTenantId,
      newRoommateId: newRoommateId,
    );
  }

  /// Từ chối cho vào ở ghép (Từ Role Chủ Trọ)
  Future<void> rejectRoommateRequest({
    required String notificationId,
    required String primaryTenantId,
    required String primaryTenantName,
    required String newRoommateId,
    required String newRoommateName,
    String roomTitle = 'Phòng trọ',
    String roomCode = '',
    String userNotificationId = '',
    String reason =
        'Chủ trọ chưa đồng ý tiếp nhận thêm người ở ghép tại thời điểm này.',
  }) async {
    if (_firestore == null || _notificationsCol == null) return;
    final batch = _firestore!.batch();

    // 1. Cập nhật thông báo của Chủ trọ thành rejected
    if (notificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(notificationId), {
        NotificationFields.statusId: 'rejected',
        'status': 'rejected',
        NotificationFields.isRead: true,
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 2. Cập nhật thông báo lời mời của người được mời thành host_rejected
    if (userNotificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(userNotificationId), {
        'status': 'host_rejected',
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Gửi thông báo đến chuông người ở ghép
    if (newRoommateId.isNotEmpty) {
      final notifNew = _notificationsCol!.doc();
      batch.set(notifNew, {
        'id': notifNew.id,
        'receiverId': newRoommateId,
        'recipientRole': 'renter',
        'title': 'Chủ trọ đã từ chối yêu cầu vào ở ghép',
        'message':
            'Chủ trọ phòng $roomTitle ($roomCode) đã từ chối yêu cầu ở ghép: $reason',
        'notificationType': 'roommate_rejected',
        'roomId': '',
        'status': 'rejected',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. Gửi thông báo đến chuông người thuê chính
    if (primaryTenantId.isNotEmpty) {
      final notifPrimary = _notificationsCol!.doc();
      batch.set(notifPrimary, {
        'id': notifPrimary.id,
        'receiverId': primaryTenantId,
        'recipientRole': 'renter',
        'title': 'Yêu cầu ở ghép đã bị từ chối',
        'message':
            'Chủ trọ phòng $roomTitle ($roomCode) không đồng ý duyệt cho $newRoommateName vào ở ghép: $reason',
        'notificationType': 'roommate_rejected',
        'roomId': '',
        'status': 'rejected',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Xác nhận đồng ý thay đổi đặt chỗ (Màn hình Figma: Xác nhận thay đổi)
  Future<void> confirmBookingChange({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null ||
        _bookingsCol == null ||
        _notificationsCol == null) {
      return;
    }
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(_bookingsCol!.doc(bookingId), {
        'status': 'daXacNhanThayDoi',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (notificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(notificationId), {
        NotificationFields.statusId: 'approved',
        NotificationFields.isRead: true,
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Từ chối thay đổi đặt chỗ
  Future<void> rejectBookingChange({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null ||
        _bookingsCol == null ||
        _notificationsCol == null) {
      return;
    }
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(_bookingsCol!.doc(bookingId), {
        'status': 'tuChoiThayDoi',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (notificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(notificationId), {
        NotificationFields.statusId: 'rejected',
        NotificationFields.isRead: true,
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
