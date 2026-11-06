import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/host_reputation.dart';

/// Thanh uy tín 0–100. Chỉ gắn vào hồ sơ chủ trọ.
class HostReputationBar extends StatelessWidget {
  final int score;

  const HostReputationBar({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = HostReputation.barColor(score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Độ uy tín',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Text(
              HostReputation.label(score),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: HostReputation.ratio(score),
                minHeight: 18,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              HostReputation.scoreText(score),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
