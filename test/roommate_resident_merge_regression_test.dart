// The Firestore interfaces are faked only to exercise actual repository writes/streams.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/booking_service.dart';
import 'package:home_share/core/services/resident_service.dart';
import 'package:home_share/features/host/repositories/tenant_repository.dart';
import 'package:home_share/features/host/notifications/repositories/host_notification_repository.dart';

class Store extends Fake implements FirebaseFirestore {
  final rows = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast(sync: true);
  var sequence = 0;
  bool failCommit = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      Col(this, path);
  @override
  WriteBatch batch() => Batch(this);
}

class Col extends Fake implements CollectionReference<Map<String, dynamic>> {
  final Store store;
  @override
  final String path;
  final Map<String, Object?> filters;
  Col(this.store, this.path, [this.filters = const {}]);
  Snap snapshot() => Snap(
    store.rows.entries
        .where(
          (e) =>
              e.key.startsWith('$path/') &&
              e.key.split('/').length == 2 &&
              filters.entries.every((f) => e.value[f.key] == f.value),
        )
        .map<QueryDocumentSnapshot<Map<String, dynamic>>>(
          (e) => QDoc(store, e.key, Map.from(e.value)),
        )
        .toList(),
  );
  Stream<QuerySnapshot<Map<String, dynamic>>> watch() async* {
    yield snapshot();
    yield* store.changes.stream
        .map((_) => snapshot())
        .distinct((a, b) => a.signature == b.signature);
  }

  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #doc) {
      return Ref(
        store,
        '$path/${call.positionalArguments.isEmpty || call.positionalArguments.first == null ? 'new_${store.sequence++}' : call.positionalArguments.first}',
      );
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
      return Future<QuerySnapshot<Map<String, dynamic>>>.value(snapshot());
    }
    if (call.memberName == #snapshots) return watch();
    if (call.memberName == #add) {
      final ref = Ref(store, '$path/new_${store.sequence++}');
      store.rows[ref.path] = Map<String, dynamic>.from(
        call.positionalArguments.first as Map,
      );
      store.changes.add(null);
      return Future<DocumentReference<Map<String, dynamic>>>.value(ref);
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
  ]) async => Doc(
    store,
    path,
    store.rows[path] == null ? null : Map.from(store.rows[path]!),
  );
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final writes = Batch(store);
    writes.write(this, data);
    await writes.commit();
  }
}

class Doc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Store store;
  final String path;
  final Map<String, dynamic>? contents;
  Doc(this.store, this.path, this.contents);
  @override
  String get id => path.split('/').last;
  @override
  bool get exists => contents != null;
  @override
  Map<String, dynamic>? data() => contents;
  @override
  DocumentReference<Map<String, dynamic>> get reference => Ref(store, path);
}

class QDoc extends Doc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  QDoc(super.store, super.path, super.contents);
  @override
  Map<String, dynamic> data() => contents!;
}

class Snap extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  Snap(this.docs);
  String get signature => docs.map((d) => '${d.id}:${d.data()}').join('|');
}

