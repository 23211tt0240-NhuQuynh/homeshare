import 'package:flutter/material.dart';

import '../../features/auth/services/role_resolver.dart';
import '../constants/app_colors.dart';

/// Thanh uy tín 0–100 chỉ dùng cho hồ sơ chủ trọ. Người thuê không hiện thanh này.
///
/// Công thức thống nhất: `diemUyTin = max(0, 20 * R - P)`.
/// R là sao trung bình 1–5 từ `host_reviews`. P là tổng phạt Admin (hiện tại = 0).
abstract final class HostReputation {
  static const int maxScore = 100;
  static const int defaultScore = 100;
  static const int pointsPerStar = 20;
  static const int adminPenalty = 0;

  /// Chỉ chủ trọ mới được gắn thanh uy tín. Renter/admin không hiện.
  static bool isHostRole(String role) {
    return RoleResolver.normalizeRole(role) == RoleResolver.host;
  }

  static int clampScore(int raw) => raw.clamp(0, maxScore);

  /// Tính điểm uy tín lúc đọc. Chưa có đánh giá hợp lệ thì giữ 100.
  static int fromAverage(double? averageStars, {int penalty = adminPenalty}) {
    if (averageStars == null) return clampScore(defaultScore);
    final rating = averageStars.clamp(1, 5);
    final appliedPenalty = penalty < 0 ? 0 : penalty;
    return clampScore((pointsPerStar * rating - appliedPenalty).round());
  }

  static double ratio(int raw) => clampScore(raw) / maxScore;

  static Color barColor(int raw) {
    final score = clampScore(raw);
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  static String label(int raw) {
    final score = clampScore(raw);
    if (score >= 80) return 'Uy tín cao';
    if (score >= 50) return 'Uy tín trung bình';
    return 'Uy tín thấp';
  }

  static String scoreText(int raw) => '${clampScore(raw)}/$maxScore';
}
