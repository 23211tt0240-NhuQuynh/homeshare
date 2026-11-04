import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/admin/services/admin_audit_identity.dart';

void main() {
  group('AdminAuditIdentity audit role parsing', () {
    test('recognizes explicit admin role markers', () {
      expect(
        AdminAuditIdentity.hasExplicitAdminRole({'actorRole': 'admin'}),
        isTrue,
      );
    });

    test('does not classify a non-admin role as an admin log', () {
      expect(
        AdminAuditIdentity.hasExplicitAdminRole({
          'actorRole': 'host',
          'actorUid': 'host-user-uid',
        }),
        isFalse,
      );
    });

    test('recognizes legacy admin post review actions', () {
      expect(
        AdminAuditIdentity.isKnownAdminAction({
          'category': 'post',
          'title': 'Duyệt Tin Đăng #TD-12345',
        }),
        isTrue,
      );
      expect(
        AdminAuditIdentity.isKnownAdminAction({
          'category': 'post',
          'title': 'Từ Chối Bài Đăng #TD-12345',
        }),
        isTrue,
      );
    });

    test('recognizes legacy admin order approval actions only', () {
      expect(
        AdminAuditIdentity.isKnownAdminAction({
          'category': 'taiChinh',
          'action': 'Duyệt thanh toán',
          'details': 'Admin đã xác nhận thanh toán cho đơn DH-001.',
        }),
        isTrue,
      );
      expect(
        AdminAuditIdentity.isKnownAdminAction({
          'category': 'taiChinh',
          'action': 'Khách xác nhận chuyển khoản',
          'details': 'Khách đã báo đã chuyển khoản.',
        }),
        isFalse,
      );
    });

    test('resolves legacy actor IDs from admin-specific fields', () {
      expect(
        AdminAuditIdentity.legacyActorUid({'reviewedById': 'admin-user-uid'}),
        'admin-user-uid',
      );
      expect(
        AdminAuditIdentity.legacyActorUid({
          'performerId': 'admin-user-uid',
          'actorUid': 'system',
        }),
        'admin-user-uid',
      );
      expect(
        AdminAuditIdentity.legacyActorUid({
          'actorUid': 'system',
          'adminUid': 'admin-user-uid',
        }),
        'admin-user-uid',
      );
    });

    test('does not treat renter and system IDs as legacy admin identities', () {
      expect(
        AdminAuditIdentity.legacyActorUid({
          'actor': 'Người thuê',
          'action': 'Khách xác nhận chuyển khoản',
        }),
        isNull,
      );
      expect(AdminAuditIdentity.legacyActorUid({'actorUid': 'system'}), isNull);
    });
  });
}
