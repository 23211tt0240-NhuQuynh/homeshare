import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../models/violation_model.dart';

class ViolationTypeSelector extends StatelessWidget {
  final List<ViolationModel> violations;
  final List<ViolationModel> selectedViolations;
  final ValueChanged<ViolationModel> onToggle;

  const ViolationTypeSelector({
    super.key,
    required this.violations,
    required this.selectedViolations,
    required this.onToggle,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'delete_outline':
        return Icons.delete_outline_rounded;
      case 'volume_up_outlined':
        return Icons.campaign_outlined;
      case 'smoke_free_outlined':
        return Icons.smoke_free_rounded;
      case 'group_outlined':
        return Icons.groups_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getUnselectedIconColor(String id) {
    if (id.contains('rac')) return AppColors.primary;
    if (id.contains('on_ao')) return const Color(0xFFEA580C);
    if (id.contains('hut_thuoc')) return const Color(0xFFEF4444);
    if (id.contains('nguoi_la')) return const Color(0xFF0284C7);
    return const Color(0xFFD97706);
  }

  String _formatCurrency(double amount) {
    final s = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join()} đ';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedViolations.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HÀNH VI VI PHẠM',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedCount > 0
                      ? AppColors.primaryContainer
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selectedCount > 0 ? 'Chọn $selectedCount lỗi' : 'Chưa chọn lỗi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedCount > 0
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: violations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = violations[index];
              final isSelected =
                  selectedViolations.any((v) => v.id == item.id);

              return InkWell(
                onTap: () => onToggle(item),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getIconData(item.iconName),
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : _getUnselectedIconColor(item.id),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(item.defaultFine),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
