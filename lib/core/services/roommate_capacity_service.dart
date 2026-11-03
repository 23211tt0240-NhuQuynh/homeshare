import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/roommate_post_model.dart';
import '../constants/firestore_collections.dart';
import '../utils/roommate_capacity_policy.dart';
import 'roommate_service.dart';

class RoommateCapacitySnapshot {
  final int occupantCount;
  final int capacity;
  final RoommatePostModel? latestHasRoomPost;

  const RoommateCapacitySnapshot({
    required this.occupantCount,
    required this.capacity,
    this.latestHasRoomPost,
  });

  bool get isFull => RoommateCapacityPolicy.isFull(
        occupantCount: occupantCount,
        capacity: capacity,
      );
}

/// Đếm người đang ở và đóng tin ở ghép "đã có phòng" khi đủ sức chứa.
class RoommateCapacityService {
  RoommateCapacityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<RoommateCapacitySnapshot> snapshotForAuthor({
    required String authorId,
    required String roomId,
    int roomCapacity = 0,
    Iterable<String> knownOccupantIds = const [],
  }) async {
    final posts = await loadAuthorPosts(authorId);
    final latest = RoommateCapacityPolicy.latestHasRoomPost(posts);
    final roomCap = roomCapacity > 0
        ? roomCapacity
        : await _roomCapacity(roomId);
    final capacity = RoommateCapacityPolicy.resolveCapacity(
      postCapacity: latest?.capacity ?? 0,
      roomCapacity: roomCap,
    );
    final occupantCount = await countOccupants(
      roomId: roomId,
      knownOccupantIds: [
        ...knownOccupantIds,
        if (authorId.trim().isNotEmpty) authorId,
      ],
    );
    return RoommateCapacitySnapshot(
      occupantCount: occupantCount,
      capacity: capacity,
      latestHasRoomPost: latest,
    );
  }

  Future<int> countOccupants({
    required String roomId,
    Iterable<String> knownOccupantIds = const [],
  }) async {
    final ids = <String>{
      for (final id in knownOccupantIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isNotEmpty) {
      for (final field in const ['roomId', 'phongId', 'phongTroId']) {
        final snapshot = await _firestore
            .collection(FirestoreCollections.residents)
            .where(field, isEqualTo: cleanRoomId)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final status = data['statusId'] ??
              data['status'] ??
              data['trangThai_id'] ??
              '';
          if (!_isActiveResidentStatus(status)) continue;
          final userId = (data['userId'] ?? data['nguoiDungId'] ?? '')
              .toString()
              .trim();
          if (userId.isNotEmpty) ids.add(userId);
        }
      }
      for (final collection in const ['posts', 'rooms', 'host_rooms']) {
        final doc = await _firestore.collection(collection).doc(cleanRoomId).get();
        final tenantIds = doc.data()?['tenantIds'];
        if (tenantIds is List) {
          for (final value in tenantIds) {
            final id = value?.toString().trim() ?? '';
            if (id.isNotEmpty) ids.add(id);
          }
        }
      }
    }
    return ids.length;
  }

  Future<List<RoommatePostModel>> loadAuthorPosts(String authorId) async {
    final id = authorId.trim();
    if (id.isEmpty) return const [];
    final byPath = <String, RoommatePostModel>{};
    for (final field in const ['authorId', 'nguoiDangId']) {
      final snapshot = await _firestore
          .collection(FirestoreCollections.roommatePosts)
          .where(field, isEqualTo: id)
          .get();
      for (final doc in snapshot.docs) {
        try {
          byPath[doc.reference.path] = RoommatePostModel.fromFirestore(doc);
        } catch (error) {
          debugPrint('Lỗi parse tin ở ghép ${doc.id}: $error');
        }
      }
    }
    return byPath.values.toList();
  }

  /// Đóng mọi tin "đã có phòng" còn mở của người đăng khi sức chứa bài mới nhất đã đủ.
  Future<void> closeHasRoomPostsIfFull({
    required String authorId,
    required String roomId,
    int roomCapacity = 0,
    Iterable<String> knownOccupantIds = const [],
  }) async {
    final snapshot = await snapshotForAuthor(
      authorId: authorId,
      roomId: roomId,
      roomCapacity: roomCapacity,
      knownOccupantIds: knownOccupantIds,
    );
    if (!snapshot.isFull) return;

    final posts = await loadAuthorPosts(authorId);
    final openPosts = RoommateCapacityPolicy.openHasRoomPosts(posts);
    if (openPosts.isEmpty) return;

    final batch = _firestore.batch();
    for (final post in openPosts) {
      batch.set(
        _firestore.collection(FirestoreCollections.roommatePosts).doc(post.id),
        {
          'status': RoommateCapacityPolicy.closedStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      RoommateService.markLocalPostClosed(post.id);
    }
    await batch.commit();
  }

  Future<int> _roomCapacity(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) return 0;
    for (final collection in const ['posts', 'rooms', 'host_rooms']) {
      final doc = await _firestore.collection(collection).doc(id).get();
      final raw = doc.data()?['capacity'] ?? doc.data()?['sucChua'];
      final value = (raw as num?)?.toInt() ?? 0;
      if (value > 0) return value;
    }
    return 0;
  }

  bool _isActiveResidentStatus(dynamic status) {
    final normalized = RoommateCapacityPolicy.normalizeStatus(status.toString());
    return normalized == 'dango' || normalized == 'active';
  }
}
