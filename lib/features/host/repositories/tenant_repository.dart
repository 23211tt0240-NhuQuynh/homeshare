import 'package:flutter/foundation.dart';
import '../../../core/services/roommate_capacity_service.dart';
import '../../../core/services/resident_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';

/// Đại diện một nhóm hoặc một người thuê kèm phòng và cơ sở
class TenantItem {
  final String id;
  final String primaryName;
  final String renterId;
  final String phone;
  final String avatar;
  final String roomId;
  final String roomName;
  final String propertyId;
  final String propertyName;
  final int floor;
  final List<ResidentModel> roommates;
  final String periodId;
  final String bookingId;
  final DateTime moveInDate;
  final double deposit;
  final String status;

  bool get isActive => const [
    'dango',
    'active',
    'danhanphong',
    'dang_o',
  ].contains(status.toLowerCase());
  String get statusLabel => isActive ? 'Đang ở' : 'Chờ nhận phòng';

  bool matches(String query) {
    final text = query.trim().toLowerCase();
    return text.isEmpty ||
        [
          primaryName,
          phone,
          roomName,
          propertyName,
          bookingId,
          ...roommates.expand((r) => [r.fullName, r.phone]),
        ].any((v) => v.toLowerCase().contains(text));
  }

  bool get isGroup => roommates.length > 1;
  int get memberCount => roommates.isEmpty ? 1 : roommates.length;

  String get displayName {
    if (roommates.length > 1) {
      return roommates.map((r) => r.fullName).take(2).join(' & ');
    }
    return primaryName.isNotEmpty ? primaryName : 'Khách thuê';
  }

  const TenantItem({
    required this.id,
    required this.primaryName,
    this.renterId = '',
    required this.phone,
    this.avatar = '',
    required this.roomId,
    required this.roomName,
    required this.propertyId,
    required this.propertyName,
    this.floor = 1,
    this.roommates = const [],
    this.periodId = '',
    this.bookingId = '',
    required this.moveInDate,
    this.deposit = 0.0,
    this.status = 'dangO',
  });
}

/// Thống kê người thuê của chủ trọ
class TenantStats {
  final int facilityCount; // Số cơ sở
  final int activeTenantCount; // Số người đang thuê
  final int occupiedRoomCount; // Số phòng đang sử dụng

  const TenantStats({
    this.facilityCount = 0,
    this.activeTenantCount = 0,
    this.occupiedRoomCount = 0,
  });
}

class TenantRepository {
  final FirebaseFirestore _firestore;

  TenantRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<({int created, int skipped})> syncCheckedInResidents(String hostId) =>
      ResidentService(_firestore).syncCheckedInResidents(hostId);

  // Read the existing check-in routes without changing shared booking parsing.
  static bool isCheckedInBooking(Map<String, dynamic> data) {
    if (data['source'] == 'host_manual') return false;
    final status = (data['status'] ?? data['trangThai'] ?? '')
        .toString()
        .toLowerCase();
    if (const [
      'cancelled',
      'rejected',
      'dahuy',
      'checkout',
      'checked_out',
      'daketthuc',
    ].contains(status)) {
      return false;
    }
    return const [
          'active',
          'dango',
          'dang_o',
          'danhanphong',
        ].contains(status) ||
        data['isCheckIn'] == true ||
        data['daNhanPhong'] == true;
  }

  static BookingRequestModel bookingForTenant(
    Map<String, dynamic> data,
    String id,
  ) {
    final normalized = Map<String, dynamic>.from(data);
    for (final pair in {
      'roomId': 'phongId',
      'renterName': 'tenNguoiO',
      'renterPhone': 'sdtNguoiO',
      'hostId': 'chuNhaId',
    }.entries) {
      final value = data[pair.key];
      if (value is String && value.isNotEmpty) normalized[pair.value] = value;
    }
    normalized['status'] = 'active';
    normalized['acceptedDate'] =
        data['checkedInAt'] ?? data['checkinAt'] ?? data['acceptedDate'];
    return BookingRequestModel.fromMap(normalized, id);
  }

  static TenantItem tenantFromBooking(
    BookingRequestModel booking, {
    RoomModel? room,
    Map<String, String> propertyNames = const {},
  }) => TenantItem(
    id: booking.id,
    primaryName: booking.renterName,
    renterId: booking.renterId,
    phone: booking.renterPhone,
    roomId: room?.id ?? booking.roomId,
    roomName: room != null
        ? (room.roomCode.isNotEmpty ? 'P.${room.roomCode}' : room.title)
        : (booking.roomCode.isNotEmpty
              ? 'P.${booking.roomCode}'
              : booking.roomTitle),
    propertyId: room?.propertyId ?? '',
    propertyName:
        propertyNames[room?.propertyId] ?? room?.address ?? booking.roomAddress,
    floor: room != null && room.floor > 0 ? room.floor : 1,
    bookingId: booking.id,
    moveInDate: booking.acceptedDate ?? booking.moveInDate,
    deposit: booking.deposit,
    status: 'active',
  );

