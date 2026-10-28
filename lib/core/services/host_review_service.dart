import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking_model.dart';
import '../../data/models/host_review_model.dart';
import '../../data/models/resident_model.dart';
import '../../data/models/room_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../constants/firestore_collections.dart';
import '../utils/host_reputation.dart';
import '../utils/host_review_policy.dart';
import 'booking_service.dart';

class HostReviewException implements Exception {
  final String message;
  const HostReviewException(this.message);

  @override
  String toString() => message;
}

class HostReviewService {
  HostReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection(FirestoreCollections.hostReviews);

  Stream<bool> watchReviewExists(String bookingId) {
    final id = bookingId.trim();
    if (id.isEmpty) return Stream.value(false);
    return _reviews.doc(id).snapshots().map((snapshot) => snapshot.exists);
  }

  Stream<List<HostReviewModel>> watchHostReviews(String hostId) {
    final id = hostId.trim();
    if (id.isEmpty) return Stream.value(const []);
    return _reviews
        .where(HostReviewFields.hostId, isEqualTo: id)
        .orderBy(HostReviewFields.createdAt, descending: true)
        .limit(30)
        .snapshots()
        .handleError((error, stack) {
          debugPrint('Đọc đánh giá chủ trọ $id: $error');
        })
        .map((snapshot) {
          final reviews = snapshot.docs
              .map((doc) {
                try {
                  return HostReviewModel.fromFirestore(doc);
                } catch (error) {
                  debugPrint('Lỗi parse đánh giá ${doc.id}: $error');
                  return null;
                }
              })
              .whereType<HostReviewModel>()
              .toList();
          return reviews;
        });
  }

