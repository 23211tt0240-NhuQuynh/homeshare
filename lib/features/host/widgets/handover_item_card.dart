import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../../../data/models/handover_item_model.dart';

class HandoverItemCard extends StatelessWidget {
  final HandoverItemModel item;
  final ValueChanged<bool> onToggle;

  const HandoverItemCard({
    super.key,
    required this.item,
    required this.onToggle,
  });

  IconData _getIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('điều hòa') ||
        lower.contains('máy lạnh') ||
        lower.contains('ac')) {
      return Icons.mode_fan_off_outlined;
    }
    if (lower.contains('nóng lạnh') ||
        lower.contains('bình nóng') ||
        lower.contains('nước nóng')) {
      return Icons.shower_outlined;
    }
    if (lower.contains('giường') ||
        lower.contains('nệm') ||
        lower.contains('tủ')) {
      return Icons.bed_outlined;
    }
    if (lower.contains('khóa') || lower.contains('chìa')) {
      return Icons.key_outlined;
    }
    if (lower.contains('tủ lạnh')) {
      return Icons.kitchen_outlined;
    }
    if (lower.contains('máy giặt')) {
      return Icons.local_laundry_service_outlined;
    }
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isChecked
              ? AppColors.border
              : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          // Icon thiết bị
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIcon(item.itemName),
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          // Tên + Mô tả
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Switch toggle
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: item.isChecked,
              activeThumbColor: AppColors.success,
              activeTrackColor: const Color(0xFFBBF7D0),
              inactiveThumbColor: AppColors.textMuted,
              inactiveTrackColor: AppColors.border,
              onChanged: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
