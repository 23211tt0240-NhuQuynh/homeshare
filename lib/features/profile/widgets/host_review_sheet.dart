import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/host_review_service.dart';
import '../../../core/utils/host_review_policy.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';

Future<bool> showHostReviewSheet(
  BuildContext context, {
  required String hostId,
  required String hostName,
  required String bookingId,
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HostReviewSheet(
      hostId: hostId,
      hostName: hostName,
      bookingId: bookingId,
    ),
  );
  return submitted == true;
}

class HostReviewSheet extends ConsumerStatefulWidget {
  final String hostId;
  final String hostName;
  final String bookingId;

  const HostReviewSheet({
    super.key,
    required this.hostId,
    required this.hostName,
    required this.bookingId,
  });

  @override
  ConsumerState<HostReviewSheet> createState() => _HostReviewSheetState();
}

class _HostReviewSheetState extends ConsumerState<HostReviewSheet> {
  int _rating = 0;
  bool _submitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    if (user == null) {
      _toast('Vui lòng đăng nhập để đánh giá.', failed: true);
      return;
    }
    if (_rating < 1) {
      _toast('Vui lòng chọn số sao từ 1 đến 5.', failed: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(hostReviewServiceProvider).submitReview(
            bookingId: widget.bookingId,
            hostId: widget.hostId,
            reviewerId: user.uid,
            reviewerName: profile?.displayName ?? user.displayName ?? '',
            rating: _rating,
            comment: _commentController.text,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on HostReviewException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(error.message, failed: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Gửi đánh giá thất bại. Vui lòng thử lại.', failed: true);
    }
  }

  void _toast(String message, {bool failed = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Đánh giá ${widget.hostName.trim().isEmpty ? 'chủ trọ' : widget.hostName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chọn số sao. Nhận xét ngắn không bắt buộc.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    onPressed: _submitting ? null : () => setState(() => _rating = star),
                    icon: Icon(
                      star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFA000),
                      size: 32,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: HostReviewPolicy.maxCommentLength,
              decoration: InputDecoration(
                hintText: 'Nhận xét của bạn (không bắt buộc)',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Gửi đánh giá',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
