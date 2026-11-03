// Firestore SDK interfaces are implemented only by these test doubles.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/providers/host_amenity_provider.dart';
import 'package:home_share/features/host/data/host_property.dart';
import 'package:home_share/features/host/screens/host_create_post_screen.dart';
import 'package:home_share/data/models/host_post_model.dart';
import 'package:home_share/core/services/booking_service.dart';
import 'package:home_share/data/models/room_model.dart';

// Small transactional store exercising the service's reads and atomic writes.
// Firestore contention/retry semantics still require an emulator integration test.
class MemoryFirestore implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = MemoryTransaction(this);
    final result = await handler(transaction);
    for (final write in transaction.writes) {
      final data = records.putIfAbsent(write.$1, () => {});
      for (final entry in write.$2.entries) {
        if (entry.value is FieldValue) {
          if (entry.key.endsWith('At')) {
            data[entry.key] = Timestamp.now();
          } else {
            data.remove(entry.key);
          }
        } else {
          data[entry.key] = entry.value;
        }
      }
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryCollection implements CollectionReference<Map<String, dynamic>> {
  final MemoryFirestore db;
  @override
  final String path;
  MemoryCollection(this.db, this.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      MemoryDocument(db, '$path/$id');
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      return MemoryQuery(
        db,
        path,
        invocation.positionalArguments.first as String,
        invocation.namedArguments[#isEqualTo],
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class MemoryDocument implements DocumentReference<Map<String, dynamic>> {
  final MemoryFirestore db;
  @override
  final String path;
  MemoryDocument(this.db, this.path);
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => MemorySnapshot(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemorySnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final MemoryDocument reference;
  MemorySnapshot(this.reference);
  @override
  String get id => reference.id;
  @override
  bool get exists => reference.db.records.containsKey(reference.path);
  @override
  Map<String, dynamic> data() => reference.db.records[reference.path] ?? {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryQuery implements Query<Map<String, dynamic>> {
  final MemoryFirestore db;
  final String path, field;
  final dynamic value;
  MemoryQuery(this.db, this.path, this.field, this.value);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => MemoryQuerySnapshot([
    for (final entry in db.records.entries)
      if (entry.key.startsWith('$path/') && entry.value[field] == value)
        MemorySnapshot(MemoryDocument(db, entry.key)),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  MemoryQuerySnapshot(this.docs);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryTransaction implements Transaction {
  final MemoryFirestore db;
  final writes = <(String, Map<String, dynamic>)>[];
  MemoryTransaction(this.db);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => MemorySnapshot(reference as MemoryDocument) as DocumentSnapshot<T>;
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes.add((reference.path, Map<String, dynamic>.from(data)));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MemoryFirestore db;
  late BookingService service;
  setUp(() {
    db = MemoryFirestore();
    service = BookingService(firestore: db);
    db.records.addAll({
      'host_rooms/room1': {
        'propertyId': 'property1',
        'status': 'available',
        'isAvailable': true,
      },
      'bookings/booking1': {'roomId': 'post1', 'status': 'pending'},
      'bookings/booking2': {'roomId': 'room1', 'status': 'pending'},
      'posts/post1': {
        'roomId': 'room1',
        'status': 'active',
        'isAvailable': true,
      },
      'posts/post2': {'phongId': 'room1', 'status': 'pending'},
      'posts/other': {'roomId': 'room2', 'status': 'active'},
      'rooms/mirror': {'hostRoomId': 'room1', 'status': 'active'},
    });
  });

  test(
    'confirming deposit reserves source room and hides every related listing',
    () async {
      await service.confirmPayment('booking1', {'status': 'approved'});
      expect(db.records['bookings/booking1']!['isPaid'], true);
      final room = db.records['host_rooms/room1']!;
      expect(room['reservedBookingId'], 'booking1');
      expect(RoomModel.fromMap(room, 'room1').canBeListed, false);
      for (final path in ['posts/post1', 'posts/post2', 'rooms/mirror']) {
        expect(db.records[path]!['status'], 'hidden');
        expect(db.records[path]!['isAvailable'], false);
      }
      expect(db.records['posts/other']!['status'], 'active');
      expect(
        HostPostModel.fromFirestore(
          MemorySnapshot(MemoryDocument(db, 'posts/post1')),
        ).isActive,
        false,
      );
    },
  );

  test(
    'a second deposit is rejected without approving the second booking',
    () async {
      await service.confirmPayment('booking1', {'status': 'approved'});
      await expectLater(
        service.confirmPayment('booking2', {'status': 'approved'}),
        throwsStateError,
      );
      expect(db.records['bookings/booking2']!['status'], 'pending');
      expect(db.records['host_rooms/room1']!['reservedBookingId'], 'booking1');
    },
  );

  test(
    'payment for a cancelled booking leaves room and listing unchanged',
    () async {
      db.records['bookings/booking1']!['status'] = 'cancelled';
      await expectLater(
        service.confirmPayment('booking1', {'status': 'approved'}),
        throwsStateError,
      );
      expect(db.records['host_rooms/room1']!['status'], 'available');
      expect(db.records['posts/post1']!['status'], 'active');
    },
  );

  test(
    'cancelling another pending booking cannot unlock the deposited room',
    () async {
      // Empty recipients avoid sending notifications in this service-level test.
      await service.confirmPayment('booking1', {'status': 'approved'});
      await service.cancelBooking('booking2');
      expect(db.records['host_rooms/room1']!['status'], 'reserved');
      expect(db.records['bookings/booking2']!['status'], 'cancelled');
    },
  );

  testWidgets('create-post dropdown only contains vacant rooms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const property = HostProperty(
      id: 'property1',
      name: 'Khu nhà',
      address: '',
      city: '',
      ward: '',
      hostId: 'host1',
      plannedRooms: 4,
    );
    final rooms = [
      for (final status in ['available', 'reserved', 'occupied', 'hidden'])
        RoomModel.fromMap({
          'propertyId': 'property1',
          'status': status,
          'isAvailable': true,
          'title': status,
          'roomCode': status,
        }, status),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostSessionProvider.overrideWith((ref) => Stream.value('host1')),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          hostPropertiesProvider.overrideWith(
            (ref) => Stream.value([property]),
          ),
          hostRoomsProvider.overrideWith((ref) => Stream.value(rooms)),
          hostAmenitiesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: HostCreatePostScreen(initialProperty: property),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<RoomModel>>(
      find.byKey(const ValueKey('room_select')),
    );
    // Open the real dropdown to verify the visible choices.
    expect(dropdown, isNotNull);
    await tester.tap(find.byKey(const ValueKey('room_select')));
    await tester.pumpAndSettle();
    expect(find.text('${rooms.first.roomCode} - available'), findsOneWidget);
    expect(find.text('${rooms[1].roomCode} - reserved'), findsNothing);
    expect(find.text('${rooms[2].roomCode} - occupied'), findsNothing);
    expect(find.text('${rooms[3].roomCode} - hidden'), findsNothing);
  });

  for (final status in [
    'reserved',
    'deposited',
    'deposit_paid',
    'daCoc',
    'occupied',
    'hidden',
    'deleted',
  ]) {
    test(
      '$status is excluded even when an old isAvailable flag remains true',
      () {
        expect(
          RoomModel.fromMap({
            'status': status,
            'isAvailable': true,
          }, 'room1').canBeListed,
          false,
        );
      },
    );
  }
}
