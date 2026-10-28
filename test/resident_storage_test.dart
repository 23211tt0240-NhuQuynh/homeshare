import 'package:home_share/features/chat/services/roommate_invitation_eligibility_service.dart';
import 'package:home_share/features/host/notifications/repositories/host_notification_repository.dart';
// Firestore interfaces are faked only to record repository reads/writes in tests.
// ignore_for_file: subtype_of_sealed_class
import 'package:home_share/core/services/booking_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/resident_service.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/repositories/handover_repository.dart';
import 'package:home_share/features/host/repositories/tenant_repository.dart';

// A recording store exercises the real repositories without Firebase credentials.
class Store extends Fake implements FirebaseFirestore {
  final rows = <String, Map<String, dynamic>>{};
  var sequence = 0;
  bool failNextCommit = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      Col(this, path);
  @override
  WriteBatch batch() => Batch(this);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final batch = Batch(this);
    final result = await transactionHandler(Tx(this, batch));
    await batch.commit();
    return result;
  }
}

class Col extends Fake implements CollectionReference<Map<String, dynamic>> {
  final Store store;
  @override
  final String path;
  final Map<String, Object?> filters;
  Col(this.store, this.path, [this.filters = const {}]);
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #doc) {
      return Ref(
        store,
        '$path/${call.positionalArguments.isEmpty || call.positionalArguments.first == null ? 'generated_${store.sequence++}' : call.positionalArguments.first}',
      );
    }
    if (call.memberName == #add) {
      final ref = Ref(store, '$path/generated_${store.sequence++}');
      store.rows[ref.path] = Map<String, dynamic>.from(
        call.positionalArguments.first as Map,
      );
      return Future<DocumentReference<Map<String, dynamic>>>.value(ref);
    }
    if (call.memberName == #where) {
      return Col(store, path, {
        ...filters,
        call.positionalArguments.first as String:
            call.namedArguments[#isEqualTo],
      });
    }
    if (call.memberName == #limit) return this;
    if (call.memberName == #get) {
      final docs = store.rows.entries
          .where(
            (entry) =>
                entry.key.split('/').length == 2 &&
                entry.key.startsWith('$path/') &&
                filters.entries.every((f) => entry.value[f.key] == f.value),
          )
          .map<QueryDocumentSnapshot<Map<String, dynamic>>>(
            (entry) => QDoc(store, entry.key),
          )
          .toList();
      return Future<QuerySnapshot<Map<String, dynamic>>>.value(Snapshot(docs));
    }
    return super.noSuchMethod(call);
  }
}

class Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  final Store store;
  @override
  final String path;
  Ref(this.store, this.path);
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => Doc(store, path);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.rows[path] = {...?store.rows[path], ...data};
  }
}

class Doc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Store store;
  final String path;
  Doc(this.store, this.path);
  @override
  String get id => path.split('/').last;
  @override
  bool get exists => store.rows.containsKey(path);
  @override
  Map<String, dynamic>? data() => store.rows[path];
  @override
  DocumentReference<Map<String, dynamic>> get reference => Ref(store, path);
}

class QDoc extends Doc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  QDoc(super.store, super.path);
  @override
  Map<String, dynamic> data() => store.rows[path]!;
}

class Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  Snapshot(this.docs);
}

class Batch extends Fake implements WriteBatch {
  final Store store;
  final pending = <void Function()>[];
  Batch(this.store);
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #set || call.memberName == #update) {
      final ref = call.positionalArguments[0] as Ref;
      final data = Map<String, dynamic>.from(
        call.positionalArguments[1] as Map,
      );
      pending.add(() {
        final row = {...?store.rows[ref.path]};
        for (final entry in data.entries) {
          if (entry.value == FieldValue.delete()) {
            row.remove(entry.key);
          } else {
            row[entry.key] = entry.value is FieldValue
                ? Timestamp.now()
                : entry.value;
          }
        }
        store.rows[ref.path] = row;
      });
      return null;
    }
    if (call.memberName == #commit) {
      if (store.failNextCommit) {
        store.failNextCommit = false;
        return Future<void>.error(StateError('Simulated commit failure'));
      }
      for (final write in pending) {
        write();
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(call);
  }
}

