import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/resident_model.dart';
import '../../data/models/room_model.dart';

/// Occupant identities live in residents. Room projections are in-memory only.
class ResidentService {
  final FirebaseFirestore firestore;
  ResidentService(this.firestore);

  static bool isActive(ResidentModel resident) =>
      resident.moveOutDate == null &&
      const ['dango', 'active'].contains(resident.statusId.toLowerCase());

  static List<ResidentModel> activeMembers(Iterable<ResidentModel> residents) {
    final unique = <String, ResidentModel>{};
    for (final resident in residents.where(isActive)) {
      final key = resident.userId.isEmpty ? resident.id : resident.userId;
      final previous = unique[key];
      if (previous == null ||
          resident.moveInDate.isAfter(previous.moveInDate)) {
        unique[key] = resident;
      }
    }
    return unique.values.toList()..sort(
      (a, b) =>
          (a.formId == 'chinh' ? 0 : 1).compareTo(b.formId == 'chinh' ? 0 : 1),
    );
  }

  Future<String> resolveRoomId(String reference) async {
    if (reference.trim().isEmpty) throw StateError('Thiếu mã phòng');
    final room = await firestore.collection('host_rooms').doc(reference).get();
    if ((room.data()?['propertyId'] ?? '').toString().isNotEmpty) {
      return reference;
    }
    final post = await firestore.collection('posts').doc(reference).get();
    final data = post.data() ?? {};
    for (final key in ['roomId', 'room_id', 'phongId', 'phong_tro_id']) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return reference;
  }

  Future<List<ResidentModel>> forRoom(String roomId, {String? periodId}) async {
    final residents = <String, ResidentModel>{};
    Future<void> read(String field, String value) async {
      final snapshot = await firestore
          .collection('residents')
          .where(field, isEqualTo: value)
          .get();
      for (final doc in snapshot.docs) {
        residents[doc.id] = ResidentModel.fromFirestore(doc);
      }
    }

    await read('roomId', roomId);
    final periodIds = <String>{
      if (periodId != null && periodId.isNotEmpty) periodId,
    };
    final periods = await firestore
        .collection('periods')
        .where('roomId', isEqualTo: roomId)
        .get();
    final endedPeriods = <String>{};
    for (final doc in periods.docs) {
      final status = (doc.data()['status'] ?? doc.data()['trangThai'] ?? '')
          .toString()
          .toLowerCase();
      if (const ['dango', 'active'].contains(status)) {
        periodIds.add(doc.id);
      } else {
        endedPeriods.add(doc.id);
      }
    }
    for (final id in periodIds) {
      await read('periodId', id);
      await read('kyThue_id', id);
    }
    return activeMembers(
      residents.values.where((r) => !endedPeriods.contains(r.periodId)),
    );
  }

  static RoomModel withResidents(
    RoomModel room,
    List<ResidentModel> residents,
  ) {
    final active = activeMembers(residents);
    return room.copyWith(
      tenantName: active.map((r) => r.fullName).join(' & '),
      tenantPhone: active.isEmpty ? '' : active.first.phone,
      tenantAvatar: active.isEmpty ? '' : active.first.avatar,
    );
  }

  Future<RoomModel> hydrateRoom(RoomModel room) async =>
      withResidents(room, await forRoom(room.id));

