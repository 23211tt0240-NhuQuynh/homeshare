import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/profile/services/required_account_info_policy.dart';

void main() {
  group('RequiredAccountInfoPolicy', () {
    test('đủ thông tin khi SĐT và tài khoản ngân hàng đều hợp lệ', () {
      final missing = RequiredAccountInfoPolicy.missingFields(
        phoneNumber: '0912345678',
        bankName: 'Vietcombank',
        accountNumber: '123456789',
        accountHolder: 'NGUYEN VAN AN',
      );

      expect(missing, isEmpty);
    });

    test('báo thiếu cả SĐT và ba trường tài khoản ngân hàng', () {
      final missing = RequiredAccountInfoPolicy.missingFields(
        phoneNumber: '',
        bankName: '',
        accountNumber: '',
        accountHolder: '',
      );

      expect(
        missing,
        containsAll(<RequiredAccountInfoField>{
          RequiredAccountInfoField.phoneNumber,
          RequiredAccountInfoField.bankName,
          RequiredAccountInfoField.bankAccountNumber,
          RequiredAccountInfoField.bankAccountHolder,
        }),
      );
    });

    test('SĐT sai định dạng và STK quá ngắn vẫn được xem là chưa hoàn tất', () {
      expect(
        RequiredAccountInfoPolicy.isComplete(
          phoneNumber: '912345678',
          bankName: 'MB Bank',
          accountNumber: '12345',
          accountHolder: 'TRAN ANH',
        ),
        isFalse,
      );
    });

    test('tài khoản đã cập nhật trước đó không bị yêu cầu cập nhật lại', () {
      expect(
        RequiredAccountInfoPolicy.shouldPrompt(
          previouslyCompleted: true,
          phoneNumber: '',
          bankName: '',
          accountNumber: '',
          accountHolder: '',
        ),
        isFalse,
      );
    });

    test('tài khoản cũ đủ dữ liệu thật không bị yêu cầu cập nhật lại', () {
      expect(
        RequiredAccountInfoPolicy.shouldPrompt(
          previouslyCompleted: false,
          phoneNumber: '0912345678',
          bankName: 'Vietcombank',
          accountNumber: '123456789',
          accountHolder: 'NGUYEN VAN AN',
        ),
        isFalse,
      );
    });

    test('tài khoản chưa cập nhật và còn thiếu dữ liệu vẫn phải bổ sung', () {
      expect(
        RequiredAccountInfoPolicy.shouldPrompt(
          previouslyCompleted: false,
          phoneNumber: '0912345678',
          bankName: '',
          accountNumber: '',
          accountHolder: '',
        ),
        isTrue,
      );
    });
  });
}
