import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/user_provider.dart';
import '../screens/cccd_verification_screen.dart';

/// Hiển thị Modal cảnh báo dí dỏm yêu cầu xác thực CCCD trước khi thực hiện hành động.
/// - Renter: Chưa xác thực CCCD -> Không được đặt phòng.
/// - Host: Chưa xác thực CCCD -> Không được tạo cơ sở, tạo phòng hay đăng bài.
/// Tự động đọc trạng thái `cccdVerificationStatus` (`pending`, `rejected`, `unverified`)
/// từ [userProfileProvider] nếu caller không truyền tường minh.
Future<bool?> showCccdRequiredModal(
  BuildContext context, {
  required bool isHost,
  String? actionName,
  bool? isPending,
  bool? isRejected,
  String? rejectedReason,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CccdRequiredDialog(
      isHost: isHost,
      actionName: actionName,
      isPending: isPending,
      isRejected: isRejected,
      rejectedReason: rejectedReason,
    ),
  );
}

class CccdRequiredDialog extends ConsumerWidget {
  final bool isHost;
  final String? actionName;
  final bool? isPending;
  final bool? isRejected;
  final String? rejectedReason;

  const CccdRequiredDialog({
    super.key,
    required this.isHost,
    this.actionName,
    this.isPending,
    this.isRejected,
    this.rejectedReason,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final effectivePending = isPending ?? (profile?.isCccdPending ?? false);
    final effectiveRejected = isRejected ?? (profile?.isCccdRejected ?? false);
    final effectiveReason =
        (rejectedReason ?? profile?.cccdRejectedReason ?? '').trim();

    const cardBg = Colors.white;
    final textDark = AppColors.textDark;
    final textMuted = AppColors.textMuted;

    // Tiêu đề theo trạng thái cccdVerificationStatus
    final title = effectivePending
        ? 'Hồ sơ CCCD đang được xem xét! ⏳'
        : effectiveRejected
            ? 'Hồ sơ CCCD chưa được duyệt!'
            : (isHost
                ? 'Ủa ủa! Khoan đã chủ trọ ơi! 😱'
                : 'Ối kìa! Chưa có vé thông hành sao? 😱');

    // Nội dung cảnh báo theo ngữ cảnh
    String message;
    if (effectivePending) {
      if (isHost) {
        message =
            'Hồ sơ xác thực CCCD chủ trọ của bạn đã gửi sang Quản trị viên xem xét, đang chờ xác thực tài khoản để mở khóa quyền ${actionName ?? "quản lý trọ"}. BQT đang tích cực kiểm tra, bạn đợi trong giây lát nhé! 🏠';
      } else {
        message =
            'Hồ sơ xác thực CCCD của bạn đã gửi sang Quản trị viên xem xét, đang chờ xác thực tài khoản để ${actionName ?? "đặt phòng"}. Bạn kiên nhẫn đợi trong giây lát nhé! 🪪';
      }
    } else if (effectiveRejected) {
      message = isHost
          ? 'Quản trị viên đã từ chối hồ sơ CCCD trước đó của bạn. Vui lòng chụp lại ảnh CCCD 2 mặt rõ nét và quét mã QR gửi lại để mở khóa quyền ${actionName ?? "quản lý trọ"}.'
          : 'Quản trị viên đã từ chối hồ sơ CCCD trước đó của bạn. Vui lòng chụp lại ảnh CCCD 2 mặt rõ nét và gửi lại để ${actionName ?? "đặt phòng"}.';
    } else if (isHost) {
      if (actionName == 'tạo cơ sở') {
        message =
            'Muốn làm "ông trùm bất động sản" mà chưa cho HomeShare biết danh tính sao nè? 🏢 Mau mau xác thực CCCD để mở khóa tạo cơ sở hoành tráng nhé!';
      } else if (actionName == 'tạo phòng') {
        message =
            'Phòng xịn chuẩn bị đón khách mà chủ trọ chưa "lên sóng" CCCD là không được đâu nha! 🔑 Chỉ mất 1 phút xác thực để an tâm quản lý phòng nè!';
      } else if (actionName == 'đăng bài') {
        message =
            'Bài đăng hay, ảnh phòng đẹp, nhưng khách chỉ tin tưởng chủ nhà đã xác thực thôi á! 📜 Xác thực CCCD ngay để bài đăng được duyệt vèo vèo nha!';
      } else {
        message =
            'Muốn làm chủ trọ uy tín "vạn người mê" mà chưa cho HomeShare diện kiến CCCD sao nè? 🏠 Mau xác thực ngay chỉ 1 phút để tha hồ tạo cơ sở, phòng xịn và đăng bài nhé!';
      }
    } else {
      message =
          'Nhà thì đẹp, giá thì êm, nhưng chủ trọ "bảo mật level max" chỉ nhận khách đã xác thực CCCD thôi nè! 🪪 Xác thực nhanh trong 1 phút để rinh ngay phòng xinh bạn nhé!';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mascot Icon
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: (effectiveRejected
                            ? const Color(0xFFD92D20)
                            : const Color(0xFF155EEF))
                        .withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: effectiveRejected
                  ? Container(
                      color: const Color(0xFFFEF3F2),
                      child: const Center(
                        child: Icon(
                          Icons.gpp_bad_rounded,
                          size: 54,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/images/cccd_mascot_warning.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFEFF6FF),
                        child: const Center(
                          child: Icon(
                            Icons.shield_outlined,
                            size: 50,
                            color: Color(0xFF155EEF),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),

            // Tiêu đề
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: effectiveRejected ? const Color(0xFFB42318) : textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Lời nhắc theo trạng thái
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.48,
                color: textMuted,
              ),
            ),
            if (effectiveRejected && effectiveReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDCA)),
                ),
                child: Text(
                  'Lý do từ chối: $effectiveReason',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB42318),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Chip thông tin
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: effectivePending
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: effectivePending
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    effectivePending
                        ? Icons.hourglass_top_rounded
                        : Icons.bolt_rounded,
                    size: 16,
                    color: effectivePending
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    effectivePending
                        ? 'Trạng thái: Đang chờ Admin duyệt'
                        : 'Xác thực eKYC AI an toàn • Chỉ 60 giây',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: effectivePending
                          ? const Color(0xFF92400E)
                          : const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            if (effectivePending) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF155EEF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Nút bấm: Xác thực ngay / Chụp & gửi lại
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const ValueKey('cccd_verify_now_button'),
                  onPressed: () {
                    Navigator.pop(context, true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CccdVerificationScreen(),
                      ),
                    );
                  },
                  icon: Icon(
                    effectiveRejected
                        ? Icons.camera_alt_outlined
                        : Icons.badge_outlined,
                    size: 19,
                  ),
                  label: Text(
                    effectiveRejected
                        ? 'Chụp & gửi lại CCCD ngay'
                        : 'Xác thực CCCD ngay',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveRejected
                        ? const Color(0xFFD92D20)
                        : const Color(0xFF155EEF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Nút phụ: Để sau
              TextButton(
                key: const ValueKey('cccd_verify_later_button'),
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text(
                  'Để tôi làm sau nhé',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

