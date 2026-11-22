import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_audit_identity.dart';

/// Duyệt / từ chối bài đăng và gửi thông báo cho chủ trọ.
/// Dữ liệu được đọc từ chính document trong collection `posts`.
class PostReviewService {
  PostReviewService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> approve(String postId, {String performer = 'Admin'}) {
    return _review(postId, approved: true, performer: performer);
  }

  static Future<void> reject(
    String postId, {
    required String reason,
    String penaltyType = 'reject_only',
    String performer = 'Admin',
  }) {
    return _review(
      postId,
      approved: false,
      reason: reason,
      penaltyType: penaltyType,
      performer: performer,
    );
  }

  static Future<void> _review(
    String postId, {
    required bool approved,
    String? reason,
    String penaltyType = 'reject_only',
    required String performer,
  }) async {
    final actorFields = await AdminAuditIdentity.currentActorFields();
    final actorName = (actorFields['performer'] ?? performer).toString();
    final postRef = _db.collection('posts').doc(postId);
    final snap = await postRef.get();
    if (!snap.exists) {
      throw Exception('Bài đăng không tồn tại');
    }

    // ===== Lấy dữ liệu từ bảng posts =====
    final data = snap.data() ?? {};
    final currentStatus =
        (data['status'] ?? data['statusId'] ?? data['status_id'] ?? 'pending')
            .toString()
            .trim()
            .toLowerCase();
    final isRejected = const {
      'rejected',
      'reject',
      'denied',
      'tuchoi',
      'tu choi',
      'từ chối',
      'đã từ chối',
      'da tu choi',
      'da_tu_choi',
      'hidden',
      'da an',
      'đã ẩn',
    }.contains(currentStatus);
    DateTime? parseTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    }

    final reviewedAt = parseTime(data['reviewedAt']);
    final updatedAt = parseTime(data['updatedAt']);
    final isResubmitted =
        data['hostResubmittedAt'] != null ||
        data['resubmittedAt'] != null ||
        (reviewedAt != null &&
            updatedAt != null &&
            updatedAt.difference(reviewedAt).inSeconds > 2);
    if (approved && isRejected && !isResubmitted) {
      throw StateError('Chủ trọ cần chỉnh sửa và gửi lại bài trước khi duyệt.');
    }
    var hostId =
        (data['hostId'] ??
                data['chuNhaId'] ??
                data['chu_tro_id'] ??
                data['host_id'] ??
                data['landlordId'] ??
                data['userId'] ??
                data['ownerId'] ??
                '')
            .toString()
            .trim();
    final hostName = (data['hostName'] ?? data['landlordName'] ?? 'Chủ trọ')
        .toString();
    final title = (data['title'] ?? 'Bài đăng').toString();
    final roomId = (data['roomId'] ?? data['phongId'] ?? '').toString().trim();
    if (hostId.isEmpty && roomId.isNotEmpty) {
      for (final col in ['host_rooms', 'rooms']) {
        final roomSnap = await _db.collection(col).doc(roomId).get();
        if (roomSnap.exists) {
          final rData = roomSnap.data() ?? {};
          hostId = (rData['hostId'] ?? rData['chuNhaId'] ?? '')
              .toString()
              .trim();
          if (hostId.isNotEmpty) break;
        }
      }
    }
    final roomCode = (data['roomCode'] ?? data['maPhong'] ?? roomId).toString();
    final code =
        '#TD-${postId.substring(0, postId.length > 5 ? 5 : postId.length).toUpperCase()}';

    final cleanReason = (reason ?? '').trim().isEmpty
        ? 'Bài đăng chưa đạt yêu cầu kiểm duyệt.'
        : reason!.trim();

    final now = DateTime.now();
    final batch = _db.batch();
    final shouldRecordWarning =
        !approved &&
        penaltyType == 'warning' &&
        hostId.isNotEmpty &&
        (!isRejected || isResubmitted);

    if (shouldRecordWarning) {
      final hostRef = _db.collection('users').doc(hostId);
      final hostSnap = await hostRef.get();
      final hostData = hostSnap.data() ?? {};
      final rawScore =
          hostData['reputationScore'] ?? hostData['diemUyTin'] ?? 100;
      final currentScore = rawScore is num
          ? rawScore.toInt()
          : int.tryParse(rawScore.toString()) ?? 100;
      if (hostSnap.exists) {
        batch.update(hostRef, {
          'reputationScore': (currentScore - 1).clamp(0, 100),
          if (hostData.containsKey('diemUyTin'))
            'diemUyTin': FieldValue.delete(),
        });
      }
    }

    // 1) Cập nhật bài đăng (chủ trọ đọc được các field này ngay trên post)
    batch.update(postRef, {
      'status': approved ? 'active' : 'rejected',
      if (!approved) 'hostResubmittedAt': FieldValue.delete(),
      'rejectReason': approved ? FieldValue.delete() : cleanReason,
      'reviewedBy': actorName,
      'reviewedById': actorFields['actorUid'],
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) Thông báo cho chủ trọ
    if (hostId.isNotEmpty) {
      batch.set(_db.collection('notifications').doc(), {
        'userId': hostId,
        'hostId': hostId,
        'hostName': hostName,
        'type': approved ? 'post_approved' : 'post_rejected',
        'title': approved ? 'Bài đăng đã được duyệt' : 'Bài đăng bị từ chối',
        'body': approved
            ? 'Bài đăng "$title" đã được phê duyệt và đang hiển thị.'
            : 'Bài đăng "$title" bị từ chối. Lý do: $cleanReason',
        'postId': postId,
        'postTitle': title,
        'roomId': roomId,
        'roomCode': roomCode,
        'reason': approved ? null : cleanReason,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3) Nhật ký kiểm toán
    batch.set(_db.collection('audit_logs').doc(), {
      ...actorFields,
      'title': approved ? 'Duyệt Tin Đăng $code' : 'Từ Chối Bài Đăng $code',
      'subtitle': approved
          ? 'Phê duyệt hiển thị phòng: $title'
          : 'Từ chối bài đăng: $title ($cleanReason)',
      'category': 'post',
      'code': code,
      'timeStr': DateFormat('HH:mm:ss').format(now),
      'dateGroup': 'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
