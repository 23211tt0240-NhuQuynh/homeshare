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
  }) {
    final missing = <RequiredAccountInfoField>[];
    if (!_vietnamPhone.hasMatch(phoneNumber.trim())) {
      missing.add(RequiredAccountInfoField.phoneNumber);
    }
    if (bankName.trim().isEmpty) {
      missing.add(RequiredAccountInfoField.bankName);
    }
    if (!_bankAccountNumber.hasMatch(accountNumber.trim())) {
      missing.add(RequiredAccountInfoField.bankAccountNumber);
    }
    if (accountHolder.trim().length < 2) {
      missing.add(RequiredAccountInfoField.bankAccountHolder);
    }
    return missing;
  }

  static bool isComplete({
    required String phoneNumber,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    return missingFields(
      phoneNumber: phoneNumber,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
    ).isEmpty;
  }

  /// Chỉ bỏ hộp nhắc khi dữ liệu SĐT và tài khoản ngân hàng thực tế đã đủ.
  static bool shouldPrompt({
    required String phoneNumber,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    return !isComplete(
      phoneNumber: phoneNumber,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
    );
  }
}