  /// Booking roomId can be a listing ID. Resolve its FK, never its title.
  static RoomModel? resolveTenantRoom(
    String reference,
    Map<String, RoomModel> hostRooms,
    Map<String, Map<String, dynamic>> posts,
  ) {
    final post = posts[reference];
    if (post != null) {
      for (final key in ['roomId', 'room_id', 'phongId', 'phong_tro_id']) {
        final id = (post[key] ?? '').toString().trim();
        if (id.isNotEmpty && hostRooms.containsKey(id)) return hostRooms[id];
      }
    }
    return hostRooms[reference];
  }

  /// Roommate approval after quick check-in can create a period without
  /// bookingId. Only attach it to a checked-in booking for the same tenant/room.
  static BookingRequestModel? bookingForPeriod(
    PeriodModel period,
    List<BookingRequestModel> bookings,
    Map<String, RoomModel> rooms,
  ) {
    final roomId = rooms[period.roomId]?.id ?? period.roomId;
    for (final booking in bookings) {
      if (!booking.isActive) continue;
      final bookingRoomId = rooms[booking.roomId]?.id ?? booking.roomId;
      if (bookingRoomId != roomId) continue;
      if (period.bookingId.isNotEmpty) {
        if (booking.id == period.bookingId) return booking;
      } else if (period.renterId.isNotEmpty &&
          booking.renterId == period.renterId) {
        return booking;
      }
    }
    return null;
  }

  static TenantItem tenantFromResidents(
    RoomModel room,
    List<ResidentModel> residents, {
    String propertyName = '',
    BookingRequestModel? booking,
  }) {
    final members = ResidentService.activeMembers(residents);
    if (members.isEmpty) throw StateError('Phòng chưa có cư dân đang ở');
    final primary = members.first;
    return TenantItem(
      id: primary.periodId.isNotEmpty ? primary.periodId : primary.id,
      primaryName: primary.fullName,
      renterId: primary.userId,
      phone: primary.phone,
      avatar: primary.avatar,
      roomId: room.id,
      roomName: room.roomCode.isNotEmpty ? 'P.${room.roomCode}' : room.title,
      propertyId: room.propertyId,
      propertyName: propertyName,
      floor: room.floor,
      roommates: members,
      periodId: primary.periodId,
      bookingId: booking?.id ?? '',
      moveInDate: primary.moveInDate,
      deposit: booking?.deposit ?? room.deposit,
      status: 'active',
    );
  }

