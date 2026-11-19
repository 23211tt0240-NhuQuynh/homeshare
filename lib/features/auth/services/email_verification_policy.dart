class EmailVerificationPolicy {
  const EmailVerificationPolicy._();

  static bool isSupportedGmail(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();
    return RegExp(
      r'^[a-z0-9](?:[a-z0-9._%+\-]*[a-z0-9])?@(gmail\.com|googlemail\.com)$',
    ).hasMatch(email);
  }

  static bool isSupportedRegistrationRole(String role) {
    return role == 'renter' || role == 'host';
  }

  /// Chỉ tài khoản được tạo bởi luồng mới mới có cờ
  /// `emailVerificationRequired`. Nhờ vậy tài khoản legacy không bị khóa nhầm.
  static bool requiresVerification({
    required bool firebaseEmailVerified,
    required bool profileRequiresVerification,
  }) {
    // Cờ hồ sơ chỉ được gỡ sau khi app đã kiểm tra Firebase, hiện thông báo
    // thành công và hoàn tất kích hoạt. Không mở màn hình chính giữa chừng.
    return profileRequiresVerification;
  }

  static bool canResumePendingRegistration({
    required bool firebaseEmailVerified,
    required bool profileExists,
    required bool profileRequiresVerification,
  }) {
    if (firebaseEmailVerified) return false;
    return !profileExists || profileRequiresVerification;
  }

  static String maskEmail(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();
    final atIndex = email.indexOf('@');
    if (atIndex <= 0 || atIndex == email.length - 1) return email;

    final local = email.substring(0, atIndex);
    final domain = email.substring(atIndex + 1);
    if (local.length == 1) return '${local[0]}****@$domain';

    final suffixLength = local.length > 4 ? 4 : local.length - 1;
    final suffix = local.substring(local.length - suffixLength);
    return '${local[0]}****$suffix@$domain';
  }
}
