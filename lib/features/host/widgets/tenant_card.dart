import 'package:flutter/material.dart';
import '../repositories/tenant_repository.dart';
import '../../../core/constants/app_colors.dart';

class TenantCard extends StatelessWidget {
  final TenantItem tenant;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;

  const TenantCard({
    super.key,
    required this.tenant,
    this.onTap,
    this.onMessage,
  });

  Color _getAvatarBg(String name) {
    if (name.isEmpty) return const Color(0xFFE0E7FF);
    final code = name.codeUnitAt(0);
    if (code % 3 == 0) return const Color(0xFFE0E7FF); // light blue
    if (code % 3 == 1) return const Color(0xFFFFEDD5); // light orange
    return AppColors.successContainer; // light green
  }

  Color _getAvatarText(String name) {
    if (name.isEmpty) return const Color(0xFF3730A3);
    final code = name.codeUnitAt(0);
    if (code % 3 == 0) return const Color(0xFF3730A3);
    if (code % 3 == 1) return const Color(0xFF9A3412);
    return const Color(0xFF166534);
  }

  Widget _buildAvatar() {
    if (tenant.isGroup && tenant.roommates.length >= 2) {
      final name1 = tenant.roommates[0].fullName;
      final name2 = tenant.roommates[1].fullName;
      final initial1 = name1.isNotEmpty ? name1[0].toUpperCase() : 'A';
      final initial2 = name2.isNotEmpty ? name2[0].toUpperCase() : 'B';

      return SizedBox(
        width: 48,
        height: 44,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 2,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  initial1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF1D4ED8)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFBAE6FD),
                  child: Text(
                    initial2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final initial = tenant.displayName.isNotEmpty
        ? tenant.displayName[0].toUpperCase()
        : 'K';
    final bg = _getAvatarBg(tenant.displayName);
    final fg = _getAvatarText(tenant.displayName);

    return CircleAvatar(
      radius: 22,
      backgroundColor: bg,
      child: Text(
        initial,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Avatar + Tên + Số người + Số điện thoại
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tenant.displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tenant.isGroup) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${tenant.memberCount} người',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            tenant.phone.isNotEmpty
                                ? tenant.phone
                                : 'Chưa cập nhật SĐT',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Divider(height: 1, color: AppColors.surfaceVariant),
                SizedBox(height: 12),
                // Hàng 2: Phòng & Nhà trọ + Nút nhắn tin trong ứng dụng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 17,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${tenant.roomName} • ${tenant.propertyName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Nút SMS
                    InkWell(
                      onTap: onMessage,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 15,
                              color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SMS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