  /// Lắng nghe danh sách người thuê của chủ trọ hiện tại
  Stream<List<TenantItem>> watchHostTenants(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _watchTenantChanges(hostId).asyncMap((roomSnapshot) async {
      final hostRooms = roomSnapshot.docs
          .map(RoomModel.fromFirestore)
          .where((r) => r.status != 'deleted')
          .toList();

      final roomMap = {for (var r in hostRooms) r.id: r};
      final propertyIds = hostRooms
          .map((r) => r.propertyId)
          .where((id) => id.isNotEmpty)
          .toSet();

      // Lấy danh sách tên properties
      final propertyNameMap = <String, String>{};
      await Future.wait(
        propertyIds.map((pid) async {
          try {
            final propDoc = await _firestore
                .collection(FirestoreCollections.hostProperties)
                .doc(pid)
                .get();
            if (propDoc.exists) {
              final data = propDoc.data();
              propertyNameMap[pid] =
                  data?['name'] ??
                  data?['tenNha'] ??
                  data?['title'] ??
                  'Nhà trọ';
            }
          } catch (_) {}
        }),
      );

      // 2. Tìm các bookings đang thuê của chủ nhà này
      final bookingsSnapshot = await _firestore
          .collection(FirestoreCollections.bookings)
          .where('hostId', isEqualTo: hostId)
          .get();

      final activeBookings = bookingsSnapshot.docs
          .where((doc) => isCheckedInBooking(doc.data()))
          .map((doc) => bookingForTenant(doc.data(), doc.id))
          .toList();

      // Older bookings saved the listing ID as roomId. Alias it to the
      // operational room so property filters and room grouping use real IDs.
      final postData = <String, Map<String, dynamic>>{};
      await Future.wait(
        activeBookings.map((b) => b.roomId).toSet().map((reference) async {
          final existing = roomMap[reference];
          if (existing != null && existing.propertyId.isNotEmpty) return;
          final post = await _firestore
              .collection(FirestoreCollections.posts)
              .doc(reference)
              .get();
          if (post.exists) postData[reference] = post.data()!;
          final resolved = resolveTenantRoom(reference, roomMap, postData);
          if (resolved != null) roomMap[reference] = resolved;
        }),
      );

      // residents is the only source of occupant identities. Bookings only
      // supply contract/deposit context; a booking alone is not a resident.
      final grouped = <String, List<ResidentModel>>{};
      final service = ResidentService(_firestore);
      // Chủ trọ - Quản lý người thuê - Gom mã bài đăng về phòng thật,
      // mỗi phòng chỉ đọc một lần và các phòng được tải song song.
      final canonicalRooms = {
        for (final room in roomMap.values)
          if (room.propertyId.isNotEmpty) room.id: room,
      };
      await Future.wait(
        canonicalRooms.keys.map((roomId) async {
          grouped[roomId] = await service.forRoom(roomId);
        }),
      );
      final items = <TenantItem>[];
      for (final entry in grouped.entries) {
        final room = roomMap.values.firstWhere((room) => room.id == entry.key);
        final members = ResidentService.activeMembers(entry.value);
        if (members.isEmpty) continue;
        final primary = members.first;
        final bookings = activeBookings
            .where(
              (booking) =>
                  (roomMap[booking.roomId]?.id ?? booking.roomId) == room.id &&
                  booking.renterId == primary.userId,
            )
            .toList();
        final booking = bookings.isEmpty ? null : bookings.first;
        items.add(
          tenantFromResidents(
            room,
            members,
            propertyName: propertyNameMap[room.propertyId] ?? room.address,
            booking: booking,
          ),
        );
      }

      items.sort((a, b) => b.moveInDate.compareTo(a.moveInDate));
      return items;
    });
  }

