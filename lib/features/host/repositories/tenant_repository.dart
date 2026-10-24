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
    phone: booking.renterPhone,
    roomId: booking.roomId,
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
      for (final pid in propertyIds) {
        try {
          final propDoc = await _firestore
              .collection(FirestoreCollections.hostProperties)
              .doc(pid)
              .get();
          if (propDoc.exists) {
            final data = propDoc.data();
            propertyNameMap[pid] =
                data?['name'] ?? data?['tenNha'] ?? data?['title'] ?? 'Nhà trọ';
          }
        } catch (_) {}
      }

      // 2. Tìm các bookings đang thuê của chủ nhà này
      final bookingsSnapshot = await _firestore
          .collection(FirestoreCollections.bookings)
          .where('hostId', isEqualTo: hostId)
          .get();

      final activeBookings = bookingsSnapshot.docs
          .where((doc) => isCheckedInBooking(doc.data()))
          .map((doc) => bookingForTenant(doc.data(), doc.id))
          .toList();

      // 3. Tìm các kỳ ở (periods) đang hoạt động
      final hostPeriods = <PeriodModel>[];
      for (final room in hostRooms) {
        for (final field in ['roomId', 'phongId']) {
          final snapshot = await _firestore
              .collection(FirestoreCollections.periods)
              .where(field, isEqualTo: room.id)
              .get();
          for (final doc in snapshot.docs) {
            final period = PeriodModel.fromFirestore(doc);
            if (const [
                  'dango',
                  'active',
                ].contains(period.status.toLowerCase()) &&
                !hostPeriods.any((p) => p.id == period.id)) {
              hostPeriods.add(period);
            }
          }
        }
      }
      hostPeriods.sort((a, b) => b.startDate.compareTo(a.startDate));

      // 4. Lấy cư dân theo từng kỳ ở
      final residentsByPeriod = <String, List<ResidentModel>>{};
      for (final period in hostPeriods) {
        var resSnap = await _firestore
            .collection(FirestoreCollections.residents)
            .where('periodId', isEqualTo: period.id)
            .get();
        if (resSnap.docs.isEmpty) {
          resSnap = await _firestore
              .collection(FirestoreCollections.residents)
              .where('kyThue_id', isEqualTo: period.id)
              .get();
        }

        residentsByPeriod[period.id] =
            resSnap.docs
                .map(ResidentModel.fromFirestore)
                .where(
                  (r) =>
                      r.moveOutDate == null &&
                      const [
                        'dango',
                        'active',
                      ].contains(r.statusId.toLowerCase()),
                )
                .toList()
              ..sort(
                (a, b) => (a.formId == 'chinh' ? 0 : 1).compareTo(
                  b.formId == 'chinh' ? 0 : 1,
                ),
              );
      }

      final items = <TenantItem>[];
      final processedRoomIds = <String>{};

      // Tổng hợp từ periods trước
      for (final period in hostPeriods) {
        final room = roomMap[period.roomId];
        if (room == null ||
            processedRoomIds.contains(room.id) ||
            !activeBookings.any((b) => b.id == period.bookingId)) {
          continue;
        }

        final periodResidents = residentsByPeriod[period.id] ?? [];
        final booking = activeBookings.cast<BookingRequestModel?>().firstWhere(
          (b) => b?.id == period.bookingId,
          orElse: () => null,
        );

        final propName =
            propertyNameMap[room.propertyId] ??
            (room.address.isNotEmpty ? room.address : 'Nhà trọ');

        final primaryName = periodResidents.isNotEmpty
            ? periodResidents.first.fullName
            : (booking?.renterName.isNotEmpty == true
                  ? booking!.renterName
                  : (room.tenantName.isNotEmpty ? room.tenantName : 'Cư dân'));

        final phone =
            periodResidents.isNotEmpty && periodResidents.first.phone.isNotEmpty
            ? periodResidents.first.phone
            : (booking?.renterPhone.isNotEmpty == true
                  ? booking!.renterPhone
                  : room.tenantPhone);

        items.add(
          TenantItem(
            id: period.id,
            primaryName: primaryName,
            phone: phone,
            avatar: periodResidents.isNotEmpty
                ? periodResidents.first.avatar
                : '',
            roomId: room.id,
            roomName: room.roomCode.isNotEmpty
                ? 'P.${room.roomCode}'
                : room.title,
            propertyId: room.propertyId,
            propertyName: propName,
            floor: room.floor > 0 ? room.floor : 1,
            roommates: periodResidents,
            periodId: period.id,
            bookingId: period.bookingId,
            moveInDate: period.startDate,
            deposit: booking?.deposit ?? room.deposit,
            status: period.status,
          ),
        );
        processedRoomIds.add(room.id);
      }

      // Tổng hợp thêm từ activeBookings nếu chưa có period
      activeBookings.sort((a, b) {
        final byState = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
        return byState != 0 ? byState : b.createdAt.compareTo(a.createdAt);
      });
      for (final booking in activeBookings) {
        if (hostPeriods.any((period) => period.bookingId == booking.id) ||
            (booking.isActive && processedRoomIds.contains(booking.roomId))) {
          continue;
        }
        final item = tenantFromBooking(
          booking,
          room: roomMap[booking.roomId],
          propertyNames: propertyNameMap,
        );
        items.add(item);
        processedRoomIds.add(item.roomId);
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
  }) async {
    final batch = _firestore.batch();

    // 1. Tìm hoặc tạo kỳ ở (Period) cho phòng
    String periodId = '';
    final periodQuery = await _firestore
        .collection(FirestoreCollections.periods)
        .where('roomId', isEqualTo: roomId)
        .where('status', isEqualTo: 'dangO')
        .limit(1)
        .get();

    if (periodQuery.docs.isNotEmpty) {
      periodId = periodQuery.docs.first.id;
    } else {
      final periodRef = _firestore
          .collection(FirestoreCollections.periods)
          .doc();
      periodId = periodRef.id;
      batch.set(periodRef, {
        'id': periodId,
        'roomId': roomId,
        'renterId': primaryTenantId,
        'startDate': FieldValue.serverTimestamp(),
        'status': 'dangO',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 2. Đảm bảo người thuê chính có bản ghi trong residents nếu chưa có
    final primaryResQuery = await _firestore
        .collection(FirestoreCollections.residents)
        .where('periodId', isEqualTo: periodId)
        .where('userId', isEqualTo: primaryTenantId)
        .limit(1)
        .get();

    if (primaryResQuery.docs.isEmpty) {
      final primaryResRef = _firestore
          .collection(FirestoreCollections.residents)
          .doc();
      batch.set(primaryResRef, {
        'id': primaryResRef.id,
        'periodId': periodId,
        'roomId': roomId,
        'userId': primaryTenantId,
        'fullName': primaryTenantName,
        'formId': 'chinh',
        'statusId': 'dangO',
        'moveInDate': FieldValue.serverTimestamp(),
      });
    }

    // 3. Thêm cư dân mới (người ở ghép) vào collection residents
    final newResRef = _firestore
        .collection(FirestoreCollections.residents)
        .doc();
    batch.set(newResRef, {
      'id': newResRef.id,
      'periodId': periodId,
      'roomId': roomId,
      'userId': newRoommateId,
      'fullName': newRoommateName,
      'phone': newRoommatePhone,
      'avatar': newRoommateAvatar,
      'formId': 'oGhep',
      'statusId': 'dangO',
      'moveInDate': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Cập nhật tên phòng kết hợp trong host_rooms
    final combinedTenantName = '$primaryTenantName & $newRoommateName';

    final hostRoomRef = _firestore
        .collection(FirestoreCollections.hostRooms)
        .doc(roomId);
    batch.set(hostRoomRef, {
      'status': 'occupied',
      'tenantName': combinedTenantName,
      'tenantIds': FieldValue.arrayUnion([primaryTenantId, newRoommateId]),
      'roommates': FieldValue.arrayUnion([newRoommateName]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
