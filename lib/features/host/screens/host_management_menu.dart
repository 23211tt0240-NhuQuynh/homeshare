import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';

enum HostManagementSection {
  tenants,
  checkinCheckout,
  violations,
}

class HostManagementMenu extends StatelessWidget {
  final HostManagementSection currentSection;
  final ValueChanged<HostManagementSection> onSelect;
  final VoidCallback onClose;

  const HostManagementMenu({
    super.key,
    required this.currentSection,
    required this.onSelect,
    required this.onClose,
  });

  /// Hiển thị menu nổi từ góc trái dưới nút menu
  static Future<void> show({
    required BuildContext context,
    required HostManagementSection currentSection,
    required ValueChanged<HostManagementSection> onSelect,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissMenu',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, anim1, anim2) {
        return SafeArea(
          child: Stack(
            children: [
              // Tap outside để đóng
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
              // Menu nổi góc trái
              Positioned(
                top: 56,
                left: 16,
                child: Material(
                  color: Colors.transparent,
                  child: HostManagementMenu(
                    currentSection: currentSection,
                    onSelect: (section) {
                      Navigator.of(context).pop();
                      onSelect(section);
                    },
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItem({
    required HostManagementSection section,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => onSelect(section),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textDark,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildItem(
            section: HostManagementSection.tenants,
            title: 'Quản lý người thuê',
            icon: Icons.person_outline,
            iconColor: AppColors.primary,
            iconBg: AppColors.primaryContainer,
            isSelected: currentSection == HostManagementSection.tenants,
          ),
          const SizedBox(height: 4),
          _buildItem(
            section: HostManagementSection.checkinCheckout,
            title: 'Quản lý Check in/Check out',
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.textMuted,
            iconBg: AppColors.surfaceVariant,
            isSelected:
                currentSection == HostManagementSection.checkinCheckout,
          ),
          const SizedBox(height: 4),
          _buildItem(
            section: HostManagementSection.violations,
            title: 'Quản lý vi phạm & Phí phạt',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            iconBg: AppColors.warningContainer,
            isSelected: currentSection == HostManagementSection.violations,
          ),
        ],
      ),
    );
  }
}
