import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/room_issue_model.dart';
import '../constants/firestore_collections.dart';
import '../utils/id_generator.dart';
import '../utils/room_issue_policy.dart';

class RoomIssueException implements Exception {
  final String message;
  const RoomIssueException(this.message);

  @override
  String toString() => message;
}

class RoomIssueService {
  RoomIssueService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Gửi báo cáo sự cố phòng trọ đến chủ nhà và ghi nhận hệ thống
  Future<String> submitRoomIssue({
    required String bookingId,
    required String roomId,
    required String roomTitle,
    required String hostId,
    String hostName = '',
    required String reporterId,
    required String reporterName,
    required String reporterPhone,
    required String category,
    String severity = RoomIssueSeverities.medium,
    required String description,
    List<String> imageUrls = const [],
  }) async {
    final cleanBookingId = bookingId.trim();
    final cleanRoomId = roomId.trim();
    final cleanRoomTitle = roomTitle.trim().isEmpty ? 'Phòng trọ' : roomTitle.trim();
    var cleanHostId = hostId.trim();
    var cleanHostName = hostName.trim();
    var cleanReporterId = reporterId.trim();
    final cleanReporterName = reporterName.trim().isEmpty ? 'Người thuê' : reporterName.trim();
    final cleanReporterPhone = reporterPhone.trim();
    final cleanCategory = category.trim();
    final cleanSeverity = severity.trim().isEmpty ? RoomIssueSeverities.medium : severity.trim();
    final cleanDescription = description.trim();

    // Tự động phân giải hostId nếu bị khuyết từ nguồn booking
    if (cleanHostId.isEmpty && cleanRoomId.isNotEmpty) {
      try {
        final hrDoc = await _firestore.collection('host_rooms').doc(cleanRoomId).get();
        if (hrDoc.exists) {
          cleanHostId = (hrDoc.data()?['hostId'] ?? hrDoc.data()?['chuNhaId'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    if (cleanHostId.isEmpty && cleanBookingId.isNotEmpty) {
      try {
        final bDoc = await _firestore.collection('bookings').doc(cleanBookingId).get();
        if (bDoc.exists) {
          cleanHostId = (bDoc.data()?['hostId'] ?? bDoc.data()?['chuNhaId'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    if (cleanHostName.isEmpty && cleanHostId.isNotEmpty) {
      try {
        final uDoc = await _firestore.collection('users').doc(cleanHostId).get();
        if (uDoc.exists) {
          cleanHostName = (uDoc.data()?['displayName'] ?? uDoc.data()?['fullName'] ?? uDoc.data()?['hoTen'] ?? '').toString().trim();
        }
      } catch (_) {}
    }

    // 1. Kiểm tra tính hợp lệ nghiệp vụ
    final validationError = RoomIssuePolicy.validate(
      category: cleanCategory,
      description: cleanDescription,
      reporterPhone: cleanReporterPhone,
    );
    if (validationError != null) {
      throw RoomIssueException(validationError);
    }

    final reportId = IdGenerator.roomIssue();
    final hostNotifId = IdGenerator.notification();
    final userNotifId = 'NF_ISSUE_${DateTime.now().millisecondsSinceEpoch}';
    final logId = IdGenerator.auditLog();

    final issue = RoomIssueModel(
      id: reportId,
      bookingId: cleanBookingId,
      roomId: cleanRoomId,
      roomTitle: cleanRoomTitle,
      hostId: cleanHostId,
      hostName: cleanHostName,
      reporterId: cleanReporterId,
      reporterName: cleanReporterName,
      reporterPhone: cleanReporterPhone,
      category: cleanCategory,
      severity: cleanSeverity,
      description: cleanDescription,
      imageUrls: imageUrls,
      status: RoomIssueStatuses.pending,
      createdAt: DateTime.now(),
    );

    try {
      final batch = _firestore.batch();

      // a. Lưu vào collection `reports`
      batch.set(
        _firestore.collection(FirestoreCollections.reports).doc(reportId),
        issue.toFirestore(),
      );

      // b. Bắn thông báo cho Chủ trọ (collection `notifications`) - hiển thị tại Tab "Đang xử lý" (pendingAction)
      final bookingCode = cleanBookingId.length > 8 ? cleanBookingId.substring(0, 8).toUpperCase() : cleanBookingId.toUpperCase();
      batch.set(
        _firestore.collection(FirestoreCollections.notifications).doc(hostNotifId),
        {
          'id': hostNotifId,
          NotificationFields.receiverId: cleanHostId,
          'recipientId': cleanHostId,
          'hostId': cleanHostId,
          'chuNhaId': cleanHostId,
          NotificationFields.senderId: cleanReporterId,
          'recipientRole': 'host',
          NotificationFields.notificationType: 'pendingAction',
          'type': 'room_issue',
          'actionType': 'room_issue',
          NotificationFields.title: 'Báo cáo sự cố: $cleanCategory ($cleanRoomTitle)',
          NotificationFields.message: cleanDescription,
          'details': RoomIssuePolicy.formatHostMessage(
            reporterName: cleanReporterName,
            reporterPhone: cleanReporterPhone,
            category: cleanCategory,
            severity: cleanSeverity,
            description: cleanDescription,
          ),
          NotificationFields.roomId: cleanRoomId,
          NotificationFields.roomTitle: cleanRoomTitle,
          NotificationFields.bookingId: cleanBookingId,
          NotificationFields.bookingCode: bookingCode,
          NotificationFields.renterName: cleanReporterName,
          'reporterName': cleanReporterName,
          'reporterPhone': cleanReporterPhone,
          'issueId': reportId,
          'category': cleanCategory,
          'severity': cleanSeverity,
          'imageUrls': imageUrls,
          NotificationFields.statusId: 'pending',
          'status': 'pending',
          NotificationFields.isRead: false,
          NotificationFields.createdAt: FieldValue.serverTimestamp(),
        },
      );

      // c. Bắn thông báo xác nhận cho Khách thuê (collection `notification_user`)
      batch.set(
        _firestore.collection(FirestoreCollections.notificationUser).doc(userNotifId),
        {
          'id': userNotifId,
          'recipientId': cleanReporterId,
          'userId': cleanReporterId,
          'recipientRole': 'renter',
          'notificationType': 'room_issue',
          'type': 'room_issue',
          'title': 'Đã gửi báo cáo sự cố phòng: $cleanRoomTitle',
          'message': RoomIssuePolicy.formatTenantMessage(
            category: cleanCategory,
            hostName: cleanHostName,
          ),
          'roomId': cleanRoomId,
          'bookingId': cleanBookingId,
          'issueId': reportId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      // d. Ghi nhật ký kiểm toán hệ thống (`audit_logs`)
      batch.set(
        _firestore.collection('audit_logs').doc(logId),
        {
          'id': logId,
          'action': 'Khách thuê báo cáo sự cố phòng',
          'actor': cleanReporterName,
          'category': 'suCo',
          'details': '$cleanReporterName ($cleanReporterPhone) gửi báo cáo $reportId phòng $cleanRoomTitle. Sự cố: $cleanCategory ($cleanSeverity)',
          'target': 'Sự cố $reportId',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      return reportId;
    } on RoomIssueException {
      rethrow;
    } catch (e) {
      debugPrint('Lỗi khi gửi báo cáo sự cố phòng: $e');
      throw RoomIssueException('Gửi báo cáo sự cố thất bại: $e');
    }
  }

  /// Lắng nghe danh sách sự cố đã báo theo mã đơn đặt phòng (Realtime stream)
  Stream<List<RoomIssueModel>> streamIssuesForBooking(String bookingId) {
    if (bookingId.trim().isEmpty) return Stream.value(const []);
    return _firestore
        .collection(FirestoreCollections.reports)
        .where('targetType', isEqualTo: 'room_issue')
        .where('bookingId', isEqualTo: bookingId.trim())
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => RoomIssueModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Lắng nghe danh sách sự cố do người thuê gửi (Realtime stream)
  Stream<List<RoomIssueModel>> streamIssuesForRenter(String renterId) {
    if (renterId.trim().isEmpty) return Stream.value(const []);
    return _firestore
        .collection(FirestoreCollections.reports)
        .where('targetType', isEqualTo: 'room_issue')
        .where('reporterId', isEqualTo: renterId.trim())
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => RoomIssueModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Hủy báo cáo sự cố khi sự cố đã tự hết hoặc báo nhầm
  Future<void> cancelRoomIssue({
    required String issueId,
    String reason = 'Khách thuê hủy yêu cầu',
  }) async {
    try {
      await _firestore.collection(FirestoreCollections.reports).doc(issueId).update({
        'status': RoomIssueStatuses.cancelled,
        'cancelReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Lỗi khi hủy báo cáo sự cố: $e');
      throw RoomIssueException('Không thể hủy báo cáo: $e');
    }
  }

  /// Chủ trọ xác nhận đã tiếp nhận và xử lý xong sự cố phòng trọ
  Future<void> resolveRoomIssue({
    required String issueId,
    String hostNotes = '',
    String? hostNotificationId,
  }) async {
    try {
      final batch = _firestore.batch();
      final cleanIssueId = issueId.trim();

      // 1. Cập nhật trạng thái sự cố trong collection `reports`
      final reportRef = _firestore.collection(FirestoreCollections.reports).doc(cleanIssueId);
      final reportSnap = await reportRef.get();
      final reportData = reportSnap.data() ?? {};
      final roomTitle = (reportData['roomTitle'] ?? 'Phòng trọ').toString();
      final category = (reportData['category'] ?? 'Sự cố').toString();
      final reporterId = (reportData['reporterId'] ?? '').toString();

      batch.set(reportRef, {
        'status': RoomIssueStatuses.resolved,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (hostNotes.isNotEmpty) 'hostNotes': hostNotes.trim(),
      }, SetOptions(merge: true));

      // 2. Cập nhật thông báo của Chủ trọ sang trạng thái đã xử lý
      if (hostNotificationId != null && hostNotificationId.isNotEmpty) {
        batch.set(_firestore.collection(FirestoreCollections.notifications).doc(hostNotificationId), {
          NotificationFields.statusId: 'resolved',
          'status': 'resolved',
          'hostNotes': hostNotes.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final notifSnap = await _firestore
            .collection(FirestoreCollections.notifications)
            .where('issueId', isEqualTo: cleanIssueId)
            .get();
        for (final doc in notifSnap.docs) {
          batch.set(doc.reference, {
            NotificationFields.statusId: 'resolved',
            'status': 'resolved',
            'hostNotes': hostNotes.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // 3. Gửi thông báo cho Người thuê biết chủ trọ đã khắc phục xong
      if (reporterId.isNotEmpty) {
        final tenantNotifId = 'NF_ISSUE_RESOLVED_${DateTime.now().millisecondsSinceEpoch}';
        batch.set(_firestore.collection(FirestoreCollections.notificationUser).doc(tenantNotifId), {
          'id': tenantNotifId,
          'recipientId': reporterId,
          'userId': reporterId,
          'recipientRole': 'renter',
          'notificationType': 'room_issue_resolved',
          'type': 'room_issue',
          'title': 'Chủ trọ đã khắc phục xong sự cố: $category',
          'message': hostNotes.isNotEmpty
              ? 'Sự cố [$category] tại $roomTitle đã được chủ trọ xử lý xong: "$hostNotes"'
              : 'Sự cố [$category] tại $roomTitle đã được chủ trọ khắc phục xong.',
          'roomId': reportData['roomId'] ?? '',
          'bookingId': reportData['bookingId'] ?? '',
          'issueId': cleanIssueId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Lỗi khi cập nhật trạng thái sự cố: $e');
      throw RoomIssueException('Không thể cập nhật trạng thái sự cố: $e');
    }
  }
}

final roomIssueServiceProvider = Provider<RoomIssueService>((ref) {
  return RoomIssueService();
});

final bookingIssuesStreamProvider =
    StreamProvider.family<List<RoomIssueModel>, String>((ref, bookingId) {
  final service = ref.watch(roomIssueServiceProvider);
  return service.streamIssuesForBooking(bookingId);
});

