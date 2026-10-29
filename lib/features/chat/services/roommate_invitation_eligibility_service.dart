import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/roommate_capacity_service.dart';
import '../../../data/models/room_model.dart';
import '../../auth/services/role_resolver.dart';
import 'roommate_invitation_policy.dart';

enum RoommateInvitationBlockReason {
  none,
  invalidUser,
  roleNotAllowed,
  noActiveRoom,
  roomAtCapacity,
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
      if (activeRoom == null) {
        return RoommateInvitationEligibility(
          senderRole: senderRole,
          receiverRole: receiverRole,
          activeRoom: null,
          blockReason: RoommateInvitationBlockReason.noActiveRoom,
        );
      }

      final capacity = await RoommateCapacityService(firestore: _firestore)
          .snapshotForAuthor(
        authorId: cleanSenderId,
        roomId: activeRoom.id,
        roomCapacity: activeRoom.capacity,
        knownOccupantIds: [cleanSenderId],
      );
      return RoommateInvitationEligibility(
        senderRole: senderRole,
        receiverRole: receiverRole,
        activeRoom: activeRoom,
        blockReason: capacity.isFull
            ? RoommateInvitationBlockReason.roomAtCapacity
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

    final activeBookings = bookingDocs.where((doc) {
      final data = doc.data();
      final status =
          data['status'] ?? data['trangThai'] ?? data['trangThai_id'];
      return RoommateInvitationPolicy.isActiveBookingStatus(status);
    }).toList()
      ..sort((a, b) {
        final aTime = _bookingTime(a.data());
        final bTime = _bookingTime(b.data());
        return bTime.compareTo(aTime);
      });

    for (final doc in activeBookings) {
      final data = doc.data();
      final roomId = _firstNonEmpty(data, const [
        'roomId',
        'phongId',
        'phongTroId',
        'baiDangId',
      ]);
      final room = await _loadRoom(roomId) ?? roomFromActiveBooking(data, doc.id);
      if (room != null && room.hostId.trim().isNotEmpty) return room;
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

  DateTime _bookingTime(Map<String, dynamic> data) {
    for (final key in const [
      'checkedInAt',
      'acceptedDate',
      'updatedAt',
      'approvedAt',
      'createdAt',
    ]) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Xác minh phòng khi người kia chấp nhận lời mời.
  /// `roomId` thường là document `posts`; nếu thiếu thì dùng hostId đã gắn lúc gửi.
  Future<RoomModel?> resolveInvitationRoom({
    required String roomId,
    String hostId = '',
    String roomTitle = '',
    String roomCode = '',
    String hostName = '',
  }) async {
    final loaded = await _loadRoom(roomId);
    if (loaded != null && loaded.hostId.trim().isNotEmpty) return loaded;
    return roomFromInvitationPayload(
      roomId: roomId,
      hostId: hostId,
      roomTitle: roomTitle,
      roomCode: roomCode,
      hostName: hostName,
    );
  }

  Future<RoomModel?> _loadRoom(String roomId) async {
    if (roomId.trim().isEmpty) return null;
    // Đơn thuê thường lưu roomId = document `posts`, không phải `rooms`.
    for (final collection in const ['posts', 'rooms', 'host_rooms']) {
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

/// Phòng mời ở ghép lấy từ đơn đang ở khi document `rooms`/`posts` thiếu.
RoomModel? roomFromActiveBooking(Map<String, dynamic> booking, String bookingId) {
  final hostId = [
    booking['hostId'],
    booking['chuNhaId'],
    booking['chu_tro_id'],
  ].map((value) => value?.toString().trim() ?? '').firstWhere(
        (value) => value.isNotEmpty,
        orElse: () => '',
      );
  if (hostId.isEmpty) return null;
  final roomId = [
    booking['roomId'],
    booking['phongId'],
    booking['phongTroId'],
    booking['baiDangId'],
    bookingId,
  ].map((value) => value?.toString().trim() ?? '').firstWhere((value) => value.isNotEmpty);
  return RoomModel.fromMap({
    'hostId': hostId,
    'hostName': booking['hostName'] ?? booking['tenChuNha'] ?? '',
    'hostPhone': booking['hostPhone'] ?? '',
    'title': booking['roomTitle'] ?? booking['title'] ?? '',
    'price': booking['rentalPrice'] ?? booking['price'] ?? booking['totalAmount'] ?? 0,
    'rentalPrice': booking['rentalPrice'] ?? booking['price'] ?? 0,
    'deposit': booking['depositAmount'] ?? booking['deposit'] ?? 0,
    'address': booking['roomAddress'] ?? booking['address'] ?? '',
    'roomCode': booking['roomCode'] ?? booking['maPhong'] ?? '',
  }, roomId);
}

RoomModel? roomFromInvitationPayload({
  required String roomId,
  required String hostId,
  String roomTitle = '',
  String roomCode = '',
  String hostName = '',
}) {
  if (hostId.trim().isEmpty) return null;
  return RoomModel.fromMap({
    'hostId': hostId.trim(),
    'hostName': hostName,
    'title': roomTitle,
    'roomCode': roomCode,
  }, roomId.trim().isNotEmpty ? roomId.trim() : hostId.trim());
}