  /// Only queries rooms belonging to this host and their periods/residents.
  /// Re-emits the room snapshot when any input changes so the projection reloads.
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchTenantChanges(
    String hostId,
  ) {
    late StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
    final subscriptions =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    QuerySnapshot<Map<String, dynamic>>? rooms;
    Timer? debounce;
    void emit() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 100), () {
        if (!controller.isClosed && rooms != null) controller.add(rooms!);
      });
    }

    void listen(
      String key,
      Query<Map<String, dynamic>> query, {
      void Function(QuerySnapshot<Map<String, dynamic>>)? onData,
    }) {
      if (subscriptions.containsKey(key)) return;
      subscriptions[key] = query.snapshots().listen(
        (snapshot) {
          if (controller.isClosed) return;
          onData?.call(snapshot);
          emit();
        },
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        },
      );
    }

    controller = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      onListen: () {
        listen(
          'bookings',
          _firestore
              .collection(FirestoreCollections.bookings)
              .where('hostId', isEqualTo: hostId),
        );
        listen(
          'posts',
          _firestore
              .collection(FirestoreCollections.posts)
              .where('hostId', isEqualTo: hostId),
        );
        listen(
          'properties',
          _firestore
              .collection(FirestoreCollections.hostProperties)
              .where('hostId', isEqualTo: hostId),
        );
        listen(
          'rooms',
          _firestore
              .collection(FirestoreCollections.hostRooms)
              .where('hostId', isEqualTo: hostId),
          onData: (snapshot) {
            rooms = snapshot;
            // Replace dependent listeners when the host's room inventory changes.
            for (final key
                in subscriptions.keys
                    .where(
                      (k) =>
                          k.startsWith('period:') || k.startsWith('resident:'),
                    )
                    .toList()) {
              subscriptions.remove(key)?.cancel();
            }
            for (final room in snapshot.docs.where(
              (r) => r.data()['status'] != 'deleted',
            )) {
              listen(
                'resident:room:${room.id}',
                _firestore
                    .collection(FirestoreCollections.residents)
                    .where('roomId', isEqualTo: room.id),
              );
              for (final field in ['roomId', 'phongId']) {
                listen(
                  'period:${room.id}:$field',
                  _firestore
                      .collection(FirestoreCollections.periods)
                      .where(field, isEqualTo: room.id),
                  onData: (periods) {
                    for (final period in periods.docs) {
                      for (final residentField in ['periodId', 'kyThue_id']) {
                        listen(
                          'resident:${period.id}:$residentField',
                          _firestore
                              .collection(FirestoreCollections.residents)
                              .where(residentField, isEqualTo: period.id),
                        );
                      }
                    }
                  },
                );
              }
            }
          },
        );
      },
      onCancel: () async {
        debounce?.cancel();
        await Future.wait(subscriptions.values.map((s) => s.cancel()));
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  /// Counts only checked-in occupants, including active roommates.
  Stream<TenantStats> watchTenantStats(String hostId) =>
      watchHostTenants(hostId).map((items) {
        final active = items.where((item) => item.isActive).toList();
        return TenantStats(
          facilityCount: items
              .map((item) => item.propertyId)
              .where((id) => id.isNotEmpty)
              .toSet()
              .length,
          activeTenantCount: active.fold<int>(
            0,
            (total, item) => total + item.memberCount,
          ),
          occupiedRoomCount: active.map((item) => item.roomId).toSet().length,
        );
      });

  /// Thêm người ở ghép vào chung phòng với người thuê chính
  Future<void> addRoommateToRoom({
    required String roomId,
    required String primaryTenantId,
    required String primaryTenantName,
    required String newRoommateId,
    required String newRoommateName,
    String newRoommatePhone = '',
    String newRoommateAvatar = '',
    WriteBatch? batch,
  }) async {
    if (primaryTenantId.isEmpty ||
        newRoommateId.isEmpty ||
        primaryTenantId == newRoommateId) {
      throw StateError('Tài khoản người ở ghép không hợp lệ');
    }
    final service = ResidentService(_firestore);
    roomId = await service.resolveRoomId(roomId);
    final members = await service.forRoom(roomId);
    final primary = members
        .where((r) => r.userId == primaryTenantId && r.formId == 'chinh')
        .toList();
    if (primary.isEmpty || primary.first.periodId.isEmpty) {
      throw StateError(
        'Người thuê chính chưa có hồ sơ nhận phòng tại phòng này. Vui lòng kiểm tra hoặc đồng bộ hồ sơ nhận phòng.',
      );
    }
    final writes = batch ?? _firestore.batch();
    final periodId = await service.ensureActivePeriodForResident(
      batch: writes,
      resident: primary.first,
      roomId: roomId,
    );

    // 3. Thêm cư dân mới (người ở ghép) vào collection residents
    final existingRoommates = await _firestore
        .collection(FirestoreCollections.residents)
        .where('periodId', isEqualTo: periodId)
        .get();
    final existing = existingRoommates.docs
        .where((doc) => doc.data()['userId'] == newRoommateId)
        .toList();
    final newResRef = existing.isEmpty
        ? _firestore
              .collection(FirestoreCollections.residents)
              .doc('${periodId}_$newRoommateId')
        : existing.first.reference;
    writes.set(newResRef, {
      'id': newResRef.id,
      'periodId': periodId,
      'roomId': roomId,
      'userId': newRoommateId,
      'fullName': newRoommateName,
      if (newRoommatePhone.isNotEmpty || existing.isEmpty)
        'phone': newRoommatePhone,
      if (newRoommateAvatar.isNotEmpty || existing.isEmpty)
        'avatar': newRoommateAvatar,
      'formId': 'oGhep',
      'statusId': 'dangO',
      'status': 'active',
      'moveOutDate': FieldValue.delete(),
      if (existing.isEmpty || existing.first.data()['moveOutDate'] != null)
        'moveInDate': FieldValue.serverTimestamp(),
      if (existing.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. Phòng chỉ lưu trạng thái vận hành; danh sách người ở nằm ở residents

    final hostRoomRef = _firestore
        .collection(FirestoreCollections.hostRooms)
        .doc(roomId);
    writes.update(hostRoomRef, {
      'status': 'occupied',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (batch == null) {
      await writes.commit();
      await closeFullRoommatePosts(
        roomId: roomId,
        primaryTenantId: primaryTenantId,
        newRoommateId: newRoommateId,
      );
    }
  }

  Future<void> closeFullRoommatePosts({
    required String roomId,
    required String primaryTenantId,
    required String newRoommateId,
  }) async {
    try {
      roomId = await ResidentService(_firestore).resolveRoomId(roomId);
      await RoommateCapacityService(
        firestore: _firestore,
      ).closeHasRoomPostsIfFull(
        authorId: primaryTenantId,
        roomId: roomId,
        knownOccupantIds: [primaryTenantId, newRoommateId],
      );
    } catch (error) {
      debugPrint('Ẩn tin ở ghép khi đủ sức chứa: $error');
    }
  }
}
