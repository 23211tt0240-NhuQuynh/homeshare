import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/resident_service.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/services/role_resolver.dart';
import 'roommate_invitation_policy.dart';

enum RoommateInvitationBlockReason {
  none,
  invalidUser,
  roleNotAllowed,
  noActiveRoom,
  roomFull,
  lookupFailed,
}

class RoomCapacityCheckResult {
  final String roomId;
  final int capacity;
  final int currentOccupants;
  final bool isFull;
  final String message;

  const RoomCapacityCheckResult({
    required this.roomId,
    required this.capacity,
    required this.currentOccupants,
    required this.isFull,
    required this.message,
  });

  int get remainingSlots => math.max(0, capacity - currentOccupants);
}

class RoommateInvitationEligibility {
  final String? senderRole;
  final String? receiverRole;
  final RoomModel? activeRoom;
  final List<RoomModel> activeRooms;
  final RoommateInvitationBlockReason blockReason;
  final Map<String, RoomCapacityCheckResult> capacityChecks;

  const RoommateInvitationEligibility({
    required this.senderRole,
    required this.receiverRole,
    required this.activeRoom,
    this.activeRooms = const [],
    required this.blockReason,
    this.capacityChecks = const {},
  });

  bool get canInvite =>
      blockReason == RoommateInvitationBlockReason.none &&
      RoommateInvitationPolicy.canInvite(
        senderRole: senderRole,
        receiverRole: receiverRole,
        hasActiveRoom: activeRooms.isNotEmpty || activeRoom != null,
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
        activeRooms: [],
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
          activeRooms: [],
          blockReason: RoommateInvitationBlockReason.roleNotAllowed,
        );
      }

      final activeRooms = await findActiveRooms(cleanSenderId);
      final activeRoom = activeRooms.isNotEmpty ? activeRooms.first : null;

      final capacityChecks = <String, RoomCapacityCheckResult>{};
      for (final room in activeRooms) {
        final cap = await checkRoomCapacity(
          room.id,
          senderId: cleanSenderId,
          fallbackRoom: room,
        );
        capacityChecks[room.id] = cap;
      }

      RoommateInvitationBlockReason blockReason = RoommateInvitationBlockReason.none;
      if (activeRooms.isEmpty) {
        blockReason = RoommateInvitationBlockReason.noActiveRoom;
      } else if (activeRooms.every((r) => capacityChecks[r.id]?.isFull == true)) {
        blockReason = RoommateInvitationBlockReason.roomFull;
      }

      return RoommateInvitationEligibility(
        senderRole: senderRole,
        receiverRole: receiverRole,
        activeRoom: activeRoom,
        activeRooms: activeRooms,
        blockReason: blockReason,
        capacityChecks: capacityChecks,
      );
    } catch (_) {
      return const RoommateInvitationEligibility(
        senderRole: null,
        receiverRole: null,
        activeRoom: null,
        activeRooms: [],
        blockReason: RoommateInvitationBlockReason.lookupFailed,
      );
    }
  }

  Future<RoomModel?> findActiveRoom(String userId) async {
    final rooms = await findActiveRooms(userId);
    return rooms.isNotEmpty ? rooms.first : null;
  }

  /// Kiểm tra sức chứa (capacity) và số người đang ở hiện tại của phòng.
  /// Nếu số người đang ở >= capacity (ví dụ 3/3 người) thì phòng đã đầy (isFull = true).
  Future<RoomCapacityCheckResult> checkRoomCapacity(
    String roomId, {
    String? senderId,
    RoomModel? fallbackRoom,
  }) async {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) {
      return const RoomCapacityCheckResult(
        roomId: '',
        capacity: 0,
        currentOccupants: 0,
        isFull: false,
        message: '',
      );
    }

    try {
      // 1. Tìm thông tin phòng từ host_rooms hoặc bài đăng posts.
      DocumentSnapshot<Map<String, dynamic>>? hostRoomDoc;
      DocumentSnapshot<Map<String, dynamic>>? postDoc;

      final directHostDoc =
          await _firestore.collection('host_rooms').doc(cleanRoomId).get();
      if (directHostDoc.exists && directHostDoc.data() != null) {
        hostRoomDoc = directHostDoc;
      } else {
        final dPost =
            await _firestore.collection('posts').doc(cleanRoomId).get();
        if (dPost.exists && dPost.data() != null) postDoc = dPost;

        // Nếu bài đăng có liên kết tới host_rooms.
        final linkedHostId = (postDoc?.data()?['hostRoomId'] ??
                postDoc?.data()?['roomId'])
            ?.toString()
            .trim() ??
            '';
        if (linkedHostId.isNotEmpty && linkedHostId != cleanRoomId) {
          final linkedDoc =
              await _firestore.collection('host_rooms').doc(linkedHostId).get();
          if (linkedDoc.exists && linkedDoc.data() != null) {
            hostRoomDoc = linkedDoc;
          }
        }
      }

      // 2. Xác định sức chứa (capacity)
      int capacity = 0;
      if (hostRoomDoc != null && hostRoomDoc.exists) {
        final rawCap =
            hostRoomDoc.data()?['capacity'] ?? hostRoomDoc.data()?['sucChua'];
        if (rawCap is num) {
          capacity = rawCap.toInt();
        } else if (rawCap != null) {
          capacity = int.tryParse(rawCap.toString()) ?? 0;
        }
      }
      if (capacity <= 0 && postDoc != null && postDoc.exists) {
        final rawCap = postDoc.data()?['capacity'] ??
            postDoc.data()?['sucChua'] ??
            postDoc.data()?['room_capacity'];
        if (rawCap is num) {
          capacity = rawCap.toInt();
        } else if (rawCap != null) {
          capacity = int.tryParse(rawCap.toString()) ?? 0;
        }
      }
      if (capacity <= 0 && fallbackRoom != null && fallbackRoom.capacity > 0) {
        capacity = fallbackRoom.capacity;
      }
      // Mặc định an toàn nếu chưa cấu hình
      if (capacity <= 0) {
        capacity = 2;
      }

      // 3. Xác định số người đang ở (currentOccupants)
      final targetRoomIds = <String>{cleanRoomId};
      if (hostRoomDoc != null) targetRoomIds.add(hostRoomDoc.id);

      final occupantIds = <String>{};
      if (senderId != null && senderId.trim().isNotEmpty) {
        occupantIds.add(senderId.trim());
      }

      int explicitRoommatesCount = 0;
      int? explicitOccupantsCount;

      if (hostRoomDoc != null && hostRoomDoc.exists) {
        final hostData = hostRoomDoc.data() ?? {};
        final tIds = hostData['tenantIds'];
        if (tIds is List) {
          for (final id in tIds) {
            final sId = id?.toString().trim() ?? '';
            if (sId.isNotEmpty) occupantIds.add(sId);
          }
        }
        final rMates = hostData['roommates'];
        if (rMates is List) {
          explicitRoommatesCount = rMates.length;
        }
        final cur = hostData['currentOccupants'] ??
            hostData['occupantsCount'] ??
            hostData['soNguoiHienTai'];
        if (cur is num) {
          explicitOccupantsCount = cur.toInt();
        }
      }

      // Tra cứu cư dân đang ở trong collection `residents`
      for (final rId in targetRoomIds) {
        final resDocs = await _firestore
            .collection('residents')
            .where('roomId', isEqualTo: rId)
            .get();
        for (final doc in resDocs.docs) {
          final data = doc.data();
          final status = (data['statusId'] ?? data['status'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          final hasMovedOut = data['moveOutDate'] != null;
          if (!hasMovedOut &&
              (status == 'dango' ||
                  status == 'active' ||
                  status == 'dang_o' ||
                  status.isEmpty)) {
            final uId = (data['userId'] ?? data['nguoiDungId'] ?? doc.id)
                .toString()
                .trim();
            if (uId.isNotEmpty) occupantIds.add(uId);
          }
        }
      }

      // Tra cứu các đơn đặt phòng / hợp đồng đang ở trong `bookings`
      for (final rId in targetRoomIds) {
        final bookingDocs = await _firestore
            .collection('bookings')
            .where('roomId', isEqualTo: rId)
            .get();
        for (final doc in bookingDocs.docs) {
          final data = doc.data();
          final bStatus = (data['status'] ?? data['trangThai'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          if (RoommateInvitationPolicy.isActiveBookingStatus(bStatus)) {
            final uId = (data['renterId'] ??
                    data['userId'] ??
                    data['nguoiDungId'] ??
                    '')
                .toString()
                .trim();
            if (uId.isNotEmpty) occupantIds.add(uId);
          }
        }
      }

      int occupants = occupantIds.length;
      if (explicitRoommatesCount > 0 &&
          explicitRoommatesCount + 1 > occupants) {
        occupants = explicitRoommatesCount + 1;
      }
      if (explicitOccupantsCount != null &&
          explicitOccupantsCount > occupants) {
        occupants = explicitOccupantsCount;
      }
      // Người đang thuê gửi lời mời tính ít nhất 1 người
      if (occupants < 1) occupants = 1;

      final isFull = capacity > 0 && occupants >= capacity;
      final message = isFull
          ? 'Phòng đã đủ số người ở tối đa ($occupants/$capacity người). Không thể gửi thêm lời mời ở ghép.'
          : 'Phòng hiện có $occupants/$capacity người.';

      return RoomCapacityCheckResult(
        roomId: cleanRoomId,
        capacity: capacity,
        currentOccupants: occupants,
        isFull: isFull,
        message: message,
      );
    } catch (e) {
      debugPrint('[CapacityCheck] Lỗi kiểm tra sức chứa phòng $cleanRoomId: $e');
      final capacity = fallbackRoom?.capacity ?? 2;
      return RoomCapacityCheckResult(
        roomId: cleanRoomId,
        capacity: capacity,
        currentOccupants: 1,
        isFull: false,
        message: '',
      );
    }
  }

  /// Tìm phòng người dùng đang ở để mời ở ghép.
  ///
  /// Một phòng vật lý có thể nằm ở cả bài đăng và phòng chủ trọ, hoặc còn
  /// một đơn cũ cùng tên. Những bản ghi đó được gom thành một lựa chọn,
  /// ưu tiên đúng phòng đang ở.
  Future<List<RoomModel>> findActiveRooms(String userId) async {
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

    final residentDocs = await _queryAliases(
      collection: 'residents',
      fields: const ['userId', 'nguoiDungId', 'nguoi_dung_id'],
      value: userId,
    );

    final activeResidentRooms = <String>{};
    final leftResidentRooms = <String>{};
    for (final doc in residentDocs) {
      final resident = ResidentModel.fromFirestore(doc);
      if (resident.userId.trim().isNotEmpty &&
          resident.userId.trim() != userId.trim()) {
        continue;
      }
      final rawRoomId = resident.roomId.trim().isNotEmpty
          ? resident.roomId.trim()
          : await _roomIdFromActivePeriod(resident.periodId);
      if (rawRoomId.isEmpty) continue;
      final canonical = await _canonicalRoomId(rawRoomId);
      final keys = {rawRoomId, if (canonical.isNotEmpty) canonical};
      if (ResidentService.isActive(resident)) {
        activeResidentRooms.addAll(keys);
      } else if (resident.isMovedOut) {
        leftResidentRooms.addAll(keys);
      }
    }

    final bookings = bookingDocs.toList()
      ..sort((a, b) {
        final aTime = _bookingTime(a.data());
        final bTime = _bookingTime(b.data());
        return bTime.compareTo(aTime);
      });

    final candidates = <InviteRoomCandidate>[];
    for (final doc in bookings) {
      final data = doc.data();
      final status =
          data['status'] ?? data['trangThai'] ?? data['trangThai_id'];
      final roomId = _firstNonEmpty(data, const [
        'roomId',
        'phongId',
        'phongTroId',
        'baiDangId',
      ]);
      final canonical = await _canonicalRoomId(roomId);
      final keys = {
        if (roomId.isNotEmpty) roomId,
        if (canonical.isNotEmpty) canonical,
      };
      final residentStillThere = keys.any(activeResidentRooms.contains);
      final residentLeft =
          keys.any(leftResidentRooms.contains) && !residentStillThere;
      if (residentLeft) continue;
      final staying =
          RoommateInvitationPolicy.isCurrentOccupancyStatus(status) ||
          residentStillThere;
      if (!staying) continue;

      final loaded = await _loadInviteRoom(
        preferredId: canonical.isNotEmpty ? canonical : roomId,
        fallbackId: roomId,
        booking: data,
        bookingId: doc.id,
      );
      if (loaded == null || loaded.room.hostId.trim().isEmpty) continue;
      candidates.add(
        InviteRoomCandidate(
          room: loaded.room,
          canonicalId: canonical.isNotEmpty ? canonical : loaded.room.id,
          sortTime: _bookingTime(data),
          currentStay: true,
          hostRoom: loaded.hostRoom,
        ),
      );
    }

    for (final doc in residentDocs) {
      final resident = ResidentModel.fromFirestore(doc);
      if (!ResidentService.isActive(resident)) continue;
      if (resident.userId.trim().isNotEmpty &&
          resident.userId.trim() != userId.trim()) {
        continue;
      }
      var roomId = resident.roomId.trim();
      if (roomId.isEmpty) {
        roomId = await _roomIdFromActivePeriod(resident.periodId);
      }
      if (roomId.isEmpty) continue;
      final canonical = await _canonicalRoomId(roomId);
      final loaded = await _loadInviteRoom(
        preferredId: canonical.isNotEmpty ? canonical : roomId,
        fallbackId: roomId,
      );
      if (loaded == null || loaded.room.hostId.trim().isEmpty) continue;
      candidates.add(
        InviteRoomCandidate(
          room: loaded.room,
          canonicalId: canonical.isNotEmpty ? canonical : loaded.room.id,
          sortTime: resident.moveInDate,
          currentStay: true,
          hostRoom: loaded.hostRoom,
        ),
      );
    }

    return collapseRoommateInviteRooms(candidates);
  }

  Future<String> _canonicalRoomId(String roomId) async {
    final clean = roomId.trim();
    if (clean.isEmpty) return '';
    try {
      final resolved = await ResidentService(_firestore).resolveRoomId(clean);
      return resolved.trim().isEmpty ? clean : resolved.trim();
    } catch (_) {
      return clean;
    }
  }

  Future<({RoomModel room, bool hostRoom})?> _loadInviteRoom({
    required String preferredId,
    required String fallbackId,
    Map<String, dynamic>? booking,
    String bookingId = '',
  }) async {
    for (final id in [preferredId, fallbackId]) {
      final hostRoom = await _loadHostRoom(id);
      if (hostRoom != null) return (room: hostRoom, hostRoom: true);
    }
    for (final id in [preferredId, fallbackId]) {
      final room = await _loadRoom(id);
      if (room != null) return (room: room, hostRoom: false);
    }
    if (booking != null) {
      final fallback = roomFromActiveBooking(
        booking,
        bookingId.isNotEmpty ? bookingId : fallbackId,
      );
      if (fallback != null) return (room: fallback, hostRoom: false);
    }
    return null;
  }

  Future<RoomModel?> _loadHostRoom(String roomId) async {
    final clean = roomId.trim();
    if (clean.isEmpty) return null;
    final doc = await _firestore.collection('host_rooms').doc(clean).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    final status = (data['status'] ?? data['trangThai'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'deleted' || status == 'daxoa') return null;
    final room = RoomModel.fromMap(data, doc.id);
    if (room.hostId.trim().isEmpty) return null;
    return room;
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
    for (final collection in const ['posts', 'host_rooms']) {
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

class InviteRoomCandidate {
  final RoomModel room;
  final String canonicalId;
  final DateTime sortTime;
  final bool currentStay;
  final bool hostRoom;

  const InviteRoomCandidate({
    required this.room,
    required this.canonicalId,
    required this.sortTime,
    required this.currentStay,
    this.hostRoom = false,
  });
}

/// Gom các đơn/bài đăng của cùng một phòng thành một lựa chọn mời ở ghép.
/// Giữ phòng chủ trọ đang ở, bỏ bản trùng tên và đơn không còn ở.
List<RoomModel> collapseRoommateInviteRooms(List<InviteRoomCandidate> candidates) {
  final staying = candidates.where((candidate) {
    return candidate.currentStay && candidate.room.hostId.trim().isNotEmpty;
  }).toList();

  final groups = <String, List<InviteRoomCandidate>>{};
  final order = <String>[];
  for (final candidate in staying) {
    final key = _inviteRoomIdentity(candidate);
    if (!groups.containsKey(key)) order.add(key);
    groups.putIfAbsent(key, () => []).add(candidate);
  }

  final rooms = <RoomModel>[];
  final seenIds = <String>{};
  for (final key in order) {
    final group = groups[key]!;
    group.sort((a, b) {
      final byHost = (b.hostRoom ? 1 : 0).compareTo(a.hostRoom ? 1 : 0);
      if (byHost != 0) return byHost;
      final aCanonical = a.canonicalId.isNotEmpty && a.room.id == a.canonicalId;
      final bCanonical = b.canonicalId.isNotEmpty && b.room.id == b.canonicalId;
      final byCanonical = (bCanonical ? 1 : 0).compareTo(aCanonical ? 1 : 0);
      if (byCanonical != 0) return byCanonical;
      return b.sortTime.compareTo(a.sortTime);
    });
    final chosen = group.first.room;
    if (chosen.id.isNotEmpty && !seenIds.add(chosen.id)) continue;
    rooms.add(chosen);
  }
  return rooms;
}

String _inviteRoomIdentity(InviteRoomCandidate candidate) {
  final room = candidate.room;
  final title = room.title.trim().toLowerCase();
  final address = room.address.trim().toLowerCase();
  final host = room.hostId.trim();
  final price = room.price.round();
  if (title.isNotEmpty || address.isNotEmpty) {
    return '$host|$title|$address|$price';
  }
  final canonical = candidate.canonicalId.trim();
  return canonical.isNotEmpty ? 'id:$canonical' : 'id:${room.id}';
}

/// Phòng mời ở ghép lấy từ đơn đang ở khi document `posts` thiếu.
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