class Tx extends Fake implements Transaction {
  final Store store;
  final Batch batch;
  Tx(this.store, this.batch);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => Doc(store, (reference as Ref).path) as DocumentSnapshot<T>;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #set || call.memberName == #update) {
      batch.noSuchMethod(call);
      return this;
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  late Store store;
  setUp(() {
    store = Store();
    store.rows['host_rooms/room'] = {
      'propertyId': 'home',
      'hostId': 'host',
      'status': 'occupied',
    };
    store.rows['bookings/booking'] = {
      'roomId': 'room',
      'renterId': 'uid',
      'status': 'active',
    };
  });
  test(
    'Check-in preparation stores identity only in residents and reuses it on retry',
    () async {
      final service = ResidentService(store);
      final original = Map<String, dynamic>.from(
        store.rows['host_rooms/room']!,
      );
      Future<void> checkin() async {
        final batch = store.batch();
        await service.preparePrimary(
          batch: batch,
          bookingId: 'booking',
          roomId: 'room',
          userId: 'uid',
          fullName: 'An',
          phone: '0912345678',
          now: DateTime(2026),
        );
        await batch.commit();
      }

      await checkin();
      await checkin();
      expect(
        store.rows.keys.where((k) => k.startsWith('residents/')),
        hasLength(1),
      );
      final residents = await service.forRoom('room');
      expect(residents.single.fullName, 'An');
      expect(residents.single.roomId, 'room');
      expect(store.rows['host_rooms/room'], original);
    },
  );
  test(
    'Quick QR check-in creates residents and never persists room identity',
    () async {
      store.rows['bookings/booking']!.addAll({
        'renterName': 'An',
        'renterPhone': '0912345678',
      });
      await BookingService(
        firestore: store,
      ).checkinBooking('booking', hostId: 'host');
      final members = await ResidentService(store).forRoom('room');
      expect(members.single.fullName, 'An');
      expect(members.single.phone, '0912345678');
      expect(store.rows['host_rooms/room']!.containsKey('tenantName'), isFalse);
      expect(
        store.rows['host_rooms/room']!.containsKey('tenantPhone'),
        isFalse,
      );
      expect(store.rows['host_rooms/room']!['status'], 'occupied');
    },
  );

  test(
    'Full handover records residents without duplicating identity on the room',
    () async {
      await HandoverRepository(firestore: store).confirmHandover(
        bookingId: 'booking',
        roomId: 'room',
        renterId: 'uid',
        renterName: 'An',
        renterPhone: '0912345678',
        hostId: 'host',
        electricityMeter: 0,
        electricityRate: 0,
        waterMeter: 0,
        waterRate: 0,
        isKeyHandedOver: true,
        note: '',
        items: [],
      );
      expect(
        (await ResidentService(store).forRoom('room')).single.fullName,
        'An',
      );
      expect(
        store.rows['host_rooms/room']!.keys,
        isNot(contains('tenantName')),
      );
      expect(
        store.rows['host_rooms/room']!.keys,
        isNot(contains('tenantPhone')),
      );
    },
  );
  test(
    'Roommate approval adds members in residents, is idempotent and does not write room identities',
    () async {
      final primaryBatch = store.batch();
      await ResidentService(store).preparePrimary(
        batch: primaryBatch,
        bookingId: 'booking',
        roomId: 'room',
        userId: 'uid',
        fullName: 'An',
        phone: '0912345678',
        now: DateTime(2026),
      );
      await primaryBatch.commit();
      final repo = TenantRepository(firestore: store);
      Future<void> approve() => repo.addRoommateToRoom(
        roomId: 'room',
        primaryTenantId: 'uid',
        primaryTenantName: 'An',
        newRoommateId: 'mate',
        newRoommateName: 'Bình',
      );
      await approve();
      await approve();
      final members = await ResidentService(store).forRoom('room');
      expect(members.map((r) => r.fullName), ['An', 'Bình']);
      expect(
        store.rows.keys.where((k) => k.startsWith('residents/')),
        hasLength(2),
      );
      for (final key in [
        'tenantName',
        'tenantPhone',
        'tenantIds',
        'roommates',
      ]) {
        expect(store.rows['host_rooms/room']!.containsKey(key), isFalse);
      }
      final projection = TenantRepository.tenantFromResidents(
        RoomModel.fromMap(store.rows['host_rooms/room']!, 'room'),
        members,
      );
      expect(projection.memberCount, 2);
      expect(projection.renterId, 'uid');
    },
  );
  test(
    'Legacy residents without roomId are read through the period, not the room snapshot',
    () async {
      store.rows['periods/period'] = {'roomId': 'room', 'status': 'dangO'};
      store.rows['residents/primary'] = {
        'periodId': 'period',
        'userId': 'uid',
        'fullName': 'An',
        'formId': 'chinh',
        'statusId': 'dangO',
      };
      store.rows['residents/gone'] = {
        'roomId': 'room',
        'userId': 'gone',
        'fullName': 'Gone',
        'status': 'moved_out',
      };
      final members = await ResidentService(store).forRoom('room');
      expect(members.map((r) => r.fullName), ['An']);
      final projected = ResidentService.withResidents(
        RoomModel.fromMap(store.rows['host_rooms/room']!, 'room'),
        members,
      );
      expect(projected.tenantName, 'An');
      expect(projected.toMap().containsKey('tenantName'), isFalse);
    },
  );

