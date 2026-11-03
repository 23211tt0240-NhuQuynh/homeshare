import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/host_post_report_service.dart';
import '../../../core/utils/host_post_report_policy.dart';
import '../../../data/models/host_post_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';

Future<void> showReportHostPostDialog(
  BuildContext context, {
  required String postId,
  required String postTitle,
  required String hostId,
  required String hostName,
  String roomId = '',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ReportHostPostDialog(
      postId: postId,
      postTitle: postTitle,
      hostId: hostId,
      hostName: hostName,
      roomId: roomId,
    ),
  );
}

class ReportHostPostDialog extends ConsumerStatefulWidget {
  final String postId;
  final String postTitle;
  final String hostId;
  final String hostName;
  final String roomId;

  const ReportHostPostDialog({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.hostId,
    required this.hostName,
    this.roomId = '',
  });

  factory ReportHostPostDialog.fromRoom(RoomModel room) {
    return ReportHostPostDialog(
      postId: room.id,
      postTitle: room.title,
      hostId: room.hostId,
      hostName: room.hostName,
      roomId: room.id,
    );
  }

  factory ReportHostPostDialog.fromHostPost(HostPostModel post) {
    return ReportHostPostDialog(
      postId: post.id,
      postTitle: post.title,
      hostId: post.hostId,
      hostName: post.authorName,
      roomId: post.roomId,
    );
  }

  @override
  ConsumerState<ReportHostPostDialog> createState() =>
      _ReportHostPostDialogState();
}

class _ReportHostPostDialogState extends ConsumerState<ReportHostPostDialog> {
  final Set<String> _selectedReasons = {};
  final TextEditingController _otherController = TextEditingController();
  bool _isSubmitting = false;

  bool get _showOtherField =>
      HostPostReportPolicy.includesOther(_selectedReasons);

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _toggleReason(String reason) {
    setState(() {
      if (_selectedReasons.contains(reason)) {
        _selectedReasons.remove(reason);
        if (reason == HostPostReportPolicy.otherReason) {
          _otherController.clear();
        }
      } else {
        _selectedReasons.add(reason);
      }
    });
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    final otherText = _otherController.text.trim();
    final error = HostPostReportPolicy.validate(
      reporterId: user?.uid ?? '',
      hostId: widget.hostId,
      postId: widget.postId,
      selectedReasons: _selectedReasons,
      otherText: otherText,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(hostPostReportServiceProvider).submitPostReport(
            postId: widget.postId,
            postTitle: widget.postTitle,
            hostId: widget.hostId,
            hostName: widget.hostName,
            roomId: widget.roomId,
            reporterId: user!.uid,
            reporterName: profile?.displayName ?? user.displayName ?? '',
            selectedReasons: _selectedReasons.toList(),
            otherText: otherText,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Báo cáo bài đăng đã được gửi tới ban quản trị HomeShare.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } on HostPostReportException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi báo cáo thất bại. Vui lòng thử lại.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Báo cáo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tìm hỗ trợ hoặc báo cáo bài đăng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hãy giúp chúng tôi hiểu chuyện gì đang xảy ra.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in HostPostReportPolicy.reasons)
                    _ReportReasonChip(
                      label: reason,
                      selected: _selectedReasons.contains(reason),
                      onTap: _isSubmitting ? null : () => _toggleReason(reason),
                    ),
                ],
              ),
              if (_showOtherField) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherController,
                  enabled: !_isSubmitting,
                  maxLength: HostPostReportPolicy.maxDetailLength,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Mô tả vấn đề khác...',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB54708)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hãy liên hệ với cơ quan hành pháp tại khu vực bạn nếu ai đó đang gặp nguy hiểm.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFB54708)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(88, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Tiếp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportReasonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ReportReasonChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
