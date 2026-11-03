import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

/// Nhận diện HomeShare đồng nhất trong tiêu đề các trang quản trị.
class AdminBrandedTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AdminBrandedTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AdminColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: Icon(
            Icons.home_work_rounded,
            size: 22,
            color: AdminColors.accent,
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HomeShare',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.25,
                  color: AdminColors.accentText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.title,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    color: AdminColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
