import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_collections.dart';
import '../utils/host_report_policy.dart';
import '../utils/id_generator.dart';
import 'image_storage_service.dart';

class HostReportException implements Exception {
  final String message;
  const HostReportException(this.message);

  @override
  String toString() => message;
}

class HostReportService {
  HostReportService({
    FirebaseFirestore? firestore,
    ImageStorageService? images,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _images = images ?? ImageStorageService();

  final FirebaseFirestore _firestore;
  final ImageStorageService _images;

  Future<String> submitHostReport({
    required String hostId,
    required String hostName,
    String hostPhone = '',
    String hostAvatar = '',
    String roomId = '',
    String roomTitle = '',
    double roomPrice = 0,
    String roomAddress = '',
    List<String> roomImages = const [],
    required String reporterId,
    required String reporterName,
    String reporterPhone = '',
    required List<String> selectedReasons,
    String otherText = '',
    List<String> evidencePaths = const [],
  }) async {
    final cleanHostId = hostId.trim();
    final cleanReporterId = reporterId.trim();
    final reasons = selectedReasons.map((reason) => reason.trim()).where((reason) => reason.isNotEmpty).toList();
    final cleanOther = otherText.trim();

    final error = HostReportPolicy.validate(
      reporterId: cleanReporterId,
      hostId: cleanHostId,
      selectedReasons: reasons,
      otherText: cleanOther,
      evidenceCount: evidencePaths.length,
    );
    if (error != null) throw HostReportException(error);

    final cleanReason = HostReportPolicy.joinedReason(reasons, cleanOther);

    final reportId = IdGenerator.hostReport();
    final evidenceUrls = <String>[];
    for (var i = 0; i < evidencePaths.length; i++) {
      final url = await _images.uploadSingleImage(
        filePath: evidencePaths[i],
        folder: 'host_reports/$reportId',
        fileName: '$i.jpg',
        sampleIndex: i,
      );
      if (url.isNotEmpty) evidenceUrls.add(url);
    }
    final notifId = IdGenerator.notification();
    final logId = IdGenerator.auditLog();
    final hostLabel = hostName.trim().isEmpty ? 'chủ trọ' : hostName.trim();
    final reporterLabel =
        reporterName.trim().isEmpty ? 'Người thuê' : reporterName.trim();

    final cleanRoomId = roomId.trim();
    final cleanRoomTitle = roomTitle.trim();
    final hasRoom = cleanRoomId.isNotEmpty || cleanRoomTitle.isNotEmpty;

    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(FirestoreCollections.reports).doc(reportId),
        {
          HostReportFields.id: reportId,
          HostReportFields.targetType: hasRoom ? 'room_post' : HostReportPolicy.targetHost,
          HostReportFields.hostId: cleanHostId,
          HostReportFields.hostName: hostLabel,
          HostReportFields.hostPhone: hostPhone.trim(),
          HostReportFields.roomId: cleanRoomId,
          HostReportFields.roomTitle: cleanRoomTitle,
          HostReportFields.reporterId: cleanReporterId,
          HostReportFields.reporterName: reporterLabel,
          HostReportFields.reason: cleanReason,
          HostReportFields.reasons: reasons,
          HostReportFields.detail: cleanOther,
          HostReportFields.evidenceUrls: evidenceUrls,
          HostReportFields.status: HostReportPolicy.pendingStatus,
          HostReportFields.createdAt: FieldValue.serverTimestamp(),

          // Compatibility fields for Admin & User management
          'reportedUserId': cleanHostId,
          'reportedUserName': hostLabel,
          'reportedPhone': hostPhone.trim(),
          'reportedAvatar': hostAvatar.trim(),
          'targetUserId': cleanHostId,
          'targetUserName': hostLabel,
          'reporterPhone': reporterPhone.trim(),

          'postId': cleanRoomId,
          'postTitle': cleanRoomTitle,
          'roomPrice': roomPrice,
          'roomAddress': roomAddress.trim(),
          'roomImages': roomImages,
        },
      );

      // Đồng bộ vào collection repost/reposts để admin xem ở tab Duyệt Repost
      if (hasRoom) {
        final repostMap = {
          'id': reportId,
          'reportId': reportId,
          'postId': cleanRoomId,
          'roomId': cleanRoomId,
          'title': cleanRoomTitle.isNotEmpty ? cleanRoomTitle : 'Bài đăng phòng trọ',
          'price': roomPrice,
          'address': roomAddress.trim(),
          'images': roomImages,
          'userId': cleanHostId,
          'hostId': cleanHostId,
          'userName': hostLabel,
          'hostName': hostLabel,
          'userPhone': hostPhone.trim(),
          'reporterId': cleanReporterId,
          'reporterName': reporterLabel,
          'reason': cleanReason,
          'rejectReason': cleanReason,
          'userNote': cleanOther,
          'status': 'pending',
          'isReport': true,
          'createdAt': FieldValue.serverTimestamp(),
          'repostedAt': FieldValue.serverTimestamp(),
        };
        batch.set(
          _firestore.collection('reposts').doc(reportId),
          repostMap,
        );
        batch.set(
          _firestore.collection('repost').doc(reportId),
          repostMap,
        );
      }

      batch.set(
        _firestore.collection(FirestoreCollections.notifications).doc(notifId),
        {
          'id': notifId,
          'recipientRole': 'admin',
          'notificationType': 'report',
          'title': hasRoom ? 'Báo cáo bài đăng phòng trọ' : 'Báo cáo chủ trọ',
          'message': hasRoom
              ? '$reporterLabel báo cáo bài đăng "$cleanRoomTitle" của $hostLabel: $cleanReason'
              : '$reporterLabel báo cáo $hostLabel: $cleanReason',
          'targetId': reportId,
          'hostId': cleanHostId,
          'reporterId': cleanReporterId,
          'roomId': cleanRoomId,
          'roomTitle': cleanRoomTitle,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        _firestore.collection('audit_logs').doc(logId),
        {
          'id': logId,
          'action': hasRoom
              ? 'Người thuê báo cáo bài đăng phòng trọ'
              : 'Người thuê báo cáo chủ trọ',
          'actor': reporterLabel,
          'category': 'baoCao',
          'details': hasRoom
              ? '$reporterLabel gửi báo cáo bài đăng "$cleanRoomTitle" ($cleanRoomId) của $hostLabel. Lý do: $cleanReason'
              : '$reporterLabel gửi báo cáo $reportId về $hostLabel. Lý do: $cleanReason',
          'target': 'Báo cáo $reportId',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      return reportId;
    } on HostReportException {
      rethrow;
    } catch (error) {
      debugPrint('Gửi báo cáo chủ trọ lỗi: $error');
      throw const HostReportException(
        'Gửi báo cáo thất bại. Vui lòng thử lại.',
      );
    }
  }
}

final hostReportServiceProvider = Provider<HostReportService>(
  (ref) => HostReportService(images: ref.watch(imageStorageServiceProvider)),
);
