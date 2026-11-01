import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

class AdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  final String? badgeText;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final IconData? badgeIcon;
  final String? subtext;
  final Color? subtextColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AdminKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
    this.badgeText,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeIcon,
    this.subtext,
    this.subtextColor,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AdminColors.card;
    final border = borderColor ?? AdminColors.border;
    final valueInk = valueColor ?? AdminColors.ink;
    final titleInk = valueColor == AdminColors.accent
        ? AdminColors.accentText
        : AdminColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: titleInk,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: valueInk,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor ?? AdminColors.successContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null) ...[
                      Icon(
                        badgeIcon,
                        size: 11,
                        color: badgeTextColor ?? AdminColors.successInk,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor ?? AdminColors.successInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else if (subtext != null)
              Text(
                subtext!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: subtextColor ?? AdminColors.accentText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
