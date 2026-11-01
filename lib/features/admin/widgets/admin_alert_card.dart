import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

enum AdminActionType {
  disbursement, // Giải ngân tiền cọc
  postReview, // Duyệt bài đăng mới
  ekyc, // Xác thực CCCD / eKYC
  report, // Xử lý báo cáo sự cố
}

class AdminAlertCard extends StatelessWidget {
  final AdminActionType type;
  final String title;
  final String highlightCode;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onProcess;
  final Color? actionButtonColor;

  const AdminAlertCard({
    super.key,
    this.type = AdminActionType.disbursement,
    this.title = 'Giải ngân cọc',
    this.highlightCode = '#DH8821 → CT0089',
    this.subtitle = 'Chủ trọ: Đặng Thu Hà • Số tiền: 4.250.000 đ',
    this.actionLabel = 'Xử lý ngay',
    this.actionButtonColor,
    required this.onProcess,
  });

  factory AdminAlertCard.disbursement({
    Key? key,
    String orderCode = '#DH8821',
    String hostCode = 'CT0089',
    String hostName = 'Đặng Thu Hà',
    String amount = '4.250.000 đ',
    required VoidCallback onProcess,
  }) {
    return AdminAlertCard(
      key: key,
      type: AdminActionType.disbursement,
      title: 'Giải ngân cọc',
      highlightCode: '$orderCode → $hostCode',
      subtitle: 'Chủ trọ: $hostName • Số tiền: $amount',
      actionLabel: 'Xử lý ngay',
      actionButtonColor: AdminColors.success,
      onProcess: onProcess,
    );
  }

  factory AdminAlertCard.postReview({
    Key? key,
    required String postCode,
    required String hostName,
    required String roomTitle,
    required VoidCallback onProcess,
  }) {
    return AdminAlertCard(
      key: key,
      type: AdminActionType.postReview,
      title: 'Duyệt bài đăng',
      highlightCode: postCode,
      subtitle: 'Chủ trọ: $hostName • $roomTitle',
      actionLabel: 'Duyệt ngay',
      actionButtonColor: AdminColors.accent,
      onProcess: onProcess,
    );
  }

  @override
  Widget build(BuildContext context) {
    late Color iconBgColor;
    late Widget iconWidget;

    switch (type) {
      case AdminActionType.disbursement:
        iconBgColor = AdminColors.dangerContainer;
        iconWidget = Text(
          '!',
          style: TextStyle(
            color: AdminColors.danger,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        );
        break;
      case AdminActionType.postReview:
        iconBgColor = AdminColors.accentSoft;
        iconWidget = Icon(
          Icons.apartment_rounded,
          color: AdminColors.accent,
          size: 19,
        );
        break;
      case AdminActionType.ekyc:
        iconBgColor = AdminColors.warningContainer;
        iconWidget = Icon(
          Icons.badge_outlined,
          color: AdminColors.warningInk,
          size: 19,
        );
        break;
      case AdminActionType.report:
        iconBgColor = AdminColors.dangerContainer;
        iconWidget = Icon(
          Icons.warning_amber_rounded,
          color: AdminColors.danger,
          size: 19,
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: iconWidget,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    text: '$title ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.ink,
                    ),
                    children: [
                      TextSpan(
                        text: highlightCode,
                        style: TextStyle(
                          color: AdminColors.accentText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor ?? AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