class Batch extends Fake implements WriteBatch {
  final Store store;
  final pending = <void Function()>[];
  Batch(this.store);
  void write(Ref ref, Map<String, dynamic> data) => pending.add(() {
    final row = {...?store.rows[ref.path]};
    for (final e in data.entries) {
      if (e.value == FieldValue.delete()) {
        row.remove(e.key);
      } else {
        row[e.key] = e.value is FieldValue ? Timestamp.now() : e.value;
      }
    }
    store.rows[ref.path] = row;
  });
  @override
  Future<void> commit() async {
    if (store.failCommit) throw StateError('simulated write failure');
    for (final apply in pending) {
      apply();
    }
    store.changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #set || call.memberName == #update) {
      write(
        call.positionalArguments.first as Ref,
        Map<String, dynamic>.from(call.positionalArguments[1] as Map),
      );
      return null;
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  late Store store;
  final entered = Timestamp.fromDate(DateTime(2026, 10, 30, 8, 17));
  setUp(() {
    store = Store();
    store.rows.addAll({
      'host_rooms/real': {
        'hostId': 'host',
        'propertyId': 'home',
        'roomCode': 'P101',
        'status': 'occupied',
        'capacity': 8,
      },
      'properties/home': {'hostId': 'host', 'name': 'Chung cư'},
      'posts/listing': {
        'hostId': 'host',
        'roomId': 'real',
        'title': 'Bài đăng',
      },
      'bookings/DP_old': {
        'hostId': 'host',
        'renterId': 'primary',
        'renterName': 'vanthe',
        'renterPhone': '0938912833',
        'roomId': 'listing',
        'status': 'dangO',
        'checkedInAt': entered,
      },
    });
  });
  tearDown(() async {
    await store.changes.close();
  });
  void mergedResident() {
    store.rows['residents/random_from_merge'] = {
      'id': 'random_from_merge',
      'userId': 'primary',
      'roomId': 'listing',
      'periodId': 'DP_old',
      'fullName': 'vanthe',
      'phone': '0938912833',
      'formId': 'chinh',
      'statusId': 'dangO',
      'moveInDate': entered,
    };
  }

  Future<void> approve() =>
      HostNotificationRepository(firestore: store).approveRoommateRequest(
        notificationId: 'request',
        roomId: 'listing',
        primaryTenantId: 'primary',
        primaryTenantName: 'vanthe',
        newRoommateId: 'mate',
        newRoommateName: 'Bạn mới',
      );

  test(
    'Merged quick check-in writes real period and canonical room atomically',
    () async {
      await BookingService(
        firestore: store,
      ).checkinBooking('DP_old', hostId: 'host');
      final residents = await ResidentService(store).forRoom('real');
      expect(residents.single.roomId, 'real');
      expect(residents.single.periodId, isNot('DP_old'));
      expect(
        store.rows.containsKey('periods/${residents.single.periodId}'),
        isTrue,
      );
      expect(store.rows.containsKey('host_rooms/listing'), isFalse);
      expect(store.rows['host_rooms/real']!.containsKey('tenantName'), isFalse);
    },
  );
  test(
    'Approval repairs booking-as-period and keeps original resident ID/date without duplication',
    () async {
      mergedResident();
      await approve();
      final original = store.rows['residents/random_from_merge']!;
      expect(original['periodId'], 'checkin_DP_old');
      expect(original['roomId'], 'real');
      expect(original['moveInDate'], entered);
      expect(store.rows['periods/checkin_DP_old']!['bookingId'], 'DP_old');
      final members = await ResidentService(store).forRoom('real');
      expect(members.map((r) => r.userId).toSet(), {'primary', 'mate'});
      await approve();
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(2),
      );
    },
  );
  test(
    'Tenant repository stream receives new roommate without reopening the screen',
    () async {
      mergedResident();
      final initial = Completer<List<TenantItem>>();
      final updated = Completer<List<TenantItem>>();
      final subscription = TenantRepository(firestore: store)
          .watchHostTenants('host')
          .listen(
            (items) {
              if (items.isNotEmpty && !initial.isCompleted) {
                initial.complete(items);
              }
              if (items.any((i) => i.memberCount == 2) &&
                  !updated.isCompleted) {
                updated.complete(items);
              }
            },
            onError: (Object e, StackTrace st) {
              if (!initial.isCompleted) initial.completeError(e, st);
              if (!updated.isCompleted) updated.completeError(e, st);
            },
          );
      addTearDown(subscription.cancel);
      expect(
        (await initial.future.timeout(
          const Duration(seconds: 5),
        )).single.memberCount,
        1,
      );
      await approve();
      expect(
        (await updated.future.timeout(
          const Duration(seconds: 5),
        )).single.memberCount,
        2,
      );
    },
  );
  test(
    'Failed approval leaves legacy resident and notification unchanged',
    () async {
      mergedResident();
      store.rows['notifications/request'] = {'status': 'pending'};
      store.failCommit = true;
      await expectLater(approve(), throwsStateError);
      expect(store.rows['residents/random_from_merge']!['periodId'], 'DP_old');
      expect(store.rows['notifications/request']!['status'], 'pending');
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(1),
      );
    },
  );
  test(
    'Ended periods cannot be silently reopened by a roommate request',
    () async {
      mergedResident();
      store.rows['periods/DP_old'] = {'roomId': 'real', 'status': 'daKetThuc'};
      await expectLater(approve(), throwsStateError);
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(1),
      );
    },
  );
  test(
    'Repeated quick check-in reuses the random-ID record from the merged build',
    () async {
      mergedResident();
      await BookingService(
        firestore: store,
      ).checkinBooking('DP_old', hostId: 'host');
      await BookingService(
        firestore: store,
      ).checkinBooking('DP_old', hostId: 'host');
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(1),
      );
      expect(
        store.rows['residents/random_from_merge']!['periodId'],
        'checkin_DP_old',
      );
      expect(store.rows['residents/random_from_merge']!['moveInDate'], entered);
    },
  );
  test(
    'Check-in failure cannot leave a staying booking without its resident/period',
    () async {
      store.rows['bookings/DP_old']!['status'] = 'approved';
      store.failCommit = true;
      await expectLater(
        BookingService(
          firestore: store,
        ).checkinBooking('DP_old', hostId: 'host'),
        throwsStateError,
      );
      expect(store.rows['bookings/DP_old']!['status'], 'approved');
      expect(
        store.rows.keys.where(
          (p) => p.startsWith('residents/') || p.startsWith('periods/'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'Legacy repair rejects a booking belonging to a different tenant',
    () async {
      mergedResident();
      store.rows['bookings/DP_old']!['renterId'] = 'other';
      await expectLater(approve(), throwsStateError);
      expect(store.rows['residents/random_from_merge']!['periodId'], 'DP_old');
      expect(store.rows.keys.where((p) => p.startsWith('periods/')), isEmpty);
    },
  );
  test(
    'Existing sync action repairs malformed residents instead of skipping them',
    () async {
      mergedResident();
      final service = ResidentService(store);
      expect((await service.syncCheckedInResidents('host')).created, 1);
      expect(
        store.rows['residents/random_from_merge']!['periodId'],
        'checkin_DP_old',
      );
      expect(store.rows['residents/random_from_merge']!['moveInDate'], entered);
      expect((await service.syncCheckedInResidents('host')).created, 0);
      expect(
        store.rows.keys.where((p) => p.startsWith('residents/')),
        hasLength(1),
      );
    },
  );
}
