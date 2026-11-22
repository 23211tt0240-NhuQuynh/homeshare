import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Hộp thoại thông báo trực tiếp trước màn hình khi phòng trọ đã đủ số người ở (capacity).
/// Tuyệt đối không ghi nhận vào chuông thông báo (notifications) của hệ thống.
class RoomFullDialog extends StatelessWidget {
  final int capacity;
  final int currentOccupants;
  final String? roomTitle;

  const RoomFullDialog({
    super.key,
    required this.capacity,
    required this.currentOccupants,
    this.roomTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required int capacity,
    required int currentOccupants,
    String? roomTitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoomFullDialog(
        capacity: capacity,
        currentOccupants: currentOccupants,
        roomTitle: roomTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (roomTitle ?? '').trim();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A), width: 2),
            ),
            child: const Icon(
              Icons.group_off_rounded,
              size: 34,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Phòng đã đủ người ở',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: 6),
                Text(
                  'Sức chứa: $currentOccupants / $capacity người (Đã đủ)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title.isNotEmpty
                ? 'Phòng "$title" hiện đã đạt số lượng người ở tối đa theo quy định (sức chứa $capacity người). Bạn không thể gửi thêm lời mời ở ghép cho phòng này.'
                : 'Phòng trọ này hiện đã đạt số lượng người ở tối đa theo quy định (sức chứa $capacity người). Bạn không thể gửi thêm lời mời ở ghép cho phòng này.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Lưu ý: Lời mời không được gửi và không ghi nhận vào thông báo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Đã hiểu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
