import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/user_profile_service.dart';
import 'package:home_share/core/utils/host_reputation.dart';

void main() {
  group('hostProfileUsersPatch', () {
    test('ghi users: tên, SĐT, giới tính, quê, năm sinh', () {
      final patch = hostProfileUsersPatch(
        displayName: 'Lan Chủ Trọ',
        phoneNumber: '0912345678',
        gender: 'Nữ',
        hometown: 'Đà Nẵng',
        birthDate: DateTime(1995, 3, 1),
      );

      expect(patch['displayName'], 'Lan Chủ Trọ');
      expect(patch['phoneNumber'], '0912345678');
      expect(patch['gender'], 'Nữ');
      expect(patch['hometown'], 'Đà Nẵng');
      expect(patch.containsKey('birthDate'), isTrue);
    });

    test('không ghi nghề, nơi làm, bio, sở thích, uy tín, role', () {
      final patch = hostProfileUsersPatch(
        displayName: 'Lan',
        phoneNumber: '0912345678',
        gender: 'Nữ',
        hometown: 'Huế',
      );

      for (final key in [
        'occupation',
        'workplace',
        'bio',
        'hobbies',
        'ngheNghiep',
        'noiLamViec',
        'gioiThieu',
        'reputationScore',
        'diemUyTin',
        'role',
        'vaiTro',
      ]) {
        expect(patch.containsKey(key), isFalse, reason: 'không được ghi $key');
      }
    });
  });

  group('hostBankAccountPatch', () {
    test('ghi bank_accounts theo uid người dùng', () {
      final patch = hostBankAccountPatch(
        uid: 'host1',
        accountNumber: '0123456789',
        accountHolder: 'NGUYEN LAN',
        bankName: 'Vietcombank',
      );

      expect(patch['id'], 'host1');
      expect(patch['userId'], 'host1');
      expect(patch['accountNumber'], '0123456789');
      expect(patch['accountHolder'], 'NGUYEN LAN');
      expect(patch['bankName'], 'Vietcombank');
    });
  });

  group('RoleAware routing', () {
    test('chủ trọ dùng hồ sơ host, người thuê không', () {
      expect(HostReputation.isHostRole('host'), isTrue);
      expect(HostReputation.isHostRole('renter'), isFalse);
    });
  });
}
