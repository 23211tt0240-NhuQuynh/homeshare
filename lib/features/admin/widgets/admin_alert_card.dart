import 'package:flutter/material.dart';

enum AdminActionType {
  disbursement, // Giải ngân tiền cọc
  postReview,   // Duyệt bài đăng mới
  ekyc,         // Xác thực CCCD / eKYC
  report,       // Xử lý báo cáo sự cố
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

  // Factory constructor tương thích nhanh với mã đơn giải ngân
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
      actionButtonColor: const Color(0xFF12B76A),
      onProcess: onProcess,
    );
  }

  // Factory constructor cho duyệt bài đăng mới
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
<<<<<<< HEAD
      actionButtonColor: const Color(0xFF398FC0),
=======
      actionButtonColor: const Color(0xFF155EEF),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      onProcess: onProcess,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color iconBgColor;
    Widget iconWidget;

    switch (type) {
      case AdminActionType.disbursement:
        iconBgColor = const Color(0xFFFEF3F2);
        iconWidget = const Text(
          '!',
          style: TextStyle(
            color: Color(0xFFD92D20),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        );
        break;
      case AdminActionType.postReview:
<<<<<<< HEAD
        iconBgColor = const Color(0xFFE9F5FC);
        iconWidget = const Icon(Icons.apartment_rounded, color: Color(0xFF398FC0), size: 19);
=======
        iconBgColor = const Color(0xFFEFF8FF);
        iconWidget = const Icon(Icons.apartment_rounded, color: Color(0xFF155EEF), size: 19);
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        break;
      case AdminActionType.ekyc:
        iconBgColor = const Color(0xFFFEF0C7);
        iconWidget = const Icon(Icons.badge_outlined, color: Color(0xFFB54708), size: 19);
        break;
      case AdminActionType.report:
        iconBgColor = const Color(0xFFFEE4E2);
        iconWidget = const Icon(Icons.warning_amber_rounded, color: Color(0xFFD92D20), size: 19);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
<<<<<<< HEAD
        border: Border.all(color: const Color(0xFFDCEAF5), width: 1.2),
=======
        border: Border.all(color: const Color(0xFFEAECF0), width: 1.2),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
          // Alert / Icon Badge
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

          // Main text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    text: '$title ',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                    children: [
                      TextSpan(
                        text: highlightCode,
                        style: const TextStyle(
<<<<<<< HEAD
                          color: Color(0xFF398FC0),
=======
                          color: Color(0xFF155EEF),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Action button (Xử lý ngay / Duyệt bài)
          ElevatedButton(
            onPressed: onProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor ?? const Color(0xFF12B76A),
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
