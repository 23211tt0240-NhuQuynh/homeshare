import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';
import 'package:home_share/features/host/notifications/providers/host_notification_provider.dart';

void main() {
  group('Kiểm tra logic CCCD Storage và Trạng thái Chờ duyệt Admin', () {
    test('UserProfile cccdVerificationStatus và isCccdPending khi tài khoản chờ duyệt', () {
      final pendingProfile = UserProfile(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Nguyễn Văn A',
        phoneNumber: '0901234567',
        role: 'renter',
        cccdNumber: '079203001234',
        cccdFullName: 'NGUYỄN VĂN A',
        cccdFrontImageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/cccd_front.jpg',
        cccdBackImageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/cccd_back.jpg',
        cccdVerificationStatus: 'pending',
        isCccdVerified: false,
      );

      expect(pendingProfile.isCccdVerified, isFalse);
      expect(pendingProfile.isCccdPending, isTrue);
      expect(pendingProfile.cccdFrontImageUrl.startsWith('https://'), isTrue);
      expect(pendingProfile.cccdBackImageUrl.startsWith('https://'), isTrue);
    });

    test('UserProfile cccdVerificationStatus từ Map chỉ lưu cccdVerificationStatus pending', () {
      final mapData = <String, dynamic>{
        'displayName': 'Lê Văn Chủ Trọ',
        'role': 'host',
        'isCccdVerified': false,
        'cccdVerificationStatus': 'pending',
        'cccdNumber': '079203009999',
        'cccdFrontImageUrl': 'https://firebasestorage.googleapis.com/v0/b/app/o/users/user_host/cccd_front.jpg',
        'cccdBackImageUrl': 'https://firebasestorage.googleapis.com/v0/b/app/o/users/user_host/cccd_back.jpg',
      };

      final profile = UserProfile.fromMap(mapData, 'user_host');

      expect(profile.isCccdVerified, isFalse);
      expect(profile.isCccdPending, isTrue);
      expect(profile.cccdVerificationStatus, 'pending');
      expect(profile.cccdFrontImageUrl, contains('firebasestorage'));
      expect(profile.cccdBackImageUrl, contains('firebasestorage'));
    });

    test('UserProfile khi Admin đã phê duyệt thành công chỉ lưu cccdVerificationStatus approved', () {
      final approvedMap = <String, dynamic>{
        'displayName': 'Trần Thị B',
        'role': 'renter',
        'isCccdVerified': true,
        'cccdVerificationStatus': 'approved',
        'cccdNumber': '079203005555',
        'cccdFrontImageUrl': 'https://firebasestorage.googleapis.com/v0/b/app/o/cccd_front_555.jpg',
        'cccdBackImageUrl': 'https://firebasestorage.googleapis.com/v0/b/app/o/cccd_back_555.jpg',
      };

      final profile = UserProfile.fromMap(approvedMap, 'user_approved');

      expect(profile.isCccdVerified, isTrue);
      expect(profile.isCccdPending, isFalse);
      expect(profile.cccdVerificationStatus, 'approved');
    });

    test('ResidentModel lưu giữ URL ảnh CCCD dẫn sang storage', () {
      final resident = ResidentModel(
        id: 'res_01',
        periodId: 'period_01',
        userId: 'user_123',
        fullName: 'Nguyễn Văn Khách',
        phone: '0901234567',
        moveInDate: DateTime(2025, 1, 1),
        cccdNumber: '079203001234',
        cccdFrontImageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/front.jpg',
        cccdBackImageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/back.jpg',
        isCccdVerified: false,
      );

      final map = resident.toMap();
      expect(map['cccdFrontImageUrl'], 'https://firebasestorage.googleapis.com/v0/b/app/o/front.jpg');
      expect(map['cccdBackImageUrl'], 'https://firebasestorage.googleapis.com/v0/b/app/o/back.jpg');
      expect(map['isCccdVerified'], isFalse);
    });

    test('UserProfile bắt đúng trạng thái rejected và cccdRejectedReason từ Firestore', () {
      final rejectedMap = <String, dynamic>{
        'displayName': 'Trần Trà Quốc Mẫn',
        'role': 'host',
        'isCccdVerified': false,
        'cccdVerificationStatus': 'rejected',
        'cccdRejectedReason': 'Ảnh CCCD chưa rõ hoặc thông tin chưa khớp',
        'cccdNumber': '079206022867',
      };

      final profile = UserProfile.fromMap(rejectedMap, 'host_rejected');

      expect(profile.isCccdVerified, isFalse);
      expect(profile.isCccdPending, isFalse);
      expect(profile.isCccdRejected, isTrue);
      expect(profile.cccdVerificationStatus, 'rejected');
      expect(profile.cccdRejectedReason, 'Ảnh CCCD chưa rõ hoặc thông tin chưa khớp');
    });

    test('Thông báo CCCD chủ trọ luôn xếp vào tab Đang xử lý và không nhầm với post_rejected', () {
      final pendingNotif = HostNotificationModel.fromMap({
        'type': 'cccd_verification_pending',
        'title': 'Đã gửi yêu cầu xác thực CCCD Chủ trọ',
        'body': 'Hồ sơ xác thực CCCD chủ trọ của bạn đã được gửi sang Quản trị viên.',
        'status': 'pending',
      }, 'n_pending');

      final approvedNotif = HostNotificationModel.fromMap({
        'type': 'cccd_verification_approved',
        'title': 'Xác thực CCCD thành công ✓',
        'body': 'Hồ sơ định danh CCCD của bạn đã được phê duyệt!',
        'status': 'approved',
      }, 'n_approved');

      final rejectedNotif = HostNotificationModel.fromMap({
        'type': 'cccd_verification_rejected',
        'title': 'Yêu cầu xác thực CCCD bị từ chối',
        'body': 'Hồ sơ CCCD của bạn chưa được duyệt.',
        'cccdRejectedReason': 'Ảnh mờ',
        'status': 'rejected',
      }, 'n_rejected');

      expect(pendingNotif.type, HostNotificationType.pendingAction);
      expect(pendingNotif.isCccdNotification, isTrue);
      expect(pendingNotif.isCccdPendingNotification, isTrue);

      expect(approvedNotif.type, HostNotificationType.pendingAction);
      expect(approvedNotif.isCccdNotification, isTrue);
      expect(approvedNotif.isCccdApprovedNotification, isTrue);

      expect(rejectedNotif.type, HostNotificationType.pendingAction);
      expect(rejectedNotif.isCccdNotification, isTrue);
      expect(rejectedNotif.isCccdRejectedNotification, isTrue);
      expect(rejectedNotif.isPostRejected, isFalse);
      expect(rejectedNotif.rejectReason, 'Ảnh mờ');
    });

    test('mergeLiveCccdStatusNotification tự động thêm thẻ bị từ chối khi cccdVerificationStatus đổi sang rejected', () {
      final profile = UserProfile(
        uid: 'host_1',
        email: 'host@test.com',
        displayName: 'Trần Trà Quốc Mẫn',
        phoneNumber: '0901234567',
        role: 'host',
        isCccdVerified: false,
        cccdVerificationStatus: 'rejected',
        cccdRejectedReason: 'Ảnh CCCD bị mờ góc',
        cccdRejectedAt: DateTime(2026, 11, 21, 16, 43),
      );

      final merged = mergeLiveCccdStatusNotification(
        items: const [],
        profile: profile,
        type: HostNotificationType.pendingAction,
      );

      expect(merged.length, 1);
      expect(merged.first.isCccdRejectedNotification, isTrue);
      expect(merged.first.rejectReason, 'Ảnh CCCD bị mờ góc');
      expect(merged.first.type, HostNotificationType.pendingAction);
    });
  });
}