  test(
    'Sync restores a confirmed quick-check-in record without changing its original date or creating duplicates',
    () async {
      final at = Timestamp.fromDate(DateTime(2026, 10, 26, 9));
      store.rows['bookings/booking']!.addAll({
        'hostId': 'host',
        'renterName': 'vanthe',
        'renterPhone': '0938912833',
        'checkedInAt': at,
        'isCheckIn': true,
      });
      final service = ResidentService(store);
      final first = await service.syncCheckedInResidents('host');
      expect(first.created, 1);
      final members = await service.forRoom('room');
      expect(members.single.fullName, 'vanthe');
      expect(members.single.moveInDate, at.toDate());
      final second = await service.syncCheckedInResidents('host');
      expect(second.created, 0);
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(1),
      );
      expect(store.rows['bookings/booking']!['checkedInAt'], at);
      expect(store.rows['host_rooms/room']!.containsKey('tenantName'), isFalse);
    },
  );

  test(
    'Sync does not resurrect checked-out residents or trust a status without check-in evidence',
    () async {
      final service = ResidentService(store);
      store.rows['bookings/booking']!.addAll({
        'hostId': 'host',
        'renterName': 'An',
      });
      expect((await service.syncCheckedInResidents('host')).created, 0);
      store.rows['bookings/booking']!['checkedInAt'] = Timestamp.now();
      store.rows['periods/old'] = {
        'bookingId': 'booking',
        'roomId': 'room',
        'status': 'daKetThuc',
      };
      expect((await service.syncCheckedInResidents('host')).created, 0);
      store.rows.remove('periods/old');
      store.rows['host_rooms/room']!['status'] = 'available';
      expect((await service.syncCheckedInResidents('host')).created, 0);
      expect(store.rows.keys.where((p) => p.startsWith('residents/')), isEmpty);
    },
  );

  test('Sync maps the legacy listing occupancy to its original room', () async {
    final at = Timestamp.fromDate(DateTime(2026));
    store.rows['bookings/booking']!.addAll({
      'hostId': 'host',
      'roomId': 'post',
      'checkedInAt': at,
    });
    store.rows['posts/post'] = {'roomId': 'room'};
    store.rows['host_rooms/room']!['status'] = 'available';
    store.rows['host_rooms/post'] = {'status': 'occupied', 'contractStart': at};
    expect(
      (await ResidentService(store).syncCheckedInResidents('host')).created,
      1,
    );
    expect(
      (await ResidentService(store).forRoom('room')).single.roomId,
      'room',
    );
    expect(store.rows['host_rooms/room']!['status'], 'occupied');
  });

  test(
    'Host approval uses the primary resident period and saves both residents and approval atomically',
    () async {
      final batch = store.batch();
      final periodId = await ResidentService(store).preparePrimary(
        batch: batch,
        bookingId: 'booking',
        roomId: 'room',
        userId: 'uid',
        fullName: 'An',
        phone: '',
        now: DateTime(2026),
      );
      await batch.commit();
      store.rows['periods/unrelated'] = {
        'roomId': 'room',
        'renterId': 'someone_else',
        'status': 'dangO',
      };
      store.rows['notifications/request'] = {'status': 'pending'};
      final repo = HostNotificationRepository(firestore: store);
      Future<void> approve() => repo.approveRoommateRequest(
        notificationId: 'request',
        roomId: 'room',
        primaryTenantId: 'uid',
        primaryTenantName: 'An',
        newRoommateId: 'mate',
        newRoommateName: 'Bình',
      );
      store.failNextCommit = true;
      await expectLater(approve(), throwsStateError);
      expect(store.rows['notifications/request']!['status'], 'pending');
      expect((await ResidentService(store).forRoom('room')).length, 1);
      await approve();
      expect(store.rows['notifications/request']!['status'], 'approved');
      final members = await ResidentService(store).forRoom('room');
      expect(members.length, 2);
      expect(members.singleWhere((r) => r.userId == 'mate').periodId, periodId);
      await approve();
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(2),
      );
    },
  );

  test(
    'Host approval cannot report success when the main tenant has no active resident',
    () async {
      store.rows['notifications/request'] = {'status': 'pending'};
      await expectLater(
        HostNotificationRepository(firestore: store).approveRoommateRequest(
          notificationId: 'request',
          roomId: 'room',
          primaryTenantId: 'uid',
          primaryTenantName: 'An',
          newRoommateId: 'mate',
          newRoommateName: 'Bình',
        ),
        throwsStateError,
      );
      expect(store.rows['notifications/request']!['status'], 'pending');
      expect(store.rows.keys.where((p) => p.startsWith('residents/')), isEmpty);
    },
  );

  test(
    'Invitation uses the actual resident room instead of an older approved booking',
    () async {
      store.rows['users/uid'] = {'role': 'renter'};
      store.rows['users/mate'] = {'role': 'renter'};
      store.rows['host_rooms/older'] = {
        'hostId': 'host',
        'propertyId': 'home',
        'status': 'available',
      };
      store.rows['bookings/old'] = {
        'renterId': 'uid',
        'roomId': 'older',
        'status': 'approved',
      };
      final service = RoommateInvitationEligibilityService(firestore: store);
      expect(
        (await service.resolve(senderId: 'uid', receiverId: 'mate')).canInvite,
        isFalse,
      );
      final batch = store.batch();
      await ResidentService(store).preparePrimary(
        batch: batch,
        bookingId: 'booking',
        roomId: 'room',
        userId: 'uid',
        fullName: 'An',
        phone: '',
        now: DateTime(2026),
      );
      await batch.commit();
      final eligibility = await service.resolve(
        senderId: 'uid',
        receiverId: 'mate',
      );
      expect(eligibility.canInvite, isTrue);
      expect(eligibility.activeRoom!.id, 'room');
    },
  );

  test(
    'Legacy room fields cannot supply occupants and ended residents are excluded',
    () async {
      store.rows['host_rooms/room']!['tenantName'] = 'Stale';
      final room = RoomModel.fromMap(store.rows['host_rooms/room']!, 'room');
      expect(room.tenantName, isEmpty);
      expect(await ResidentService(store).forRoom('room'), isEmpty);
      store.rows['residents/old'] = {
        'userId': 'old',
        'roomId': 'room',
        'periodId': 'ended',
        'fullName': 'Old',
        'statusId': 'dangO',
      };
      store.rows['periods/ended'] = {'roomId': 'room', 'status': 'daKetThuc'};
      expect(await ResidentService(store).forRoom('room'), isEmpty);
    },
  );
}
