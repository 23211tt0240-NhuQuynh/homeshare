import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../screens/cccd_verification_screen.dart';

/// Hiển thị Modal cảnh báo dí dỏm yêu cầu xác thực CCCD trước khi thực hiện hành động.
/// - Renter: Chưa xác thực CCCD -> Không được đặt phòng.
/// - Host: Chưa xác thực CCCD -> Không được tạo cơ sở, tạo phòng hay đăng bài.
Future<bool?> showCccdRequiredModal(
  BuildContext context, {
  required bool isHost,
  String? actionName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CccdRequiredDialog(
      isHost: isHost,
      actionName: actionName,
    ),
  );
}

class CccdRequiredDialog extends StatelessWidget {
  final bool isHost;
  final String? actionName;

  const CccdRequiredDialog({
    super.key,
    required this.isHost,
    this.actionName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textDark = isDark ? const Color(0xFFF8FAFC) : AppColors.textDark;
    final textMuted = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;

    // Tiêu đề dí dỏm
    final title = isHost
        ? 'Ủa ủa! Khoan đã chủ trọ ơi! 😱'
        : 'Ối kìa! Chưa có vé thông hành sao? 😱';

    // Nội dung cảnh báo dí dỏm theo ngữ cảnh
    String message;
    if (isHost) {
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
            // Mascot Icon (Ngôi nhà & toà nhà hoảng hốt đáng yêu)
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF155EEF).withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
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
                color: textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Lời nhắc dí dỏm
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.48,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 16),

            // Chip thông tin bảo mật & tốc độ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Xác thực eKYC AI an toàn • Chỉ 60 giây',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Nút bấm: Xác thực ngay
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
                icon: const Icon(Icons.badge_outlined, size: 19),
                label: const Text(
                  'Xác thực CCCD ngay',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF155EEF),
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
        ),
      ),
    );
  }
}

