import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/auth/services/email_verification_policy.dart';

void main() {
  group('EmailVerificationPolicy', () {
    test('hỗ trợ đăng ký và khôi phục cho cả hai role', () {
      expect(
        EmailVerificationPolicy.isSupportedRegistrationRole('renter'),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.isSupportedRegistrationRole('host'),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.isSupportedRegistrationRole('admin'),
        isFalse,
      );
    });

    test('chỉ chấp nhận địa chỉ Gmail hợp lệ khi đăng ký', () {
      expect(
        EmailVerificationPolicy.isSupportedGmail('new.user@gmail.com'),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.isSupportedGmail('NEW.USER@GMAIL.COM'),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.isSupportedGmail('user@googlemail.com'),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.isSupportedGmail('user@yahoo.com'),
        isFalse,
      );
      expect(
        EmailVerificationPolicy.isSupportedGmail('user@gmail.com.vn'),
        isFalse,
      );
      expect(EmailVerificationPolicy.isSupportedGmail('not-an-email'), isFalse);
    });

    test('tài khoản mới chưa bấm link phải ở màn hình chờ xác thực', () {
      expect(
        EmailVerificationPolicy.requiresVerification(
          firebaseEmailVerified: false,
          profileRequiresVerification: true,
        ),
        isTrue,
      );
    });

    test('hồ sơ còn chờ thì vẫn ở màn xác thực tới khi kích hoạt xong', () {
      expect(
        EmailVerificationPolicy.requiresVerification(
          firebaseEmailVerified: true,
          profileRequiresVerification: true,
        ),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.requiresVerification(
          firebaseEmailVerified: true,
          profileRequiresVerification: false,
        ),
        isFalse,
      );
    });

    test('tài khoản cũ không có cờ mới vẫn đăng nhập bình thường', () {
      expect(
        EmailVerificationPolicy.requiresVerification(
          firebaseEmailVerified: false,
          profileRequiresVerification: false,
        ),
        isFalse,
      );
    });

    test('che Gmail trên màn hình xác thực', () {
      expect(
        EmailVerificationPolicy.maskEmail('abcdef2108@gmail.com'),
        'a****2108@gmail.com',
      );
      expect(
        EmailVerificationPolicy.maskEmail('user@gmail.com'),
        'u****ser@gmail.com',
      );
    });

    test('cho phép tiếp tục tài khoản đăng ký dở chưa xác thực', () {
      expect(
        EmailVerificationPolicy.canResumePendingRegistration(
          firebaseEmailVerified: false,
          profileExists: true,
          profileRequiresVerification: true,
        ),
        isTrue,
      );
      expect(
        EmailVerificationPolicy.canResumePendingRegistration(
          firebaseEmailVerified: false,
          profileExists: false,
          profileRequiresVerification: false,
        ),
        isTrue,
      );
    });

    test('không ghi đè tài khoản đã xác thực hoặc tài khoản legacy', () {
      expect(
        EmailVerificationPolicy.canResumePendingRegistration(
          firebaseEmailVerified: true,
          profileExists: true,
          profileRequiresVerification: true,
        ),
        isFalse,
      );
      expect(
        EmailVerificationPolicy.canResumePendingRegistration(
          firebaseEmailVerified: false,
          profileExists: true,
          profileRequiresVerification: false,
        ),
        isFalse,
      );
    });
  });
}