  /// Explicit repair for older quick-check-in clients that only updated bookings.
  /// Never runs while listing residents and never creates unconfirmed occupants.
  Future<({int created, int skipped})> syncCheckedInResidents(
    String hostId,
  ) async {
    if (hostId.isEmpty) {
      throw StateError('Vui lòng đăng nhập tài khoản chủ trọ');
    }
    final snapshot = await firestore
        .collection('bookings')
        .where('hostId', isEqualTo: hostId)
        .get();
    bool checked(Map<String, dynamic> data) =>
        const [
          'dango',
          'active',
          'danhanphong',
        ].contains((data['status'] ?? '').toString().toLowerCase()) &&
        data['source'] != 'host_manual';
    Timestamp? checkedAt(Map<String, dynamic> data) => [
      data['checkedInAt'],
      data['checkinAt'],
      data['acceptedDate'],
    ].whereType<Timestamp>().firstOrNull;
    final candidates =
        snapshot.docs
            .where(
              (doc) => checked(doc.data()) && checkedAt(doc.data()) != null,
            )
            .toList()
          ..sort(
            (a, b) => checkedAt(b.data())!.compareTo(checkedAt(a.data())!),
          );
    var created = 0;
    var skipped = 0;
    final seenRooms = <String>{};
    for (final booking in candidates) {
      final data = booking.data();
      final userId = (data['renterId'] ?? data['nguoiDungId'] ?? '').toString();
      final reference = (data['roomId'] ?? data['phongId'] ?? '').toString();
      if (userId.isEmpty || userId == 'guest' || reference.isEmpty) {
        skipped++;
        continue;
      }
      final roomId = await resolveRoomId(reference);
      if (!seenRooms.add(roomId)) {
        skipped++;
        continue;
      }
      final roomRef = firestore.collection('host_rooms').doc(roomId);
      final room = await roomRef.get();
      final roomData = room.data() ?? {};
      if (roomData['hostId'] != hostId || roomData['status'] == 'deleted') {
        skipped++;
        continue;
      }
      final members = await forRoom(roomId);
      if (members.any((r) => r.userId == userId)) continue;
      if (members.any((r) => r.formId == 'chinh' && r.userId != userId)) {
        skipped++;
        continue;
      }
      final originalRef = firestore.collection('host_rooms').doc(reference);
      final original = reference == roomId ? room : await originalRef.get();
      final at = checkedAt(data)!;
      final legacyAt = original.data()?['contractStart'];
      final currentStart = roomData['contractStart'];
      if (currentStart is Timestamp &&
          currentStart.toDate().difference(at.toDate()).inSeconds > 120) {
        skipped++;
        continue;
      }
      // Old clients wrote occupancy on a listing-ID document. Only trust it
      // when its timestamp agrees with this confirmed booking.
      final legacyConfirmed =
          original.data()?['status'] == 'occupied' &&
          legacyAt is Timestamp &&
          legacyAt.toDate().difference(at.toDate()).inSeconds.abs() <= 120;
      if (roomData['status'] != 'occupied' && !legacyConfirmed) {
        skipped++;
        continue;
      }
      final periods = await firestore
          .collection('periods')
          .where('bookingId', isEqualTo: booking.id)
          .get();
      if (periods.docs.any(
        (doc) => const [
          'daketthuc',
          'ended',
          'checked_out',
        ].contains((doc.data()['status'] ?? '').toString().toLowerCase()),
      )) {
        skipped++;
        continue;
      }
      final active = periods.docs
          .where(
            (doc) => const [
              'dango',
              'active',
            ].contains((doc.data()['status'] ?? '').toString().toLowerCase()),
          )
          .toList();
      final periodRef = active.isEmpty
          ? firestore.collection('periods').doc('checkin_${booking.id}')
          : active.first.reference;
      final residentRef = firestore
          .collection('residents')
          .doc('${periodRef.id}_$userId');
      final added = await firestore.runTransaction<bool>((tx) async {
        final currentBooking = await tx.get(booking.reference);
        final currentRoom = await tx.get(roomRef);
        final currentOriginal = reference == roomId
            ? currentRoom
            : await tx.get(originalRef);
        final currentPeriod = await tx.get(periodRef);
        final currentResident = await tx.get(residentRef);
        final current = currentBooking.data() ?? {};
        if (!checked(current) ||
            checkedAt(current) != at ||
            current['hostId'] != hostId ||
            (current['renterId'] ?? current['nguoiDungId'] ?? '').toString() !=
                userId ||
            (current['roomId'] ?? current['phongId'] ?? '').toString() !=
                reference ||
            currentRoom.data()?['hostId'] != hostId ||
            currentRoom.data()?['updatedAt'] != roomData['updatedAt'] ||
            currentRoom.data()?['status'] != roomData['status'] ||
            currentRoom.data()?['contractId'] != roomData['contractId'] ||
            currentRoom.data()?['contractStart'] != roomData['contractStart'] ||
            currentOriginal.data()?['updatedAt'] !=
                original.data()?['updatedAt'] ||
            currentResident.exists) {
          return false;
        }
        if (currentPeriod.exists &&
            !const ['dango', 'active'].contains(
              (currentPeriod.data()?['status'] ?? '').toString().toLowerCase(),
            )) {
          return false;
        }
        if (!currentPeriod.exists) {
          tx.set(periodRef, {
            'id': periodRef.id,
            'bookingId': booking.id,
            'roomId': roomId,
            'renterId': userId,
            'startDate': at,
            'status': 'dangO',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        tx.set(
          residentRef,
          ResidentModel(
            id: residentRef.id,
            roomId: roomId,
            periodId: periodRef.id,
            userId: userId,
            fullName: (current['renterName'] ?? current['tenNguoiO'] ?? '')
                .toString(),
            phone: (current['renterPhone'] ?? current['sdtNguoiO'] ?? '')
                .toString(),
            moveInDate: at.toDate(),
          ).toMap(),
        );
        tx.update(roomRef, {
          'status': 'occupied',
          'contractId': periodRef.id,
          'contractStart': at,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (added) {
        created++;
      } else {
        skipped++;
      }
    }
    return (created: created, skipped: skipped);
  }

  /// Reuses existing occupancy, including records created before this change.
  /// All writes commit with the calling check-in batch.
  Future<String> preparePrimary({
    required WriteBatch batch,
    required String bookingId,
    required String roomId,
    required String userId,
    required String fullName,
    required String phone,
    required DateTime now,
  }) async {
    if (userId.isEmpty || userId == 'guest') {
      throw StateError('Thiếu tài khoản cư dân');
    }
    final periods = await firestore
        .collection('periods')
        .where('bookingId', isEqualTo: bookingId)
        .get();
    final active = periods.docs
        .where(
          (doc) => const [
            'dango',
            'active',
          ].contains((doc.data()['status'] ?? '').toString().toLowerCase()),
        )
        .toList();
    final periodRef = active.isEmpty
        ? firestore.collection('periods').doc('checkin_$bookingId')
        : active.first.reference;
    final existing = await firestore
        .collection('residents')
        .where('periodId', isEqualTo: periodRef.id)
        .get();
    final primary = existing.docs
        .where((doc) => doc.data()['userId'] == userId)
        .toList();
    final residentRef = primary.isEmpty
        ? firestore.collection('residents').doc('${periodRef.id}_$userId')
        : primary.first.reference;
    if (active.isEmpty) {
      batch.set(periodRef, {
        'id': periodRef.id,
        'bookingId': bookingId,
        'roomId': roomId,
        'renterId': userId,
        'startDate': Timestamp.fromDate(now),
        'status': 'dangO',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (active.isNotEmpty) {
      batch.update(periodRef, {'roomId': roomId});
    }
    batch.set(
      residentRef,
      ResidentModel(
        id: residentRef.id,
        periodId: periodRef.id,
        roomId: roomId,
        userId: userId,
        fullName: fullName,
        phone: phone,
        moveInDate: primary.isEmpty
            ? now
            : ResidentModel.fromFirestore(primary.first).moveInDate,
      ).toMap(),
      SetOptions(merge: true),
    );
    return periodRef.id;
  }
}
