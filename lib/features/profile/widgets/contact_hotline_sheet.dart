import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

void showContactHotlineSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ContactHotlineSheetContent(),
  );
}

class _ContactHotlineSheetContent extends StatelessWidget {
  const _ContactHotlineSheetContent();

  Future<void> _launch(BuildContext context, String urlString,
      {String? fallbackText}) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (fallbackText != null) {
        await Clipboard.setData(ClipboardData(text: fallbackText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã sao chép: $fallbackText'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (_) {
      if (fallbackText != null && context.mounted) {
        await Clipboard.setData(ClipboardData(text: fallbackText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã sao chép: $fallbackText'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Đã sao chép $label: $text'),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.textMuted : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.headset_mic_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liên hệ hỗ trợ & Hotline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hỗ trợ giải đáp thắc mắc & tiếp nhận sự cố',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Item 1: Hotline
            _buildContactCard(
              context,
              isDark: isDark,
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
              title: 'Tổng đài chăm sóc khách hàng 24/7',
              value: '1900 1234',
              subText: 'Miễn phí cước gọi mọi mạng viễn thông',
              actionIcon: Icons.call,
              actionLabel: 'Gọi ngay',
              onAction: () => _launch(context, 'tel:19001234', fallbackText: '19001234'),
              onCopy: () => _copyToClipboard(context, '19001234', 'số tổng đài'),
            ),
            const SizedBox(height: 12),

            // Item 2: Zalo CSKH
            _buildContactCard(
              context,
              isDark: isDark,
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF0068FF),
              iconBg: const Color(0xFF0068FF).withValues(alpha: 0.12),
              title: 'Zalo Hỗ trợ trực tuyến & Khiếu nại',
              value: '0981 234 567',
              subText: 'Thời gian phản hồi: 8:00 - 22:00 hàng ngày',
              actionIcon: Icons.open_in_new_rounded,
              actionLabel: 'Mở Zalo',
              onAction: () => _launch(
                context,
                'https://zalo.me/0981234567',
                fallbackText: '0981234567',
              ),
              onCopy: () => _copyToClipboard(context, '0981234567', 'số Zalo'),
            ),
            const SizedBox(height: 12),

            // Item 3: Email CSKH
            _buildContactCard(
              context,
              isDark: isDark,
              icon: Icons.email_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              title: 'Email tiếp nhận phản ánh & Hợp tác',
              value: 'cskh@homeshare.vn',
              subText: 'Phản hồi trong vòng 24 giờ làm việc',
              actionIcon: Icons.send_rounded,
              actionLabel: 'Gửi Email',
              onAction: () => _launch(
                context,
                'mailto:cskh@homeshare.vn?subject=Yeu%20cau%20ho%20tro%20HomeShare',
                fallbackText: 'cskh@homeshare.vn',
              ),
              onCopy: () => _copyToClipboard(context, 'cskh@homeshare.vn', 'email'),
            ),
            const SizedBox(height: 12),

            // Item 4: Địa chỉ
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Văn phòng tiếp đón trực tiếp',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tòa nhà HomeShare, Khu Công nghệ cao, TP. Thủ Đức, TP. Hồ Chí Minh',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMuted : AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sao chép địa chỉ',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => _copyToClipboard(
                      context,
                      'Tòa nhà HomeShare, Khu Công nghệ cao, TP. Thủ Đức, TP. Hồ Chí Minh',
                      'địa chỉ',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subText,
    required IconData actionIcon,
    required String actionLabel,
    required VoidCallback onAction,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.textMuted : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sao chép',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  subText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMuted : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 14),
                label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
