import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_collections.dart';
import '../utils/host_post_report_policy.dart';
import '../utils/id_generator.dart';

class HostPostReportException implements Exception {
  final String message;
  const HostPostReportException(this.message);

  @override
  String toString() => message;
}

class HostPostReportService {
  HostPostReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> submitPostReport({
    required String postId,
    required String postTitle,
    required String hostId,
    required String hostName,
    String roomId = '',
    required String reporterId,
    required String reporterName,
    required List<String> selectedReasons,
    String otherText = '',
  }) async {
    final cleanPostId = postId.trim();
    final cleanHostId = hostId.trim();
    final cleanReporterId = reporterId.trim();
    final reasons = selectedReasons
        .map((reason) => reason.trim())
        .where((reason) => reason.isNotEmpty)
        .toList();
    final cleanOther = otherText.trim();

    final error = HostPostReportPolicy.validate(
      reporterId: cleanReporterId,
      hostId: cleanHostId,
      postId: cleanPostId,
      selectedReasons: reasons,
      otherText: cleanOther,
    );
    if (error != null) throw HostPostReportException(error);

    final cleanReason = HostPostReportPolicy.joinedReason(reasons, cleanOther);
    final reportId = IdGenerator.postReport();
    final notifId = IdGenerator.notification();
    final logId = IdGenerator.auditLog();
    final postLabel = postTitle.trim().isEmpty ? 'bài đăng' : postTitle.trim();
    final hostLabel = hostName.trim().isEmpty ? 'chủ trọ' : hostName.trim();
    final reporterLabel =
        reporterName.trim().isEmpty ? 'Người dùng' : reporterName.trim();

    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(FirestoreCollections.reports).doc(reportId),
        {
          HostReportFields.id: reportId,
          HostReportFields.targetType: HostPostReportPolicy.targetPost,
          HostReportFields.postId: cleanPostId,
          HostReportFields.postTitle: postLabel,
          HostReportFields.hostId: cleanHostId,
          HostReportFields.hostName: hostLabel,
          HostReportFields.roomId: roomId.trim().isEmpty ? cleanPostId : roomId.trim(),
          HostReportFields.roomTitle: postLabel,
          HostReportFields.reporterId: cleanReporterId,
          HostReportFields.reporterName: reporterLabel,
          HostReportFields.reason: cleanReason,
          HostReportFields.reasons: reasons,
          HostReportFields.detail: cleanOther,
          HostReportFields.status: HostPostReportPolicy.pendingStatus,
          HostReportFields.createdAt: FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        _firestore.collection(FirestoreCollections.notifications).doc(notifId),
        {
          'id': notifId,
          'recipientRole': 'admin',
          'notificationType': 'report',
          'title': 'Báo cáo bài đăng',
          'message': '$reporterLabel báo cáo bài "$postLabel": $cleanReason',
          'targetId': reportId,
          'postId': cleanPostId,
          'hostId': cleanHostId,
          'reporterId': cleanReporterId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        _firestore.collection('audit_logs').doc(logId),
        {
          'id': logId,
          'action': 'Người dùng báo cáo bài đăng chủ trọ',
          'actor': reporterLabel,
          'category': 'baoCao',
          'details':
              '$reporterLabel gửi báo cáo $reportId về bài $postLabel. Lý do: $cleanReason',
          'target': 'Báo cáo $reportId',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      return reportId;
    } on HostPostReportException {
      rethrow;
    } catch (error) {
      debugPrint('Gửi báo cáo bài đăng lỗi: $error');
      throw const HostPostReportException(
        'Gửi báo cáo thất bại. Vui lòng thử lại.',
      );
    }
  }
}

final hostPostReportServiceProvider = Provider<HostPostReportService>(
  (ref) => HostPostReportService(),
);
