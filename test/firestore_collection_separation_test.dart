import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/firestore_collections.dart';

void main() {
  test('all room paths resolve to host_rooms', () {
    expect(FirestoreCollections.hostRooms, 'host_rooms');
    expect(FirestoreCollections.rooms, 'host_rooms');
    expect(FirestoreCollections.publicRooms, 'host_rooms');
    expect(HostFirestorePaths.roomDoc('property', 'room'), 'host_rooms/room');
    expect(HostFirestorePaths.rooms('property'), 'host_rooms');
    expect(
      HostFirestorePaths.roomImages('room'),
      'host_rooms/room/room_images',
    );
  });

  test('post creation cannot write room documents or room child data', () {
    final source = File(
      'lib/features/host/providers/host_management_provider.dart',
    ).readAsStringSync();
    final postCreation = source.substring(
      source.indexOf('Future<String> createPostWithAmenities'),
    );
    expect(postCreation, isNot(contains('roomPayload')));
    expect(postCreation, isNot(contains('roomAmenities)')));
    expect(postCreation, isNot(contains('roomImages)')));
    expect(postCreation, contains('batch.set(postRef, postPayload)'));
    expect(postCreation, isNot(contains('newRoomRef.set')));
  });

  test('post review cannot change availability or status of rooms', () {
    final source = File(
      'lib/features/admin/services/post_review_service.dart',
    ).readAsStringSync();
    expect(source, isNot(contains("collection('host_rooms')")));
    expect(source, isNot(contains("['rooms', 'host_rooms']")));
    expect(source, contains('batch.update(postRef'));
  });
}
