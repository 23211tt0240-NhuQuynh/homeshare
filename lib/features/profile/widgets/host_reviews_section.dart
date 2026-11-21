import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/host_review_service.dart';
import '../../../core/utils/host_reputation.dart';
import '../../../data/models/host_review_model.dart';
import '../../auth/providers/user_provider.dart';
import 'host_review_sheet.dart';
import 'host_reputation_bar.dart';

class HostReviewsSection extends ConsumerWidget {
  final String hostId;
  final String hostName;
  final bool showReviewButton;
  final bool? isVerified;

  const HostReviewsSection({
    super.key,
    required this.hostId,
    required this.hostName,
    required this.showReviewButton,
    this.isVerified,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(hostReviewsProvider(hostId));
    final eligible = ref.watch(eligibleHostReviewBookingProvider(hostId));
    final currentUser = ref.watch(userProfileProvider).value;
    final resolvedIsVerified = isVerified ??
        (currentUser != null && currentUser.uid == hostId
            ? currentUser.isCccdVerified
            : false);

    return reviewsAsync.when(
      data: (reviews) {
        final stats = HostReviewStats.fromReviews(reviews);
        return _card(
          context: context,
          stats: stats,
          reviews: reviews,
          canReview: showReviewButton && eligible != null,
          isVerified: resolvedIsVerified,
          onReview: eligible == null
              ? null
              : () async {
                  final ok = await showHostReviewSheet(
                    context,
                    hostId: hostId,
                    hostName: hostName,
                    bookingId: eligible.id,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    ref.invalidate(hostReviewsProvider(hostId));
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã gửi đánh giá thành công.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
        );
      },
      loading: () => _card(
        context: context,
        stats: const HostReviewStats(),
        reviews: const [],
        canReview: false,
        isVerified: resolvedIsVerified,
        loading: true,
      ),
      error: (_, _) => _card(
        context: context,
        stats: const HostReviewStats(),
        reviews: const [],
        canReview: false,
        isVerified: resolvedIsVerified,
        errorText: 'Không tải được đánh giá.',
      ),
    );
  }

  Widget _card({
    required BuildContext context,
    required HostReviewStats stats,
    required List<HostReviewModel> reviews,
    required bool canReview,
    required bool isVerified,
    VoidCallback? onReview,
    bool loading = false,
    String? errorText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!loading && isVerified) ...[
            HostReputationBar(
              score: HostReputation.fromAverage(stats.average),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 22),
              const SizedBox(width: 6),
              Text(
                stats.displayAverage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              Text(
                stats.count == 0 ? '0 lượt đánh giá' : '${stats.count} lượt đánh giá',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(errorText, style: const TextStyle(color: AppColors.danger)),
          ] else if (reviews.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Chưa có nhận xét nào.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Nhận xét gần đây',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            for (final review in reviews.take(5)) _commentTile(review),
          ],
          if (canReview) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text(
                  'Đánh giá chủ trọ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _commentTile(HostReviewModel review) {
    final name = review.reviewerName.trim().isEmpty ? 'Người thuê' : review.reviewerName.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${review.rating}/5',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB78103),
                ),
              ),
            ],
          ),
          Text(
            DateFormat('dd/MM/yyyy').format(review.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
