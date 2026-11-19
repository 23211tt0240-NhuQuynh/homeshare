import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking_model.dart';
import '../../data/models/host_review_model.dart';
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
        final reviewRef = _reviews.doc(cleanBookingId);
        final existing = await tx.get(reviewRef);
        if (existing.exists) {
          throw const HostReviewException('Bạn đã đánh giá giao dịch này rồi.');
        }

        final bookingRef =
            _firestore.collection(FirestoreCollections.bookings).doc(cleanBookingId);
        final bookingSnap = await tx.get(bookingRef);

        bool isAuthorized = false;

        if (bookingSnap.exists) {
          final booking = BookingRequestModel.fromFirestore(bookingSnap);
          if (booking.renterId == cleanReviewerId &&
              booking.hostId == cleanHostId &&
              HostReviewPolicy.isReviewableBooking(booking)) {
            isAuthorized = true;
          } else {
            // Kiểm tra nếu người dùng là người ở ghép trong phòng của đơn này
            final roomId = booking.roomId;
            final resSnap = await _firestore
                .collection(FirestoreCollections.residents)
                .where('roomId', isEqualTo: roomId)
                .where('userId', isEqualTo: cleanReviewerId)
                .get();
            if (resSnap.docs.isNotEmpty) {
              final resData = resSnap.docs.first.data();
              final resStatus = (resData['status'] ?? resData['statusId'] ?? '').toString();
              if (HostReviewPolicy.isReviewableResidentStatus(resStatus)) {
                isAuthorized = true;
              }
            }
          }
        }

        if (!isAuthorized) {
          // Kiểm tra xem cleanBookingId có phải là ID cư dân ở ghép trong residents không
          final resRef = _firestore
              .collection(FirestoreCollections.residents)
              .doc(cleanBookingId);
          final resSnap = await tx.get(resRef);
          if (resSnap.exists) {
            final resData = resSnap.data() ?? {};
            final resUserId = (resData['userId'] ?? resData['nguoiDungId'] ?? '').toString();
            final resStatus = (resData['status'] ?? resData['statusId'] ?? '').toString();
            final resRoomId = (resData['roomId'] ?? resData['phongId'] ?? '').toString();

            if (resUserId != cleanReviewerId) {
              throw const HostReviewException('Chỉ người thuê hoặc cư dân ở ghép của phòng được đánh giá.');
            }
            if (!HostReviewPolicy.isReviewableResidentStatus(resStatus)) {
              throw const HostReviewException('Hợp đồng ở ghép chưa đủ điều kiện để đánh giá.');
            }

            // Kiểm tra phòng có thuộc về chủ trọ này không
            bool hostMatched = false;
            for (final col in [
              FirestoreCollections.hostRooms,
              FirestoreCollections.rooms,
              FirestoreCollections.posts,
            ]) {
              try {
                final rSnap = await _firestore.collection(col).doc(resRoomId).get();
                if (rSnap.exists) {
                  final rData = rSnap.data() ?? {};
                  final hId = (rData['hostId'] ?? rData['chuNhaId'] ?? rData['landlordId'] ?? rData['userId'] ?? '').toString();
                  if (hId == cleanHostId) {
                    hostMatched = true;
                    break;
                  }
                }
              } catch (_) {}
            }
            if (!hostMatched) {
              throw const HostReviewException('Phòng ở ghép không thuộc chủ trọ này.');
            }
            isAuthorized = true;
          }
        }

        if (!isAuthorized) {
          throw const HostReviewException('Không tìm thấy thông tin thuê hoặc ở ghép hợp lệ để đánh giá.');
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

  /// Ghi `users.reputationScore` / `diemUyTin` = max(0, 20 * R - P), P = 0.
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
          'diemUyTin': score,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('Ghi reputationScore chủ trọ $id: $error');
    }
    return score;
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
    Provider.autoDispose.family<BookingRequestModel?, String>((ref, hostId) {
  final uid = ref.watch(currentUserProvider)?.uid ?? '';
  if (uid.isEmpty || uid == hostId) return null;
  final bookings = ref.watch(renterBookingsStreamProvider(uid)).value ?? const [];
  final reviews = ref.watch(hostReviewsProvider(hostId)).value ?? const [];
  final reviewedIds = reviews.map((review) => review.bookingId).toSet();

  final eligible = HostReviewPolicy.firstEligibleBooking(
    reviewerId: uid,
    hostId: hostId,
    bookings: bookings,
    reviewedBookingIds: reviewedIds,
  );
  if (eligible != null) return eligible;

  // Hỗ trợ người ở ghép: renterBookingsStreamProvider đã gộp cả các kỳ ở ghép từ residents
  for (final stay in bookings) {
    if (stay.hostId == hostId &&
        (stay.isActive || HostReviewPolicy.isReviewableStatus(stay.status)) &&
        !reviewedIds.contains(stay.id)) {
      return stay;
    }
  }

  return null;
});