  Future<void> submitReview({
    required String bookingId,
    required String hostId,
    required String reviewerId,
    required String reviewerName,
    required int rating,
    String comment = '',
  }) async {
    final cleanBookingId = bookingId.trim();
    final cleanHostId = hostId.trim();
    final cleanReviewerId = reviewerId.trim();
    final cleanComment = comment.trim();

    if (cleanReviewerId.isEmpty) {
      throw const HostReviewException('Vui lòng đăng nhập để đánh giá.');
    }
    if (!HostReviewPolicy.canReviewOwnHost(cleanReviewerId, cleanHostId)) {
      throw const HostReviewException('Bạn không thể đánh giá chính mình.');
    }
    if (!HostReviewPolicy.isValidRating(rating)) {
      throw const HostReviewException('Số sao phải từ 1 đến 5.');
    }
    if (cleanComment.length > HostReviewPolicy.maxCommentLength) {
      throw const HostReviewException(
        'Nhận xét tối đa ${HostReviewPolicy.maxCommentLength} ký tự.',
      );
    }
    if (cleanBookingId.isEmpty) {
      throw const HostReviewException('Thiếu giao dịch thuê để đánh giá.');
    }

    try {
      await _firestore.runTransaction((tx) async {
        final bookingRef =
            _firestore.collection(FirestoreCollections.bookings).doc(cleanBookingId);
        final reviewRef = _reviews.doc(cleanBookingId);
        final bookingSnap = await tx.get(bookingRef);
        if (bookingSnap.exists) {
          final booking = BookingRequestModel.fromFirestore(bookingSnap);
          if (booking.renterId != cleanReviewerId) {
            throw const HostReviewException(
              'Chỉ người đang thuê hoặc ở ghép chỗ này được đánh giá.',
            );
          }
          if (booking.hostId != cleanHostId) {
            throw const HostReviewException('Giao dịch không thuộc chủ trọ này.');
          }
          if (!HostReviewPolicy.isReviewableBooking(booking)) {
            throw const HostReviewException(
              'Giao dịch chưa đủ điều kiện để đánh giá.',
            );
          }
        } else {
          await _assertReviewableResident(
            tx,
            stayId: cleanBookingId,
            reviewerId: cleanReviewerId,
            hostId: cleanHostId,
          );
        }
        final existing = await tx.get(reviewRef);
        if (existing.exists) {
          throw const HostReviewException(
            'Bạn đã đánh giá giao dịch này rồi.',
          );
        }
        tx.set(
          reviewRef,
          HostReviewModel(
            id: cleanBookingId,
            hostId: cleanHostId,
            reviewerId: cleanReviewerId,
            reviewerName: reviewerName.trim(),
            rating: rating,
            comment: cleanComment,
            bookingId: cleanBookingId,
            createdAt: DateTime.now(),
          ).toMap(),
        );
      });
      await syncHostReputationScore(cleanHostId);
    } on HostReviewException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists' || error.code == 'aborted') {
        throw const HostReviewException('Bạn đã đánh giá giao dịch này rồi.');
      }
      debugPrint('Gửi đánh giá chủ trọ lỗi: $error');
      throw const HostReviewException('Gửi đánh giá thất bại. Vui lòng thử lại.');
    } catch (error) {
      if (error is HostReviewException) rethrow;
      debugPrint('Gửi đánh giá chủ trọ lỗi: $error');
      throw const HostReviewException('Gửi đánh giá thất bại. Vui lòng thử lại.');
    }
  }

  /// Ghi `users.reputationScore` = max(0, 20 * R - P), P = 0.
  Future<int> syncHostReputationScore(String hostId) async {
    final id = hostId.trim();
    if (id.isEmpty) return HostReputation.defaultScore;
    final snapshot =
        await _reviews.where(HostReviewFields.hostId, isEqualTo: id).get();
    final reviews = snapshot.docs
        .map((doc) {
          try {
            return HostReviewModel.fromFirestore(doc);
          } catch (error) {
            debugPrint('Lỗi parse đánh giá ${doc.id}: $error');
            return null;
          }
        })
        .whereType<HostReviewModel>()
        .toList();
    final score = HostReputation.fromAverage(
      HostReviewStats.fromReviews(reviews).average,
    );
    try {
      await _firestore.collection(FirestoreCollections.users).doc(id).set(
        {
          'reputationScore': score,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('Ghi reputationScore chủ trọ $id: $error');
    }
    return score;
  }

  Future<BookingRequestModel?> findEligibleStay({
    required String reviewerId,
    required String hostId,
    required List<BookingRequestModel> bookings,
    required Set<String> reviewedIds,
  }) async {
    final fromBooking = HostReviewPolicy.firstEligibleBooking(
      reviewerId: reviewerId,
      hostId: hostId,
      bookings: bookings,
      reviewedBookingIds: reviewedIds,
    );
    if (fromBooking != null) return fromBooking;

    final residents = await _loadActiveResidents(reviewerId);
    final hostByRoom = <String, String>{};
    for (final resident in residents) {
      final roomId = resident.roomId.trim();
      if (roomId.isEmpty || hostByRoom.containsKey(roomId)) continue;
      final roomHostId = await _hostIdForRoom(roomId);
      if (roomHostId.isNotEmpty) hostByRoom[roomId] = roomHostId;
    }
    return HostReviewPolicy.firstEligibleResident(
      reviewerId: reviewerId,
      hostId: hostId,
      residents: residents,
      roomHostByRoomId: hostByRoom,
      reviewedBookingIds: reviewedIds,
    );
  }

  Future<void> _assertReviewableResident(
    Transaction tx, {
    required String stayId,
    required String reviewerId,
    required String hostId,
  }) async {
    final residentSnap = await tx.get(
      _firestore.collection(FirestoreCollections.residents).doc(stayId),
    );
    if (!residentSnap.exists) {
      throw const HostReviewException('Không tìm thấy giao dịch thuê hoặc chỗ ở ghép.');
    }
    var resident = ResidentModel.fromFirestore(residentSnap);
    if (resident.userId != reviewerId) {
      throw const HostReviewException(
        'Chỉ người đang thuê hoặc ở ghép chỗ này được đánh giá.',
      );
    }
    if (resident.roomId.trim().isEmpty && resident.periodId.trim().isNotEmpty) {
      final periodSnap = await tx.get(
        _firestore.collection(FirestoreCollections.periods).doc(resident.periodId),
      );
      final periodRoomId = (periodSnap.data()?['roomId'] ??
              periodSnap.data()?['phongId'] ??
              '')
          .toString()
          .trim();
      if (periodRoomId.isNotEmpty) {
        resident = resident.copyWith(roomId: periodRoomId);
      }
    }
    if (!HostReviewPolicy.isReviewableResident(resident)) {
      throw const HostReviewException(
        'Chỗ ở ghép chưa đủ điều kiện để đánh giá.',
      );
    }
    final roomHostId = await _hostIdForRoomInTransaction(tx, resident.roomId);
    if (roomHostId.isEmpty || roomHostId != hostId) {
      throw const HostReviewException('Giao dịch không thuộc chủ trọ này.');
    }
  }

  Future<List<ResidentModel>> _loadActiveResidents(String userId) async {
    final byPath = <String, ResidentModel>{};
    for (final field in const ['userId', 'nguoiDungId']) {
      final snapshot = await _firestore
          .collection(FirestoreCollections.residents)
          .where(field, isEqualTo: userId)
          .get();
      for (final doc in snapshot.docs) {
        try {
          var resident = ResidentModel.fromFirestore(doc);
          if (resident.roomId.trim().isEmpty &&
              resident.periodId.trim().isNotEmpty) {
            final period = await _firestore
                .collection(FirestoreCollections.periods)
                .doc(resident.periodId)
                .get();
            final periodRoomId = (period.data()?['roomId'] ??
                    period.data()?['phongId'] ??
                    '')
                .toString()
                .trim();
            if (periodRoomId.isNotEmpty) {
              resident = resident.copyWith(roomId: periodRoomId);
            }
          }
          if (HostReviewPolicy.isReviewableResident(resident)) {
            byPath[doc.reference.path] = resident;
          }
        } catch (error) {
          debugPrint('Lỗi parse cư dân ${doc.id}: $error');
        }
      }
    }
    return byPath.values.toList();
  }

  Future<String> _hostIdForRoom(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) return '';
    for (final collection in const ['posts', 'rooms', 'host_rooms']) {
      final doc = await _firestore.collection(collection).doc(id).get();
      final hostId = _hostIdFromRoomData(doc.data());
      if (hostId.isNotEmpty) return hostId;
    }
    return '';
  }

  Future<String> _hostIdForRoomInTransaction(Transaction tx, String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) return '';
    for (final collection in const ['posts', 'rooms', 'host_rooms']) {
      final snap = await tx.get(_firestore.collection(collection).doc(id));
      final hostId = _hostIdFromRoomData(snap.data());
      if (hostId.isNotEmpty) return hostId;
    }
    return '';
  }

  String _hostIdFromRoomData(Map<String, dynamic>? data) {
    if (data == null) return '';
    final status = (data['status'] ?? data['trangThai'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'deleted' || status == 'daxoa') return '';
    return RoomModel.fromMap(data, 'room').hostId.trim();
  }
}

final hostReviewServiceProvider = Provider<HostReviewService>(
  (ref) => HostReviewService(),
);

final hostReviewsProvider =
    StreamProvider.autoDispose.family<List<HostReviewModel>, String>((ref, hostId) {
  return ref.watch(hostReviewServiceProvider).watchHostReviews(hostId);
});

final hostReviewExistsProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, bookingId) {
  return ref.watch(hostReviewServiceProvider).watchReviewExists(bookingId);
});

final eligibleHostReviewBookingProvider =
    FutureProvider.autoDispose.family<BookingRequestModel?, String>((ref, hostId) async {
  final uid = ref.watch(currentUserProvider)?.uid ?? '';
  if (uid.isEmpty || uid == hostId) return null;
  final bookings = await ref.watch(renterBookingsStreamProvider(uid).future);
  final reviews = await ref.watch(hostReviewsProvider(hostId).future);
  final reviewedIds = <String>{
    for (final review in reviews) ...[review.id, review.bookingId],
  };
  return ref.watch(hostReviewServiceProvider).findEligibleStay(
        reviewerId: uid,
        hostId: hostId,
        bookings: bookings,
        reviewedIds: reviewedIds,
      );
});
