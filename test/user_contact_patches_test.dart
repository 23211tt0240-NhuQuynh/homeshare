import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/user_profile_service.dart';

void main() {
  test('hostProfileUsersPatch lưu SĐT theo định dạng chuẩn để kiểm tra trùng', () {
    final patch = hostProfileUsersPatch(
      displayName: 'Nguyễn An',
      phoneNumber: '0912 345 678',
      gender: 'Nam',
      hometown: 'Đà Nẵng',
    );

    expect(patch['phoneNumber'], '0912345678');
    expect(patch['phoneNumberNormalized'], '0912345678');
  });

  test('hostBankAccountPatch lưu STK theo định dạng chuẩn để kiểm tra trùng', () {
    final patch = hostBankAccountPatch(
      uid: 'user-1',
      accountNumber: '123 456-789',
      accountHolder: 'NGUYEN VAN AN',
      bankName: 'Vietcombank',
    );

    expect(patch['accountNumber'], '123456789');
  });
}
