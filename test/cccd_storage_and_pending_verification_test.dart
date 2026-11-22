import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';

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
  });
}
