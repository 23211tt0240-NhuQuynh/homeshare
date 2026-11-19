enum RequiredAccountInfoField {
  phoneNumber,
  bankName,
  bankAccountNumber,
  bankAccountHolder,
}

/// Quy tắc xác định tài khoản đã đủ thông tin liên hệ và nhận/hoàn tiền hay chưa.
abstract final class RequiredAccountInfoPolicy {
  static final RegExp _vietnamPhone = RegExp(r'^0\d{9}$');
  static final RegExp _bankAccountNumber = RegExp(r'^\d{6,19}$');

  static List<RequiredAccountInfoField> missingFields({
    required String phoneNumber,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    bool requireBankAccount = true,
  }) {
    final missing = <RequiredAccountInfoField>[];
    if (!_vietnamPhone.hasMatch(phoneNumber.trim())) {
      missing.add(RequiredAccountInfoField.phoneNumber);
    }
    if (requireBankAccount) {
      if (bankName.trim().isEmpty) {
        missing.add(RequiredAccountInfoField.bankName);
      }
      if (!_bankAccountNumber.hasMatch(accountNumber.trim())) {
        missing.add(RequiredAccountInfoField.bankAccountNumber);
      }
      if (accountHolder.trim().length < 2) {
        missing.add(RequiredAccountInfoField.bankAccountHolder);
      }
    }
    return missing;
  }

  static bool isComplete({
    required String phoneNumber,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    bool requireBankAccount = true,
  }) {
    return missingFields(
      phoneNumber: phoneNumber,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      requireBankAccount: requireBankAccount,
    ).isEmpty;
  }

  /// Tài khoản đã hoàn tất trước đó không bị hỏi lại ở những lần đăng nhập sau.
  /// Tài khoản cũ chưa có cờ vẫn được công nhận khi dữ liệu thực tế đã đầy đủ.
  static bool shouldPrompt({
    required bool previouslyCompleted,
    required String phoneNumber,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    bool requireBankAccount = true,
  }) {
    if (previouslyCompleted) return false;
    return !isComplete(
      phoneNumber: phoneNumber,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      requireBankAccount: requireBankAccount,
    );
  }
}
