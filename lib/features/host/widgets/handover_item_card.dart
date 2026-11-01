import 'package:flutter/material.dart';
import '../../../data/models/handover_item_model.dart';
import '../../../core/constants/app_colors.dart';

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
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
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
              color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
            ),
          ),
          SizedBox(width: 12),
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
                  SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          // Switch toggle
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: item.isChecked,
              activeThumbColor: const Color(0xFF16A34A),
              activeTrackColor: const Color(0xFFBBF7D0),
              inactiveThumbColor: const Color(0xFF94A3B8),
              inactiveTrackColor: AppColors.border,
              onChanged: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
