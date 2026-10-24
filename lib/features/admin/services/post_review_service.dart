import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    final postRef = _db.collection('posts').doc(postId);
    final snap = await postRef.get();
    if (!snap.exists) {
      throw Exception('Bài đăng không tồn tại');
    }

    // ===== Lấy dữ liệu từ bảng posts =====
    final data = snap.data() ?? {};
    final currentStatus = (data['status'] ?? 'pending').toString().toLowerCase();
    if (approved &&
        (currentStatus == 'rejected' || currentStatus == 'tuchoi') &&
        data['hostResubmittedAt'] == null) {
      throw StateError('Chủ trọ cần chỉnh sửa và gửi lại bài trước khi duyệt.');
    }
    final hostId =
        (data['hostId'] ?? data['landlordId'] ?? data['userId'] ?? '')
            .toString();
    final hostName = (data['hostName'] ?? data['landlordName'] ?? 'Chủ trọ')
        .toString();
    final title = (data['title'] ?? 'Bài đăng').toString();
    final roomId = (data['roomId'] ?? '').toString();
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
        (data['status'] ?? '').toString().toLowerCase() != 'rejected';

    if (shouldRecordWarning) {
      final hostRef = _db.collection('users').doc(hostId);
      final hostSnap = await hostRef.get();
      final hostData = hostSnap.data() ?? {};
      final currentScore = (hostData['diemUyTin'] ?? 100) as num;
      if (hostSnap.exists) {
        batch.update(hostRef, {
          'diemUyTin': (currentScore.toInt() - 1).clamp(0, 100),
        });
      }
    }

    // 1) Cập nhật bài đăng (chủ trọ đọc được các field này ngay trên post)
    batch.update(postRef, {
      'status': approved ? 'active' : 'rejected',
      if (!approved) 'hostResubmittedAt': FieldValue.delete(),
      'rejectReason': approved ? FieldValue.delete() : cleanReason,
      'reviewedBy': performer,
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
      'title': approved ? 'Duyệt Tin Đăng $code' : 'Từ Chối Bài Đăng $code',
      'subtitle': approved
          ? 'Phê duyệt hiển thị phòng: $title'
          : 'Từ chối bài đăng: $title ($cleanReason)',
      'category': 'post',
      'performer': performer,
      'code': code,
      'timeStr': DateFormat('HH:mm:ss').format(now),
      'dateGroup': 'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
