import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_collections.dart';

class HostReviewModel {
  final String id;
  final String hostId;
  final String reviewerId;
  final String reviewerName;
  final int rating;
  final String comment;
  final String bookingId;
  final DateTime createdAt;

  const HostReviewModel({
    required this.id,
    required this.hostId,
    required this.reviewerId,
    this.reviewerName = '',
    required this.rating,
    this.comment = '',
    required this.bookingId,
    required this.createdAt,
  });

  factory HostReviewModel.fromFirestore(DocumentSnapshot doc) {
    return HostReviewModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory HostReviewModel.fromMap(Map<String, dynamic> data, String id) {
    return HostReviewModel(
      id: id,
      hostId: (data[HostReviewFields.hostId] ?? '').toString(),
      reviewerId: (data[HostReviewFields.reviewerId] ?? '').toString(),
      reviewerName: (data[HostReviewFields.reviewerName] ?? '').toString(),
      rating: (data[HostReviewFields.rating] as num?)?.toInt() ?? 0,
      comment: (data[HostReviewFields.comment] ?? '').toString().trim(),
      bookingId: (data[HostReviewFields.bookingId] ?? id).toString(),
      createdAt: (data[HostReviewFields.createdAt] is Timestamp)
          ? (data[HostReviewFields.createdAt] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      HostReviewFields.hostId: hostId,
      HostReviewFields.reviewerId: reviewerId,
      HostReviewFields.reviewerName: reviewerName,
      HostReviewFields.rating: rating,
      HostReviewFields.comment: comment,
      HostReviewFields.bookingId: bookingId,
      HostReviewFields.createdAt: Timestamp.fromDate(createdAt),
    };
  }
}

class HostReviewStats {
  final int count;
  final double totalStars;

  const HostReviewStats({this.count = 0, this.totalStars = 0});

  factory HostReviewStats.fromReviews(Iterable<HostReviewModel> reviews) {
    var count = 0;
    var total = 0.0;
    for (final review in reviews) {
      if (review.rating < 1 || review.rating > 5) continue;
      count++;
      total += review.rating;
    }
    return HostReviewStats(count: count, totalStars: total);
  }

  double? get average => count == 0 ? null : totalStars / count;

  String get displayAverage {
    final value = average;
    if (value == null) return 'Chưa có đánh giá';
    return '${value.toStringAsFixed(1)}/5';
  }
}
