import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/host_report_service.dart';
import '../../../core/utils/host_report_policy.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';

/// Người thuê gửi báo cáo chủ trọ tới Admin. Không gồm bước Admin xử lý.
class ReportHostScreen extends ConsumerStatefulWidget {
  final String hostId;
  final String hostName;
  final String hostPhone;
  final RoomModel? room;

  const ReportHostScreen({
    super.key,
    required this.hostId,
    required this.hostName,
    this.hostPhone = '',
    this.room,
  });

  factory ReportHostScreen.fromRoom(RoomModel room) {
    return ReportHostScreen(
      hostId: room.hostId,
      hostName: room.hostName,
      hostPhone: room.hostPhone,
      room: room,
    );
  }

  @override
  ConsumerState<ReportHostScreen> createState() => _ReportHostScreenState();
}

class _ReportHostScreenState extends ConsumerState<ReportHostScreen> {
  final Set<String> _selectedReasons = {};
  final TextEditingController _otherController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _evidenceImages = [];
  bool _isSubmitting = false;

  bool get _showOtherField =>
      HostReportPolicy.includesOther(_selectedReasons);

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _toggleReason(String reason, bool checked) {
    setState(() {
      if (checked) {
        _selectedReasons.add(reason);
      } else {
        _selectedReasons.remove(reason);
        if (reason == HostReportPolicy.otherReason) {
          _otherController.clear();
        }
      }
    });
  }

  Future<void> _pickEvidence() async {
    if (_evidenceImages.length >= HostReportPolicy.maxEvidenceImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tối đa ${HostReportPolicy.maxEvidenceImages} ảnh minh chứng.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    final remaining = HostReportPolicy.maxEvidenceImages - _evidenceImages.length;
    setState(() => _evidenceImages.addAll(picked.take(remaining)));
  }

  Future<void> _submitReport() async {
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    final otherText = _otherController.text.trim();

    final error = HostReportPolicy.validate(
      reporterId: user?.uid ?? '',
      hostId: widget.hostId,
      selectedReasons: _selectedReasons,
      otherText: otherText,
      evidenceCount: _evidenceImages.length,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(hostReportServiceProvider).submitHostReport(
            hostId: widget.hostId,
            hostName: widget.hostName,
            hostPhone: widget.hostPhone,
            hostAvatar: widget.room?.hostAvatar ?? '',
            roomId: widget.room?.id ?? '',
            roomTitle: widget.room?.title ?? '',
            roomPrice: widget.room?.price ?? 0,
            roomAddress: widget.room?.address ?? '',
            roomImages: widget.room?.images ?? const [],
            reporterId: user!.uid,
            reporterName: profile?.displayName ?? user.displayName ?? '',
            reporterPhone: profile?.phoneNumber ?? '',
            selectedReasons: _selectedReasons.toList(),
            otherText: otherText,
            evidencePaths: _evidenceImages.map((file) => file.path).toList(),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã gửi cho Admin',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Báo cáo đã được gửi tới ban quản trị HomeShare. Admin sẽ tiếp nhận và xử lý. Bạn không cần làm thêm bước nào.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    } on HostReportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi báo cáo thất bại. Vui lòng thử lại.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostName = widget.hostName.trim().isEmpty ? 'Chủ trọ' : widget.hostName.trim();
    final roomTitle = widget.room?.title.trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Báo cáo chủ trọ'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      hostName[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hostName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          roomTitle.isEmpty
                              ? 'Báo cáo vi phạm sẽ được gửi tới Ban Quản Trị'
                              : 'Phòng liên quan: $roomTitle',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'LÝ DO BÁO CÁO CHỦ TRỌ (*)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Có thể chọn nhiều lý do',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < HostReportPolicy.reasons.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                    CheckboxListTile(
                      value: _selectedReasons.contains(HostReportPolicy.reasons[i]),
                      onChanged: _isSubmitting
                          ? null
                          : (checked) => _toggleReason(
                                HostReportPolicy.reasons[i],
                                checked ?? false,
                              ),
                      title: Text(
                        HostReportPolicy.reasons[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedReasons.contains(HostReportPolicy.reasons[i])
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: _selectedReasons.contains(HostReportPolicy.reasons[i])
                              ? AppColors.textDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      side: BorderSide(color: AppColors.textMuted, width: 1.4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
            if (_showOtherField) ...[
              const SizedBox(height: 14),
              Text(
                'LÝ DO KHÁC (*)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otherController,
                enabled: !_isSubmitting,
                maxLines: 4,
                maxLength: HostReportPolicy.maxDetailLength,
                decoration: InputDecoration(
                  hintText: 'Nhập lý do khác của bạn...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: AppColors.surface,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ẢNH MINH CHỨNG (*)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _pickEvidence,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Thêm ảnh', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            Text(
              'Bắt buộc ít nhất 1 ảnh, tối đa ${HostReportPolicy.maxEvidenceImages} ảnh.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (_evidenceImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _evidenceImages.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_evidenceImages[i].path),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: _isSubmitting
                                ? null
                                : () => setState(() => _evidenceImages.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        color: AppColors.surface,
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submitReport,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.report_problem_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Gửi báo cáo tới Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
