import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/room_model.dart';
import '../../auth/services/role_resolver.dart';
import 'roommate_invitation_policy.dart';

enum RoommateInvitationBlockReason {
  none,
  invalidUser,
  roleNotAllowed,
  noActiveRoom,
  lookupFailed,
}

class RoommateInvitationEligibility {
  final String? senderRole;
  final String? receiverRole;
  final RoomModel? activeRoom;
  final RoommateInvitationBlockReason blockReason;

  const RoommateInvitationEligibility({
    required this.senderRole,
    required this.receiverRole,
    required this.activeRoom,
    required this.blockReason,
  });

  bool get canInvite =>
      blockReason == RoommateInvitationBlockReason.none &&
      RoommateInvitationPolicy.canInvite(
        senderRole: senderRole,
        receiverRole: receiverRole,
        hasActiveRoom: activeRoom != null,
      );
}

/// Phân giải quyền gửi lời mời từ dữ liệu Firebase thật.
///
/// Không dùng `pinnedRoom`, dữ liệu mẫu hay giá trị mặc định để cấp quyền.
/// Phòng hợp lệ phải đến từ booking đã duyệt/đang ở hoặc bản ghi cư dân đang ở
/// của chính người gửi.
class RoommateInvitationEligibilityService {
  final FirebaseFirestore? _injectedFirestore;

  RoommateInvitationEligibilityService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  Future<RoommateInvitationEligibility> resolve({
    required String senderId,
    required String receiverId,
  }) async {
    final cleanSenderId = senderId.trim();
    final cleanReceiverId = receiverId.trim();
    if (cleanSenderId.isEmpty ||
        cleanReceiverId.isEmpty ||
        cleanSenderId == cleanReceiverId) {
      return const RoommateInvitationEligibility(
        senderRole: null,
        receiverRole: null,
        activeRoom: null,
        blockReason: RoommateInvitationBlockReason.invalidUser,
      );
    }

    try {
      final userDocs = await Future.wait([
        _firestore.collection('users').doc(cleanSenderId).get(),
        _firestore.collection('users').doc(cleanReceiverId).get(),
      ]);
      final senderRole = RoleResolver.extractRoleFromMap(userDocs[0].data());
      final receiverRole = RoleResolver.extractRoleFromMap(userDocs[1].data());

      if (!RoommateInvitationPolicy.canInvite(
        senderRole: senderRole,
        receiverRole: receiverRole,
        hasActiveRoom: true,
      )) {
        return RoommateInvitationEligibility(
          senderRole: senderRole,
          receiverRole: receiverRole,
          activeRoom: null,
          blockReason: RoommateInvitationBlockReason.roleNotAllowed,
        );
      }

      final activeRoom = await _findActiveRoom(cleanSenderId);
      return RoommateInvitationEligibility(
        senderRole: senderRole,
        receiverRole: receiverRole,
        activeRoom: activeRoom,
        blockReason: activeRoom == null
            ? RoommateInvitationBlockReason.noActiveRoom
            : RoommateInvitationBlockReason.none,
      );
    } catch (_) {
      return const RoommateInvitationEligibility(
        senderRole: null,
        receiverRole: null,
        activeRoom: null,
        blockReason: RoommateInvitationBlockReason.lookupFailed,
      );
    }
  }

  Future<RoomModel?> _findActiveRoom(String userId) async {
    final bookingDocs = await _queryAliases(
      collection: 'bookings',
      fields: const [
        'userId',
        'renterId',
        'nguoiDungId',
        'nguoiDung_Id',
        'khachXemId',
      ],
      value: userId,
    );

    for (final doc in bookingDocs) {
      final data = doc.data();
      final status =
          data['status'] ?? data['trangThai'] ?? data['trangThai_id'];
      if (!RoommateInvitationPolicy.isActiveBookingStatus(status)) continue;

      final roomId = _firstNonEmpty(data, const [
        'roomId',
        'phongId',
        'phongTroId',
        'baiDangId',
      ]);
      final room = await _loadRoom(roomId);
      if (room != null) return room;
    }

    final residentDocs = await _queryAliases(
      collection: 'residents',
      fields: const ['userId', 'nguoiDungId', 'nguoi_dung_id'],
      value: userId,
    );

    for (final doc in residentDocs) {
      final data = doc.data();
      final status =
          data['statusId'] ??
          data['status'] ??
          data['trangThai_id'] ??
          data['trang_thai'];
      if (!RoommateInvitationPolicy.isActiveResidentStatus(status)) continue;

      var roomId = _firstNonEmpty(data, const [
        'roomId',
        'phongId',
        'phongTroId',
        'phong_tro_id',
      ]);
      if (roomId.isEmpty) {
        roomId = await _roomIdFromActivePeriod(
          _firstNonEmpty(data, const ['periodId', 'kyThue_id', 'kyOId']),
        );
      }
      final room = await _loadRoom(roomId);
      if (room != null) return room;
    }

    return null;
  }

  Future<String> _roomIdFromActivePeriod(String periodId) async {
    if (periodId.isEmpty) return '';
    final doc = await _firestore.collection('periods').doc(periodId).get();
    final data = doc.data();
    if (data == null) return '';
    final status = data['status'] ?? data['trangThai'];
    if (!RoommateInvitationPolicy.isActiveResidentStatus(status)) return '';
    return _firstNonEmpty(data, const ['roomId', 'phongId', 'phongTroId']);
  }

  Future<RoomModel?> _loadRoom(String roomId) async {
    if (roomId.trim().isEmpty) return null;
    for (final collection in const ['rooms', 'host_rooms']) {
      final doc = await _firestore.collection(collection).doc(roomId).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        final status = (data['status'] ?? data['trangThai'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (status == 'deleted' || status == 'daxoa') continue;
        final room = RoomModel.fromMap(data, doc.id);
        if (room.hostId.trim().isNotEmpty) return room;
      }
    }
    return null;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queryAliases({
    required String collection,
    required List<String> fields,
    required String value,
  }) async {
    final byPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final field in fields) {
      final snapshot = await _firestore
          .collection(collection)
          .where(field, isEqualTo: value)
          .get();
      for (final doc in snapshot.docs) {
        byPath[doc.reference.path] = doc;
      }
    }
    return byPath.values.toList();
  }

  String _firstNonEmpty(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      final value = data[field]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
