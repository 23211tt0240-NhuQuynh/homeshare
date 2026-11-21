import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/notification_write_utils.dart';
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

  CollectionReference<Map<String, dynamic>>? get _userNotificationsCol =>
      _firestore?.collection(FirestoreCollections.notificationUser);

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
    final disbursements = <HostNotificationModel>[];
    for (final item in items) {
      // Giữ thẻ "Admin đã giải ngân" riêng, không gộp theo booking.
      if (item.isDisbursementNotification) {
        disbursements.add(item);
        continue;
      }
      if (item.isRoommateApproval ||
          item.newRoommateId.isNotEmpty ||
          item.isRoomIssue) {
        continue;
      }
      final key = item.bookingId.trim().isNotEmpty
          ? 'booking:${item.bookingId.trim()}'
          : item.roomId.trim().isNotEmpty
          ? 'room:${item.roomId.trim()}'
          : 'notification:${item.id}';
      // Danh sách đã sắp xếp mới nhất trước nên giữ bản ghi đầu tiên.
      unique.putIfAbsent(key, () => item);
    }
    final merged = [...disbursements, ...unique.values];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
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
      final recipientRole =
          (data['recipientRole'] ?? '').toString().trim().toLowerCase();
      if (recipientRole == 'admin') {
        continue;
      }

      final bId =
          (data[NotificationFields.bookingId] ??
                  data['bookingId'] ??
                  data['donDatPhongId'] ??
                  '')
              .toString()
              .trim();

      final actionType = (data['actionType'] ?? data['type'] ?? data['notificationType'] ?? '').toString();
      final lowerActionType = actionType.toLowerCase();
      final lowerTitle = (data[NotificationFields.title] ?? data['title'] ?? '')
          .toString()
          .toLowerCase();
      final isCccd = lowerActionType.startsWith('cccd') ||
          lowerTitle.contains('cccd');

      final isRoomIssue = !isCccd &&
          (actionType == 'room_issue' ||
              data['issueId'] != null && data['issueId'].toString().isNotEmpty ||
              lowerTitle.contains('sự cố'));

      final isDisbursement = !isCccd &&
          (actionType == 'disbursement' ||
              lowerTitle.contains('admin đã giải ngân'));

      if (isCccd) {
        // Thông báo xác thực CCCD luôn nằm trong tab "Đang xử lý" của Chủ trọ
        data[NotificationFields.notificationType] =
            HostNotificationType.pendingAction.code;
        if ((data['actionType'] ?? '').toString().trim().isEmpty) {
          data['actionType'] =
              lowerActionType.isNotEmpty ? lowerActionType : 'cccd_verification';
        }
      } else if (isDisbursement) {
        // Thông báo giải ngân luôn nằm ở tab "Đã thanh toán".
        data[NotificationFields.notificationType] =
            HostNotificationType.paymentCompleted.code;
        data['actionType'] = 'disbursement';
      } else if (isRoomIssue) {
        // Sự cố phòng luôn được phân loại vào tab "Đang xử lý" (pendingAction) để chủ trọ tiếp nhận và giải quyết
        final issueStatus = (data['statusId'] ?? data['status'] ?? 'pending').toString().toLowerCase();
        if (issueStatus == 'resolved' || issueStatus == 'completed' || issueStatus == 'dakhacphuc') {
          data[NotificationFields.notificationType] = HostNotificationType.staying.code;
        } else {
          data[NotificationFields.notificationType] = HostNotificationType.pendingAction.code;
        }
      } else if (bId.isNotEmpty && bookingDataMap.containsKey(bId)) {
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

  /// Bổ sung thông báo giải ngân từ collection `disbursements` nếu chưa có
  /// (đơn admin đã giải ngân trước khi app ghi notification).
  Future<List<HostNotificationModel>> _mergeDisbursementNotifications(
    String hostId,
    List<HostNotificationModel> current,
  ) async {
    final db = _firestore;
    if (db == null || hostId.isEmpty) return current;

    try {
      final snap = await db
          .collection('disbursements')
          .where('hostId', isEqualTo: hostId)
          .limit(40)
          .get();
      if (snap.docs.isEmpty) return current;

      final existingIds = current.map((item) => item.id).toSet();
      final moneyFmt = NumberFormat('#,###', 'vi_VN');
      final extras = <HostNotificationModel>[];

      for (final doc in snap.docs) {
        final notifId = 'disbursement_${doc.id}';
        if (existingIds.contains(notifId)) continue;

        final data = doc.data();
        final net = (data['netAmount'] ?? data['totalAmount'] ?? 0) is num
            ? ((data['netAmount'] ?? data['totalAmount']) as num).toDouble()
            : double.tryParse('${data['netAmount'] ?? data['totalAmount']}') ??
                0;
        final itemCount = (data['itemCount'] as num?)?.toInt() ??
            ((data['bookingIds'] as List?)?.length ?? 1);
        final hostName = '${data['hostName'] ?? 'chủ trọ'}'.trim();
        final orderLabel = itemCount <= 1 ? '1 đơn' : '$itemCount đơn';
        final moneyText = moneyFmt.format(net.round());
        final createdAt = data['disbursedAt'] is Timestamp
            ? (data['disbursedAt'] as Timestamp).toDate()
            : data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();
        final bookingIds = (data['bookingIds'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];

        final payload = <String, dynamic>{
          NotificationFields.notificationId: notifId,
          NotificationFields.receiverId: hostId,
          NotificationFields.senderId: 'admin',
          NotificationFields.notificationType:
              HostNotificationType.paymentCompleted.code,
          'actionType': 'disbursement',
          NotificationFields.title: 'Admin đã giải ngân',
          NotificationFields.message:
              'Admin đã giải ngân $moneyText đ cho $hostName ($orderLabel).',
          NotificationFields.amount: net,
          NotificationFields.statusId: 'completed',
          NotificationFields.isRead: false,
          NotificationFields.createdAt: Timestamp.fromDate(createdAt),
          'disbursementId': doc.id,
          if (data['receiptCode'] != null) 'receiptCode': data['receiptCode'],
          if (bookingIds.isNotEmpty) 'bookingIds': bookingIds,
          if (bookingIds.isNotEmpty)
            NotificationFields.bookingId: bookingIds.first,
        };

        // Ghi một lần để lần sau stream đọc trực tiếp từ notifications.
        _notificationsCol
            ?.doc(notifId)
            .set(payload, SetOptions(merge: true))
            .catchError((_) {});

        extras.add(HostNotificationModel.fromMap(payload, notifId));
      }

      if (extras.isEmpty) return current;
      final merged = [...extras, ...current];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    } catch (error) {
      debugPrint('Không đồng bộ được thông báo giải ngân: $error');
      return current;
    }
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
            var filtered = all.where((item) => item.type == type).toList();
            if (type == HostNotificationType.paymentCompleted) {
              filtered =
                  await _mergeDisbursementNotifications(hostId, filtered);
            }
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
        await docRef.update(notificationReadUpdate());
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
        batch.update(doc.reference, notificationReadUpdate());
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
    String? renterId,
  }) async {
    final fs = _firestore;
    final bCol = _bookingsCol;
    final nCol = _notificationsCol;
    if (fs == null || bCol == null || nCol == null) return;
    final batch = fs.batch();

    // 1. Cập nhật booking gốc
    String effectiveRenterId = (renterId ?? '').trim();
    String effectiveHostId = (hostId ?? '').trim();
    String currentRoomCode = '';
    dynamic oldCheckInDate;
    String oldRoomTitle = '';
    String oldRoomId = '';
    double depositAmount = 0.0;
    String hostName = '';
    String renterName = '';

    if (bookingId.isNotEmpty) {
      final bookingRef = bCol.doc(bookingId);
      try {
        final bDoc = await bookingRef.get();
        if (bDoc.exists && bDoc.data() != null) {
          final bData = bDoc.data()!;
          final rId = bData['userId'] ??
              bData['renterId'] ??
              bData['nguoiDungId'] ??
              bData['nguoiDung_Id'] ??
              bData['nguoiThueId'] ??
              bData['khachXemId'];
          if (rId != null && rId.toString().isNotEmpty) {
            effectiveRenterId = rId.toString();
          }

          final hId = bData['hostId'] ?? bData['chuNhaId'];
          if (effectiveHostId.isEmpty && hId != null && hId.toString().isNotEmpty) {
            effectiveHostId = hId.toString();
          }

          currentRoomCode =
              (bData['roomCode'] ?? bData['maPhong'] ?? '').toString();
          oldCheckInDate = bData['checkInDate'] ??
              bData['ngayNhanPhong'] ??
              bData['ngayVao'] ??
              bData['ngayDonVao'] ??
              bData['expectedCheckInDate'] ??
              bData['moveInDate'] ??
              bData['checkIn'];
          oldRoomTitle =
              (bData['roomTitle'] ?? bData['tieuDePhong'] ?? '').toString();
          oldRoomId = (bData['roomId'] ?? bData['phongId'] ?? '').toString();
          final rawAmt = bData['paymentAmount'] ??
              bData['depositAmount'] ??
              bData['tienCoc'] ??
              bData['amount'];
          if (rawAmt is num) {
            depositAmount = rawAmt.toDouble();
          }
          hostName =
              (bData['hostName'] ?? bData['tenChuNha'] ?? '').toString();
          renterName =
              (bData['renterName'] ?? bData['tenNguoiO'] ?? bData['tenKhach'] ?? '').toString();
        }
      } catch (_) {}

      batch.set(bookingRef, {
        'newRoomId': newRoomId,
        'newRoomTitle': newRoomTitle,
        'newCheckInDate': Timestamp.fromDate(newCheckInDate),
        'proposedCheckInDate': Timestamp.fromDate(newCheckInDate),
        'adjustmentReason': adjustmentReason,
        'adjustmentStatus': 'pending',
        'status': 'choXacNhanThayDoi',
        'statusId': FieldValue.delete(),
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
        'adjustmentStatus': 'pending',
        'status': 'deposit',
        'statusId': FieldValue.delete(),
        NotificationFields.oldCheckInDate: ?oldCheckInDate,
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Gửi thông báo đến chuông người thuê (Renter) để người thuê có thể Đồng ý hoặc Từ chối (Lưu vào notification_user)
    if (effectiveRenterId.isNotEmpty) {
      final dateStr = DateFormat('dd/MM/yyyy').format(newCheckInDate);
      final uCol = _userNotificationsCol ??
          fs.collection(FirestoreCollections.notificationUser);
      final renterNotifRef = uCol.doc();
      batch.set(renterNotifRef, {
        'id': renterNotifRef.id,
        'receiverId': effectiveRenterId,
        'recipientId': effectiveRenterId,
        'userId': effectiveRenterId,
        'recipientRole': 'renter',
        'title': 'Chủ trọ yêu cầu đổi lịch dọn vào',
        'message':
            'Chủ trọ đề xuất chuyển ngày nhận phòng sang $dateStr.${adjustmentReason.isNotEmpty ? " Lý do: $adjustmentReason" : ""}',
        'notificationType': 'booking_adjustment',
        'type': 'booking_adjustment',
        'bookingId': bookingId,
        'hostNotificationId': notificationId,
        'roomId': newRoomId.isNotEmpty ? newRoomId : oldRoomId,
        'roomTitle': newRoomTitle.isNotEmpty ? newRoomTitle : oldRoomTitle,
        'newRoomId': newRoomId,
        'newRoomTitle': newRoomTitle,
        'oldRoomId': oldRoomId,
        'oldRoomTitle': oldRoomTitle,
        'roomCode': currentRoomCode,
        'checkInDate': ?oldCheckInDate,
        'oldCheckInDate': ?oldCheckInDate,
        'newCheckInDate': Timestamp.fromDate(newCheckInDate),
        'amount': depositAmount,
        'renterName': renterName,
        'hostName': hostName,
        'hostId': effectiveHostId,
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
          'statusId': FieldValue.delete(),
          'adminVerified': true,
          'adminVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (notificationId.isNotEmpty) {
        batch.set(_notificationsCol!.doc(notificationId), {
          NotificationFields.notificationType: targetType.code,
          'status': targetStatus,
          NotificationFields.statusId: FieldValue.delete(),
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
        'statusId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (notificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(notificationId), {
        NotificationFields.notificationType: HostNotificationType.deposit.code,
        'status': 'deposited',
        NotificationFields.statusId: FieldValue.delete(),
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
        'status': 'approved',
        'statusId': FieldValue.delete(),
        'nguoiNhanId': FieldValue.delete(),
        'nguoiGuiId': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'phongId': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        ...notificationReadUpdate(),
      }, SetOptions(merge: true));
    }

    // 3. Cập nhật thông báo lời mời của người được mời thành accepted (notification_user)
    if (userNotificationId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      batch.set(uCol.doc(userNotificationId), {
        'status': 'accepted',
        'statusId': FieldValue.delete(),
        'nguoiNhanId': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        ...notificationReadUpdate(),
      }, SetOptions(merge: true));
    }

    // 4. Gửi thông báo đến chuông của người ở ghép mới (notification_user)
    if (newRoommateId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      final notifNew = uCol.doc();
      batch.set(notifNew, {
        'id': notifNew.id,
        'receiverId': newRoommateId,
        'recipientId': newRoommateId,
        'userId': newRoommateId,
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

    // 5. Gửi thông báo đến chuông của người thuê chính (notification_user)
    if (primaryTenantId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      final notifPrimary = uCol.doc();
      batch.set(notifPrimary, {
        'id': notifPrimary.id,
        'receiverId': primaryTenantId,
        'recipientId': primaryTenantId,
        'userId': primaryTenantId,
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
        'status': 'rejected',
        'statusId': FieldValue.delete(),
        'nguoiNhanId': FieldValue.delete(),
        'nguoiGuiId': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'phongId': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        ...notificationReadUpdate(),
      }, SetOptions(merge: true));
    }

    // 2. Cập nhật thông báo lời mời của người được mời thành host_rejected (notification_user)
    if (userNotificationId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      batch.set(uCol.doc(userNotificationId), {
        'status': 'host_rejected',
        'statusId': FieldValue.delete(),
        'nguoiNhanId': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'ngayTao': FieldValue.delete(),
        ...notificationReadUpdate(),
      }, SetOptions(merge: true));
    }

    // 3. Gửi thông báo đến chuông người ở ghép (notification_user)
    if (newRoommateId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      final notifNew = uCol.doc();
      batch.set(notifNew, {
        'id': notifNew.id,
        'receiverId': newRoommateId,
        'recipientId': newRoommateId,
        'userId': newRoommateId,
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

    // 4. Gửi thông báo đến chuông người thuê chính (notification_user)
    if (primaryTenantId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      final notifPrimary = uCol.doc();
      batch.set(notifPrimary, {
        'id': notifPrimary.id,
        'receiverId': primaryTenantId,
        'recipientId': primaryTenantId,
        'userId': primaryTenantId,
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
    DateTime? newCheckInDate,
    String? newRoomId,
    String? newRoomTitle,
    String? hostNotificationId,
  }) async {
    if (_firestore == null ||
        _bookingsCol == null ||
        _notificationsCol == null) {
      return;
    }
    final batch = _firestore!.batch();

    String hostId = '';
    String renterName = '';
    String renterId = '';
    String roomCode = '';
    String oldRoomId = '';
    String oldRoomTitle = '';
    double depositAmount = 0.0;
    DateTime? oldCheckInDate;

    // 1. Lấy dữ liệu và cập nhật booking gốc
    if (bookingId.isNotEmpty) {
      try {
        final bDoc = await _bookingsCol!.doc(bookingId).get();
        if (bDoc.exists && bDoc.data() != null) {
          final bData = bDoc.data()!;
          hostId = (bData['hostId'] ?? bData['chuNhaId'] ?? '').toString();
          renterId = (bData['renterId'] ?? bData['nguoiDungId'] ?? bData['userId'] ?? '').toString();
          renterName = (bData['renterName'] ??
                  bData['userName'] ??
                  bData['nguoiThueTen'] ??
                  '')
              .toString();
          roomCode = (bData['roomCode'] ?? bData['maPhong'] ?? '').toString();
          oldRoomId = (bData['roomId'] ?? bData['phongId'] ?? '').toString();
          oldRoomTitle = (bData['roomTitle'] ?? bData['tieuDePhong'] ?? '').toString();
          final rawAmt = bData['depositAmount'] ?? bData['paymentAmount'] ?? bData['tienCoc'] ?? bData['amount'];
          if (rawAmt is num) depositAmount = rawAmt.toDouble();
          final oldDateTs = bData['checkInDate'] ?? bData['ngayVao'] ?? bData['ngayNhanPhong'];
          if (oldDateTs is Timestamp) oldCheckInDate = oldDateTs.toDate();

          if (newCheckInDate == null) {
            final ts = bData['newCheckInDate'];
            if (ts is Timestamp) newCheckInDate = ts.toDate();
          }
          if (newRoomId == null || newRoomId.isEmpty) {
            newRoomId = (bData['newRoomId'] ?? '').toString();
          }
          if (newRoomTitle == null || newRoomTitle.isEmpty) {
            newRoomTitle = (bData['newRoomTitle'] ?? '').toString();
          }
        }
      } catch (_) {}

      final bookingUpdates = <String, dynamic>{
        'status': 'daCoc',
        'statusId': FieldValue.delete(),
        'subTag': 'Đã cọc',
        'adjustmentStatus': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newCheckInDate != null) {
        bookingUpdates['checkInDate'] = Timestamp.fromDate(newCheckInDate);
        bookingUpdates['ngayNhanPhong'] = Timestamp.fromDate(newCheckInDate);
      }
      if (newRoomId != null && newRoomId.isNotEmpty) {
        bookingUpdates['roomId'] = newRoomId;
        bookingUpdates['phongId'] = newRoomId;
      }
      if (newRoomTitle != null && newRoomTitle.isNotEmpty) {
        bookingUpdates['roomTitle'] = newRoomTitle;
        bookingUpdates['tieuDePhong'] = newRoomTitle;
      }

      batch.set(
        _bookingsCol!.doc(bookingId),
        bookingUpdates,
        SetOptions(merge: true),
      );
    }

    // 2. Cập nhật thông báo của Người thuê (trong notification_user và notifications cũ)
    if (notificationId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      batch.set(uCol.doc(notificationId), {
        'status': 'accepted',
        'statusId': FieldValue.delete(),
        ...notificationReadUpdate(),
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_notificationsCol!.doc(notificationId), {
        'status': 'accepted',
        'statusId': FieldValue.delete(),
        ...notificationReadUpdate(),
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Cập nhật thông báo gốc của Chủ trọ
    if (hostNotificationId != null && hostNotificationId.isNotEmpty) {
      final hostUpdates = <String, dynamic>{
        'status': 'approved',
        'statusId': FieldValue.delete(),
        'adjustmentStatus': 'accepted',
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      };
      if (newCheckInDate != null) {
        hostUpdates['checkInDate'] = Timestamp.fromDate(newCheckInDate);
      }
      if (newRoomId != null && newRoomId.isNotEmpty) {
        hostUpdates['roomId'] = newRoomId;
      }
      if (newRoomTitle != null && newRoomTitle.isNotEmpty) {
        hostUpdates['roomTitle'] = newRoomTitle;
      }
      batch.set(
        _notificationsCol!.doc(hostNotificationId),
        hostUpdates,
        SetOptions(merge: true),
      );
    }

    // 4. Gửi thông báo đến chuông của Chủ trọ về việc khách đã đồng ý
    if (hostId.isNotEmpty) {
      final hostNotifRef = _notificationsCol!.doc();
      final dateStr = newCheckInDate != null
          ? DateFormat('dd/MM/yyyy').format(newCheckInDate)
          : '';
      final finalRoomId = (newRoomId != null && newRoomId.isNotEmpty) ? newRoomId : oldRoomId;
      final finalRoomTitle = (newRoomTitle != null && newRoomTitle.isNotEmpty) ? newRoomTitle : oldRoomTitle;

      batch.set(hostNotifRef, {
        'id': hostNotifRef.id,
        'notificationId': hostNotifRef.id,
        'receiverId': hostId,
        'recipientId': hostId,
        'recipientRole': 'host',
        'senderId': renterId,
        'renterId': renterId,
        'renterName': renterName,
        'title': 'Khách thuê đã đồng ý đổi lịch dọn vào! 🎉',
        'message':
            'Khách thuê ${renterName.isNotEmpty ? renterName : ''} đã đồng ý với ngày nhận phòng mới ${dateStr.isNotEmpty ? "($dateStr)" : ""}. Đơn đặt phòng ${bookingId.isNotEmpty ? bookingId : ""} đã sẵn sàng chờ nhận phòng.',
        'notificationType': 'deposit',
        'type': 'deposit',
        'status': 'approved',
        'bookingId': bookingId,
        if (finalRoomId.isNotEmpty) 'roomId': finalRoomId,
        if (finalRoomTitle.isNotEmpty) 'roomTitle': finalRoomTitle,
        if (roomCode.isNotEmpty) 'roomCode': roomCode,
        'amount': depositAmount,
        if (oldCheckInDate != null) 'oldCheckInDate': Timestamp.fromDate(oldCheckInDate),
        if (newCheckInDate != null) 'newCheckInDate': Timestamp.fromDate(newCheckInDate),
        if (newCheckInDate != null)
          'checkInDate': Timestamp.fromDate(newCheckInDate)
        else if (oldCheckInDate != null)
          'checkInDate': Timestamp.fromDate(oldCheckInDate),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Từ chối thay đổi đặt chỗ
  Future<void> rejectBookingChange({
    required String bookingId,
    required String notificationId,
    String? hostNotificationId,
  }) async {
    if (_firestore == null ||
        _bookingsCol == null ||
        _notificationsCol == null) {
      return;
    }
    final batch = _firestore!.batch();

    String hostId = '';
    String renterName = '';
    String renterId = '';
    String roomCode = '';
    String roomId = '';
    String roomTitle = '';
    double depositAmount = 0.0;
    DateTime? checkInDate;

    // 1. Lấy thông tin từ booking và cập nhật adjustmentStatus: 'rejected'
    if (bookingId.isNotEmpty) {
      try {
        final bDoc = await _bookingsCol!.doc(bookingId).get();
        if (bDoc.exists && bDoc.data() != null) {
          final bData = bDoc.data()!;
          hostId = (bData['hostId'] ?? bData['chuNhaId'] ?? '').toString();
          renterId = (bData['renterId'] ?? bData['nguoiDungId'] ?? bData['userId'] ?? '').toString();
          renterName = (bData['renterName'] ??
                  bData['userName'] ??
                  bData['nguoiThueTen'] ??
                  '')
              .toString();
          roomCode = (bData['roomCode'] ?? bData['maPhong'] ?? '').toString();
          roomId = (bData['roomId'] ?? bData['phongId'] ?? '').toString();
          roomTitle = (bData['roomTitle'] ?? bData['tieuDePhong'] ?? '').toString();
          final rawAmt = bData['depositAmount'] ?? bData['paymentAmount'] ?? bData['tienCoc'] ?? bData['amount'];
          if (rawAmt is num) depositAmount = rawAmt.toDouble();
          final dateTs = bData['checkInDate'] ?? bData['ngayVao'] ?? bData['ngayNhanPhong'];
          if (dateTs is Timestamp) checkInDate = dateTs.toDate();
        }
      } catch (_) {}

      batch.set(_bookingsCol!.doc(bookingId), {
        'adjustmentStatus': 'rejected',
        'status': 'daCoc',
        'statusId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 2. Cập nhật thông báo của Người thuê (trong notification_user và notifications cũ)
    if (notificationId.isNotEmpty) {
      final uCol = _userNotificationsCol ??
          _firestore!.collection(FirestoreCollections.notificationUser);
      batch.set(uCol.doc(notificationId), {
        'status': 'rejected',
        'statusId': FieldValue.delete(),
        ...notificationReadUpdate(),
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_notificationsCol!.doc(notificationId), {
        'status': 'rejected',
        'statusId': FieldValue.delete(),
        ...notificationReadUpdate(),
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Cập nhật thông báo gốc của Chủ trọ
    if (hostNotificationId != null && hostNotificationId.isNotEmpty) {
      batch.set(_notificationsCol!.doc(hostNotificationId), {
        'status': 'approved',
        NotificationFields.statusId: FieldValue.delete(),
        'adjustmentStatus': 'rejected',
        NotificationFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 4. Gửi thông báo đến chuông của Chủ trọ về việc khách từ chối
    if (hostId.isNotEmpty) {
      final hostNotifRef = _notificationsCol!.doc();
      batch.set(hostNotifRef, {
        'id': hostNotifRef.id,
        'notificationId': hostNotifRef.id,
        'receiverId': hostId,
        'recipientId': hostId,
        'recipientRole': 'host',
        'senderId': renterId,
        'renterId': renterId,
        'renterName': renterName,
        'title': 'Khách thuê từ chối thay đổi ngày dọn vào',
        'message':
            'Khách thuê ${renterName.isNotEmpty ? renterName : ''} đã từ chối yêu cầu đổi lịch dọn vào hoặc đổi phòng. Lịch dọn vào ban đầu vẫn được giữ nguyên.',
        'notificationType': 'deposit',
        'type': 'deposit',
        'status': 'approved',
        'bookingId': bookingId,
        if (roomId.isNotEmpty) 'roomId': roomId,
        if (roomTitle.isNotEmpty) 'roomTitle': roomTitle,
        if (roomCode.isNotEmpty) 'roomCode': roomCode,
        'amount': depositAmount,
        if (checkInDate != null) 'checkInDate': Timestamp.fromDate(checkInDate),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Xóa một thông báo khỏi Firestore
  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty || _notificationsCol == null) return;
    try {
      await _notificationsCol!.doc(notificationId).delete();
    } catch (e) {
      debugPrint('Lỗi khi xóa notification $notificationId: $e');
    }
  }

  /// Xóa hàng loạt thông báo lỗi/mồ côi khỏi Firestore
  Future<void> deleteNotificationsBatch(List<String> notificationIds) async {
    if (notificationIds.isEmpty || _notificationsCol == null || _firestore == null) return;
    try {
      final batch = _firestore!.batch();
      for (final id in notificationIds) {
        batch.delete(_notificationsCol!.doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Lỗi khi xóa batch notifications: $e');
    }
  }
}
